package com.filimuplus.filimu_plus

import android.app.UiModeManager
import android.content.Context
import android.content.pm.PackageManager
import android.content.res.Configuration
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var libVlcPlugin: LibVlcPlayerPlugin? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val plugin = LibVlcPlayerPlugin(this)
        plugin.register(flutterEngine)
        libVlcPlugin = plugin

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "tamba_iptv/device"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "isAndroidTv" -> {
                    val uiModeManager =
                        getSystemService(Context.UI_MODE_SERVICE) as? UiModeManager
                    val isTvUiMode =
                        uiModeManager?.currentModeType == Configuration.UI_MODE_TYPE_TELEVISION
                    val hasLeanback =
                        packageManager.hasSystemFeature(PackageManager.FEATURE_LEANBACK)
                    result.success(isTvUiMode || hasLeanback)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        libVlcPlugin?.dispose()
        libVlcPlugin = null
        super.onDestroy()
    }
}
