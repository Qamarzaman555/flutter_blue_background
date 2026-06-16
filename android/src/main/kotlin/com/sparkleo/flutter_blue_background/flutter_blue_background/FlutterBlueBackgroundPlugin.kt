package com.sparkleo.flutter_blue_background.flutter_blue_background

import android.content.Context
import android.content.Intent
import android.os.Build
import io.flutter.embedding.engine.plugins.FlutterPlugin
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
    private lateinit var context: Context

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        context = flutterPluginBinding.applicationContext
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "flutter_blue_background")
        channel.setMethodCallHandler(this)
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
                startService(title, content)
                result.success(true)
            }
            "stopService" -> {
                stopService()
                result.success(true)
            }
            "isServiceRunning" -> {
                result.success(FlutterBlueBackgroundService.isRunning)
            }
            else -> result.notImplemented()
        }
    }

    private fun startService(title: String?, content: String?) {
        val serviceIntent = Intent(context, FlutterBlueBackgroundService::class.java).apply {
            title?.let { putExtra(FlutterBlueBackgroundService.EXTRA_NOTIFICATION_TITLE, it) }
            content?.let { putExtra(FlutterBlueBackgroundService.EXTRA_NOTIFICATION_CONTENT, it) }
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
    }
}
