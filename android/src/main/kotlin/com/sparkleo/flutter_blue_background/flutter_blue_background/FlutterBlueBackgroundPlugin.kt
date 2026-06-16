package com.sparkleo.flutter_blue_background.flutter_blue_background

import android.content.Context
import android.content.Intent
import android.os.Build
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

/** FlutterBlueBackgroundPlugin */
class FlutterBlueBackgroundPlugin :
    FlutterPlugin,
    MethodCallHandler {
    // The MethodChannel that will the communication between Flutter and native Android
    //
    // This local reference serves to register the plugin with the Flutter Engine and unregister it
    // when the Flutter Engine is detached from the Activity
    private lateinit var channel: MethodChannel
    private lateinit var scanResultsChannel: EventChannel
    private lateinit var context: Context

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        context = flutterPluginBinding.applicationContext

        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "flutter_blue_background")
        channel.setMethodCallHandler(this)

        scanResultsChannel = EventChannel(
            flutterPluginBinding.binaryMessenger,
            "flutter_blue_background/scan_results",
        )
        // Bridge the engine-bound event channel to the process-wide dispatcher so
        // results produced by the service-owned scanner reach Dart, and so the
        // cache is replayed whenever a fresh engine attaches.
        scanResultsChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                ScanResultDispatcher.setSink(events)
            }

            override fun onCancel(arguments: Any?) {
                ScanResultDispatcher.setSink(null)
            }
        })
    }

    override fun onMethodCall(
        call: MethodCall,
        result: Result
    ) {
        when (call.method) {
            "getPlatformVersion" -> {
                result.success("Android ${android.os.Build.VERSION.RELEASE}")
            }
            "startService" -> {
                val title = call.argument<String>("notificationTitle")
                val content = call.argument<String>("notificationContent")
                startService(title, content, null, null)
                result.success(true)
            }
            "stopService" -> {
                stopService()
                result.success(true)
            }
            "isServiceRunning" -> {
                result.success(FlutterBlueBackgroundService.isRunning)
            }
            "startScan" -> {
                @Suppress("UNCHECKED_CAST")
                val config = (call.arguments as? Map<String, Any?>) ?: emptyMap()
                // Scanning runs inside the foreground service so it survives the
                // app being removed from recents. Starting the scan (re)starts
                // the service with the scan action.
                val json = ScanConfigCodec.encode(config)
                startService(null, null, FlutterBlueBackgroundService.ACTION_START_SCAN, json)
                result.success(true)
            }
            "stopScan" -> {
                if (FlutterBlueBackgroundService.isRunning) {
                    startService(null, null, FlutterBlueBackgroundService.ACTION_STOP_SCAN, null)
                } else {
                    ScanResultDispatcher.isScanning = false
                }
                result.success(true)
            }
            "isScanning" -> {
                result.success(isScanningState())
            }
            "getScanResults" -> {
                result.success(ScanResultDispatcher.snapshot())
            }
            "clearScanResults" -> {
                ScanResultDispatcher.clearCache()
                result.success(true)
            }
            else -> result.notImplemented()
        }
    }

    /**
     * Whether a scan is (or should be) running. Prefers the live runtime flag,
     * but falls back to the persisted intent so the state survives a full
     * process restart where the service may still be resuming the scan.
     */
    private fun isScanningState(): Boolean {
        if (ScanResultDispatcher.isScanning) return true
        val prefs = context.getSharedPreferences(
            FlutterBlueBackgroundService.PREFS_NAME,
            Context.MODE_PRIVATE,
        )
        return prefs.getBoolean(FlutterBlueBackgroundService.KEY_SCAN_ENABLED, false)
    }

    private fun startService(
        title: String?,
        content: String?,
        action: String?,
        scanConfigJson: String?,
    ) {
        val serviceIntent = Intent(context, FlutterBlueBackgroundService::class.java).apply {
            action?.let { this.action = it }
            title?.let { putExtra(FlutterBlueBackgroundService.EXTRA_NOTIFICATION_TITLE, it) }
            content?.let { putExtra(FlutterBlueBackgroundService.EXTRA_NOTIFICATION_CONTENT, it) }
            scanConfigJson?.let { putExtra(FlutterBlueBackgroundService.EXTRA_SCAN_CONFIG, it) }
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            context.startForegroundService(serviceIntent)
        } else {
            context.startService(serviceIntent)
        }
    }

    private fun stopService() {
        FlutterBlueBackgroundService.markStopRequested()
        context.stopService(Intent(context, FlutterBlueBackgroundService::class.java))
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        scanResultsChannel.setStreamHandler(null)
        // Detach the sink only. The scanner lives in the foreground service and
        // must keep running while the engine is gone (e.g. app swiped away).
        ScanResultDispatcher.setSink(null)
    }
}
