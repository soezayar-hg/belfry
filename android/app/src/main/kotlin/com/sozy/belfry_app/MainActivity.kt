package com.sozy.belfry_app

import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        private const val CHANNEL = "belfry/watcher"
        private const val TAG = "BelfryWatcher"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        Log.d(TAG, "configureFlutterEngine: wiring belfry/watcher channel")
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                Log.d(TAG, "channel call: ${call.method}")
                when (call.method) {
                    "start" -> {
                        try {
                            BelfryService.start(applicationContext)
                            Log.d(TAG, "BelfryService.start() returned")
                            result.success(null)
                        } catch (e: Throwable) {
                            Log.e(TAG, "BelfryService.start() threw", e)
                            result.error("START_FAILED", e.message, null)
                        }
                    }
                    "stop" -> {
                        BelfryService.stop(applicationContext)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
