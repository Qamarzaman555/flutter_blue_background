import Flutter
import UIKit

public class FlutterBlueBackgroundPlugin: NSObject, FlutterPlugin {
  private let backgroundService = BackgroundService.shared

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "flutter_blue_background", binaryMessenger: registrar.messenger())
    let instance = FlutterBlueBackgroundPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getPlatformVersion":
      result("iOS " + UIDevice.current.systemVersion)

    case "startService":
      // notificationTitle / notificationContent are Android-only and ignored on iOS.
      backgroundService.start()
      result(true)

    case "stopService":
      backgroundService.stop()
      result(true)

    case "isServiceRunning":
      result(backgroundService.isServiceRunning())

    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
