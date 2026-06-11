package com.yourname.second_brain

import android.app.ActivityManager
import android.content.Context
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Exposes total device RAM (MB) to Dart so OnDeviceAiService can pick the
 * right on-device model tier (or fall back to cloud on weak devices).
 *
 * NOTE: keep the package in sync with the --org you pass to `flutter create .`
 * (README uses --org com.yourname → package com.yourname.second_brain).
 */
class MainActivity : FlutterActivity() {
    private val channelName = "second_brain/device"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getTotalRamMb" -> {
                        val mi = ActivityManager.MemoryInfo()
                        val am = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
                        am.getMemoryInfo(mi)
                        result.success((mi.totalMem / (1024L * 1024L)).toInt())
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
