package com.filimuplus.filimu_plus

import android.content.Context
import android.net.Uri
import android.os.Handler
import android.os.Looper
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
        const val METHOD_CHANNEL = "tamba_iptv/libvlc"
        const val EVENT_CHANNEL = "tamba_iptv/libvlc_events"
        const val VIEW_TYPE = "tamba_iptv/libvlc_view"
    }

    private val mainHandler = Handler(Looper.getMainLooper())
    private var libVlc: LibVLC? = null
    private var mediaPlayer: MediaPlayer? = null
    private var currentMedia: Media? = null
    private var attachedLayout: VLCVideoLayout? = null
    private var eventSink: EventChannel.EventSink? = null

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
        return player
    }

    internal fun attachLayout(layout: VLCVideoLayout) {
        mainHandler.post {
            val player = ensureInitialized()
            if (attachedLayout != null && attachedLayout !== layout) {
                try {
                    player.detachViews()
                } catch (_: Exception) {
                }
            }
            attachedLayout = layout
            try {
                player.attachViews(layout, null, true, false)
            } catch (_: Exception) {
            }
        }
    }

    internal fun detachLayout(layout: VLCVideoLayout) {
        mainHandler.post {
            if (attachedLayout === layout) {
                try {
                    mediaPlayer?.detachViews()
                } catch (_: Exception) {
                }
                attachedLayout = null
            }
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
                emit(mapOf("type" to "buffering", "buffering" to false))
                emit(mapOf("type" to "playing", "playing" to false))
                emit(
                    mapOf(
                        "type" to "error",
                        "message" to "LibVLC could not play this stream. The source may be offline or unsupported."
                    )
                )
            }
            MediaPlayer.Event.TimeChanged -> {
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
            eventSink?.success(payload)
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
                    val player = ensureInitialized()
                    val vlc = libVlc!!
                    currentMedia?.release()

                    val media = Media(vlc, Uri.parse(url))
                    media.setHWDecoderEnabled(hwDecoding, false)
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

                    currentMedia = media
                    player.media = media
                    attachedLayout?.let { layout ->
                        if (!player.vlcVout.areViewsAttached()) {
                            player.attachViews(layout, null, true, false)
                        }
                    }
                    player.play()
                    result.success(null)
                } catch (e: Exception) {
                    result.error("OPEN_FAILED", e.message, null)
                }
            }
            "play" -> {
                mediaPlayer?.play()
                result.success(null)
            }
            "pause" -> {
                mediaPlayer?.pause()
                result.success(null)
            }
            "togglePlayPause" -> {
                val player = mediaPlayer
                if (player != null) {
                    if (player.isPlaying) player.pause() else player.play()
                }
                result.success(null)
            }
            "stop" -> {
                try {
                    mediaPlayer?.stop()
                    currentMedia?.release()
                    currentMedia = null
                } catch (_: Exception) {
                }
                result.success(null)
            }
            "seek" -> {
                val posMs = call.argument<Number>("positionMs")?.toLong() ?: 0L
                mediaPlayer?.time = posMs.coerceAtLeast(0L)
                result.success(null)
            }
            "setVolume" -> {
                val vol = call.argument<Number>("volume")?.toInt() ?: 100
                mediaPlayer?.volume = vol.coerceIn(0, 100)
                result.success(null)
            }
            "setRate" -> {
                val rate = call.argument<Number>("rate")?.toFloat() ?: 1.0f
                mediaPlayer?.rate = rate.coerceIn(0.25f, 4.0f)
                result.success(null)
            }
            "setAudioTrack" -> {
                val id = call.argument<Int>("id") ?: -1
                mediaPlayer?.audioTrack = id
                result.success(null)
            }
            "setSubtitleTrack" -> {
                val id = call.argument<Int>("id") ?: -1
                mediaPlayer?.spuTrack = id
                result.success(null)
            }
            "setAspectRatio" -> {
                val ratio = call.argument<String>("aspectRatio")
                mediaPlayer?.aspectRatio = if (ratio.isNullOrBlank()) null else ratio
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
        try {
            mediaPlayer?.stop()
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
