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
    private lateinit var channel: MethodChannel
    private lateinit var scanResultsChannel: EventChannel
    private lateinit var adapterStateChannel: EventChannel
    private lateinit var context: Context
    private var adapterStateStreamHandler: BleAdapterStateStreamHandler? = null

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        context = flutterPluginBinding.applicationContext

        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "flutter_blue_background")
        channel.setMethodCallHandler(this)

        scanResultsChannel = EventChannel(
            flutterPluginBinding.binaryMessenger,
            "flutter_blue_background/scan_results",
        )
        scanResultsChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                ScanResultDispatcher.setSink(events)
            }

            override fun onCancel(arguments: Any?) {
                ScanResultDispatcher.setSink(null)
            }
        })

        adapterStateStreamHandler = BleAdapterStateStreamHandler(context)
        adapterStateChannel = EventChannel(
            flutterPluginBinding.binaryMessenger,
            "flutter_blue_background/adapter_state",
        )
        adapterStateChannel.setStreamHandler(adapterStateStreamHandler)
    }

    override fun onMethodCall(
        call: MethodCall,
        result: Result
    ) {
        when (call.method) {
            "getPlatformVersion" -> {
                result.success("Android ${android.os.Build.VERSION.RELEASE}")
            }
            "getAdapterState" -> {
                result.success(BleAdapterState.getState(context))
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
                // Scanning runs inside the foreground service but must NOT start
                // it. The service is started only via startService(). If it is
                // not running, the scan is rejected.
                if (!FlutterBlueBackgroundService.isRunning) {
                    result.success(false)
                    return
                }
                if (!BleAdapterState.isReady(context)) {
                    result.success(false)
                    return
                }
                @Suppress("UNCHECKED_CAST")
                val config = (call.arguments as? Map<String, Any?>) ?: emptyMap()
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
        adapterStateChannel.setStreamHandler(null)
        adapterStateStreamHandler = null
        ScanResultDispatcher.setSink(null)
    }
}
