package com.filimuplus.filimu_plus

import android.content.Context
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.util.Log
import android.view.View
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory
import org.videolan.libvlc.LibVLC
import org.videolan.libvlc.Media
import org.videolan.libvlc.MediaPlayer
import org.videolan.libvlc.util.VLCVideoLayout

class LibVlcPlayerPlugin(
    private val context: Context,
) : MethodChannel.MethodCallHandler, EventChannel.StreamHandler {

    companion object {
        private const val TAG = "TambaLibVLC"
        const val METHOD_CHANNEL = "tamba_iptv/libvlc"
        const val EVENT_CHANNEL = "tamba_iptv/libvlc_events"
        const val VIEW_TYPE = "tamba_iptv/libvlc_view"
        private const val TIME_EVENT_THROTTLE_MS = 500L
    }

    private val mainHandler = Handler(Looper.getMainLooper())
    private val vlcLock = Any()

    @Volatile private var libVlc: LibVLC? = null
    @Volatile private var mediaPlayer: MediaPlayer? = null
    private var currentMedia: Media? = null
    private var attachedLayout: VLCVideoLayout? = null
    @Volatile private var eventSink: EventChannel.EventSink? = null

    // Automatic HW -> SW decoder fallback tracking for incompatible TV MediaCodec profiles
    private var lastOpenUrl: String? = null
    private var lastOpenHeaders: Map<String, String> = emptyMap()
    private var lastOpenStartMs: Long = 0L
    private var lastOpenHwDecoding: Boolean = true
    private var swFallbackAttemptedForCurrentUrl: Boolean = false
    private var lastTimeEmitMs: Long = 0L

    fun register(flutterEngine: FlutterEngine) {
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            METHOD_CHANNEL
        ).setMethodCallHandler(this)

        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            EVENT_CHANNEL
        ).setStreamHandler(this)

        flutterEngine.platformViewsController.registry.registerViewFactory(
            VIEW_TYPE,
            LibVlcViewFactory(this)
        )
    }

    private fun ensureInitialized(): MediaPlayer {
        mediaPlayer?.let { return it }

        val options = arrayListOf(
            "--network-caching=1500",
            "--live-caching=1500",
            "--file-caching=1500",
            "--http-reconnect",
            "--drop-late-frames",
            "--skip-frames",
            "--avcodec-fast",
            "--no-stats",
            "--no-video-title-show"
        )
        val vlc = LibVLC(context.applicationContext, options)
        val player = MediaPlayer(vlc)
        player.setEventListener { event ->
            handleVlcEvent(event)
        }
        libVlc = vlc
        mediaPlayer = player

        attachedLayout?.let { layout ->
            attachLayout(layout)
        }
        Log.i(TAG, "LibVLC MediaPlayer initialized")
        return player
    }

    internal fun attachLayout(layout: VLCVideoLayout) {
        val task = Runnable {
            synchronized(vlcLock) {
                val player = ensureInitialized()
                if (attachedLayout != null && attachedLayout !== layout) {
                    try {
                        player.detachViews()
                    } catch (e: Exception) {
                        Log.w(TAG, "detachViews before re-attach failed: ${e.message}")
                    }
                }
                attachedLayout = layout
                try {
                    player.attachViews(layout, null, true, false)
                } catch (e: Exception) {
                    Log.w(TAG, "attachViews failed: ${e.message}")
                }
            }
        }
        if (Looper.myLooper() == Looper.getMainLooper()) {
            task.run()
        } else {
            mainHandler.post(task)
        }
    }

    internal fun detachLayout(layout: VLCVideoLayout) {
        // Detach SYNCHRONOUSLY on the main thread before Android destroys the
        // underlying SurfaceView to prevent native EGL_BAD_SURFACE / SIGSEGV crashes.
        val task = Runnable {
            synchronized(vlcLock) {
                if (attachedLayout === layout) {
                    try {
                        mediaPlayer?.detachViews()
                    } catch (e: Exception) {
                        Log.w(TAG, "detachViews failed: ${e.message}")
                    }
                    attachedLayout = null
                }
            }
        }
        if (Looper.myLooper() == Looper.getMainLooper()) {
            task.run()
        } else {
            mainHandler.post(task)
        }
    }

    private fun handleVlcEvent(event: MediaPlayer.Event) {
        val player = mediaPlayer ?: return
        when (event.type) {
            MediaPlayer.Event.Opening -> {
                emit(mapOf("type" to "buffering", "buffering" to true))
            }
            MediaPlayer.Event.Buffering -> {
                val pct = event.buffering
                emit(
                    mapOf(
                        "type" to "buffering",
                        "buffering" to (pct < 100f),
                        "percent" to pct.toDouble()
                    )
                )
            }
            MediaPlayer.Event.Playing -> {
                emit(mapOf("type" to "buffering", "buffering" to false))
                emit(mapOf("type" to "playing", "playing" to true))
                emit(
                    mapOf(
                        "type" to "duration",
                        "durationMs" to player.length.coerceAtLeast(0L)
                    )
                )
                emitTracks(player)
            }
            MediaPlayer.Event.Paused -> {
                emit(mapOf("type" to "playing", "playing" to false))
            }
            MediaPlayer.Event.Stopped -> {
                emit(mapOf("type" to "playing", "playing" to false))
                emit(mapOf("type" to "buffering", "buffering" to false))
            }
            MediaPlayer.Event.EndReached -> {
                emit(mapOf("type" to "playing", "playing" to false))
                emit(mapOf("type" to "completed"))
            }
            MediaPlayer.Event.EncounteredError -> {
                // If hardware decoding (MediaCodec) failed on an incompatible TV
                // video profile, automatically retry once with software decoding.
                val retryUrl = lastOpenUrl
                if (lastOpenHwDecoding && !swFallbackAttemptedForCurrentUrl && !retryUrl.isNullOrBlank()) {
                    swFallbackAttemptedForCurrentUrl = true
                    Log.w(TAG, "Hardware decoder error detected; retrying with software decoding")
                    mainHandler.post {
                        try {
                            openInternal(
                                url = retryUrl,
                                headers = lastOpenHeaders,
                                startMs = lastOpenStartMs,
                                hwDecoding = false
                            )
                        } catch (e: Exception) {
                            Log.e(TAG, "Software fallback open failed: ${e.message}")
                            emitError()
                        }
                    }
                    return
                }
                emitError()
            }
            MediaPlayer.Event.TimeChanged -> {
                val now = SystemClock.elapsedRealtime()
                if (now - lastTimeEmitMs < TIME_EVENT_THROTTLE_MS) return
                lastTimeEmitMs = now
                emit(
                    mapOf(
                        "type" to "position",
                        "positionMs" to event.timeChanged.coerceAtLeast(0L),
                        "durationMs" to player.length.coerceAtLeast(0L)
                    )
                )
            }
            MediaPlayer.Event.LengthChanged -> {
                emit(
                    mapOf(
                        "type" to "duration",
                        "durationMs" to event.lengthChanged.coerceAtLeast(0L)
                    )
                )
            }
            MediaPlayer.Event.ESAdded,
            MediaPlayer.Event.ESDeleted,
            MediaPlayer.Event.ESSelected -> {
                emitTracks(player)
            }
        }
    }

    private fun emitError() {
        emit(mapOf("type" to "buffering", "buffering" to false))
        emit(mapOf("type" to "playing", "playing" to false))
        emit(
            mapOf(
                "type" to "error",
                "message" to "LibVLC could not play this stream. The source may be offline or unsupported."
            )
        )
    }

    private fun openInternal(
        url: String,
        headers: Map<String, String>,
        startMs: Long,
        hwDecoding: Boolean,
    ) {
        synchronized(vlcLock) {
            val player = ensureInitialized()
            val vlc = libVlc!!

            // CRITICAL: Always stop active decoding and clear player.media BEFORE
            // releasing the previous Media object to prevent native use-after-free SIGSEGV.
            try {
                if (player.isPlaying) {
                    player.stop()
                }
            } catch (_: Exception) {
            }
            try {
                player.media = null
            } catch (_: Exception) {
            }
            try {
                currentMedia?.release()
            } catch (_: Exception) {
            }
            currentMedia = null

            val media = Media(vlc, Uri.parse(url))
            media.setHWDecoderEnabled(hwDecoding, false)
            if (!hwDecoding) {
                media.addOption(":codec=avcodec,all")
            }
            media.addOption(":network-caching=1500")
            media.addOption(":live-caching=1500")
            media.addOption(":clock-jitter=0")
            media.addOption(":clock-synchro=0")
            headers["User-Agent"]?.takeIf { it.isNotBlank() }?.let {
                media.addOption(":http-user-agent=$it")
            }
            headers["Referer"]?.takeIf { it.isNotBlank() }?.let {
                media.addOption(":http-referrer=$it")
            }
            if (startMs > 0) {
                media.addOption(":start-time=${startMs / 1000}")
            }

            lastOpenUrl = url
            lastOpenHeaders = headers
            lastOpenStartMs = startMs
            lastOpenHwDecoding = hwDecoding

            currentMedia = media
            player.media = media
            attachedLayout?.let { layout ->
                if (!player.vlcVout.areViewsAttached()) {
                    player.attachViews(layout, null, true, false)
                }
            }
            player.play()
        }
    }

    private fun emitTracks(player: MediaPlayer) {
        val audioTracks = player.audioTracks?.map {
            mapOf("id" to it.id, "name" to (it.name ?: "Track ${it.id}"))
        } ?: emptyList()
        val subtitleTracks = player.spuTracks?.map {
            mapOf("id" to it.id, "name" to (it.name ?: "Subtitle ${it.id}"))
        } ?: emptyList()

        emit(
            mapOf(
                "type" to "tracks",
                "audioTracks" to audioTracks,
                "subtitleTracks" to subtitleTracks,
                "activeAudioTrack" to player.audioTrack,
                "activeSubtitleTrack" to player.spuTrack
            )
        )
    }

    private fun emit(payload: Map<String, Any?>) {
        mainHandler.post {
            try {
                eventSink?.success(payload)
            } catch (_: Exception) {
            }
        }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "open" -> {
                val url = call.argument<String>("url")
                if (url.isNullOrBlank()) {
                    result.error("INVALID_URL", "Stream URL is empty", null)
                    return
                }
                val startMs = (call.argument<Number>("startMs")?.toLong() ?: 0L)
                val hwDecoding = call.argument<Boolean>("hardwareDecoding") ?: true
                val headers = call.argument<Map<String, String>>("headers") ?: emptyMap()

                try {
                    swFallbackAttemptedForCurrentUrl = false
                    openInternal(
                        url = url,
                        headers = headers,
                        startMs = startMs,
                        hwDecoding = hwDecoding
                    )
                    result.success(null)
                } catch (e: Exception) {
                    Log.e(TAG, "open failed: ${e.message}")
                    result.error("OPEN_FAILED", e.message, null)
                }
            }
            "play" -> {
                synchronized(vlcLock) { mediaPlayer?.play() }
                result.success(null)
            }
            "pause" -> {
                synchronized(vlcLock) { mediaPlayer?.pause() }
                result.success(null)
            }
            "togglePlayPause" -> {
                synchronized(vlcLock) {
                    val player = mediaPlayer
                    if (player != null) {
                        if (player.isPlaying) player.pause() else player.play()
                    }
                }
                result.success(null)
            }
            "stop" -> {
                synchronized(vlcLock) {
                    try {
                        mediaPlayer?.stop()
                        mediaPlayer?.media = null
                        currentMedia?.release()
                        currentMedia = null
                    } catch (_: Exception) {
                    }
                }
                result.success(null)
            }
            "seek" -> {
                val posMs = call.argument<Number>("positionMs")?.toLong() ?: 0L
                synchronized(vlcLock) { mediaPlayer?.time = posMs.coerceAtLeast(0L) }
                result.success(null)
            }
            "setVolume" -> {
                val vol = call.argument<Number>("volume")?.toInt() ?: 100
                synchronized(vlcLock) { mediaPlayer?.volume = vol.coerceIn(0, 100) }
                result.success(null)
            }
            "setRate" -> {
                val rate = call.argument<Number>("rate")?.toFloat() ?: 1.0f
                synchronized(vlcLock) { mediaPlayer?.rate = rate.coerceIn(0.25f, 4.0f) }
                result.success(null)
            }
            "setAudioTrack" -> {
                val id = call.argument<Int>("id") ?: -1
                synchronized(vlcLock) { mediaPlayer?.audioTrack = id }
                result.success(null)
            }
            "setSubtitleTrack" -> {
                val id = call.argument<Int>("id") ?: -1
                synchronized(vlcLock) { mediaPlayer?.spuTrack = id }
                result.success(null)
            }
            "setAspectRatio" -> {
                val ratio = call.argument<String>("aspectRatio")
                synchronized(vlcLock) {
                    mediaPlayer?.aspectRatio = if (ratio.isNullOrBlank()) null else ratio
                }
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    fun dispose() {
        synchronized(vlcLock) {
            try {
                mediaPlayer?.setEventListener(null)
                mediaPlayer?.stop()
                mediaPlayer?.media = null
                mediaPlayer?.detachViews()
                currentMedia?.release()
                mediaPlayer?.release()
                libVlc?.release()
            } catch (_: Exception) {
            } finally {
                currentMedia = null
                mediaPlayer = null
                libVlc = null
                attachedLayout = null
                eventSink = null
            }
        }
    }
}

private class LibVlcViewFactory(
    private val plugin: LibVlcPlayerPlugin,
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        return LibVlcPlatformView(context, plugin)
    }
}

private class LibVlcPlatformView(
    context: Context,
    private val plugin: LibVlcPlayerPlugin,
) : PlatformView {
    private val videoLayout = VLCVideoLayout(context)

    init {
        plugin.attachLayout(videoLayout)
    }

    override fun getView(): View = videoLayout

    override fun dispose() {
        plugin.detachLayout(videoLayout)
    }
}
