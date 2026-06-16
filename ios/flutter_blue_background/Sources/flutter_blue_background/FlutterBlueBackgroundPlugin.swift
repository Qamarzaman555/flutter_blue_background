import Flutter
import UIKit

public class FlutterBlueBackgroundPlugin: NSObject, FlutterPlugin {
  private let backgroundService = BackgroundService.shared
  private let bleScanner = BleScanner()

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "flutter_blue_background", binaryMessenger: registrar.messenger())
    let instance = FlutterBlueBackgroundPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)

    let scanResultsChannel = FlutterEventChannel(
      name: "flutter_blue_background/scan_results",
      binaryMessenger: registrar.messenger()
    )
    scanResultsChannel.setStreamHandler(instance.bleScanner)
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

    case "startScan":
      let config = (call.arguments as? [String: Any]) ?? [:]
      result(bleScanner.startScan(config))

    case "stopScan":
      result(bleScanner.stopScan())

    case "isScanning":
      result(bleScanner.isScanning)

    default:
      result(FlutterMethodNotImplemented)
    }
  }

  public func detachFromEngine(for registrar: FlutterPluginRegistrar) {
    bleScanner.dispose()
  }
}
