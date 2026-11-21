package com.filimuplus.filimu_plus

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private var libVlcPlugin: LibVlcPlayerPlugin? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val plugin = LibVlcPlayerPlugin(this)
        plugin.register(flutterEngine)
        libVlcPlugin = plugin
    }

    override fun onDestroy() {
        libVlcPlugin?.dispose()
        libVlcPlugin = null
        super.onDestroy()
    }
}
