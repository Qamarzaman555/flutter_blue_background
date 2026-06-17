import Flutter
import UIKit

public class FlutterBlueBackgroundPlugin: NSObject, FlutterPlugin {
  private let backgroundService = BackgroundService.shared
  private let bleScanner = BleScanner()
  private var adapterStateStreamHandler: BleAdapterStateStreamHandler?

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "flutter_blue_background", binaryMessenger: registrar.messenger())
    let instance = FlutterBlueBackgroundPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)

    let scanResultsChannel = FlutterEventChannel(
      name: "flutter_blue_background/scan_results",
      binaryMessenger: registrar.messenger()
    )
    scanResultsChannel.setStreamHandler(instance.bleScanner)

    let adapterStateHandler = BleAdapterStateStreamHandler(scanner: instance.bleScanner)
    instance.adapterStateStreamHandler = adapterStateHandler
    let adapterStateChannel = FlutterEventChannel(
      name: "flutter_blue_background/adapter_state",
      binaryMessenger: registrar.messenger()
    )
    adapterStateChannel.setStreamHandler(adapterStateHandler)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getPlatformVersion":
      result("iOS " + UIDevice.current.systemVersion)

    case "getAdapterState":
      result(bleScanner.getAdapterState())

    case "startService":
      backgroundService.start()
      result(true)

    case "stopService":
      backgroundService.stop()
      _ = bleScanner.stopScan()
      result(true)

    case "isServiceRunning":
      result(backgroundService.isServiceRunning())

    case "startScan":
      // Scanning requires the background service to be started first; it must
      // not implicitly start it.
      guard backgroundService.isServiceRunning() else {
        result(false)
        return
      }
      let config = (call.arguments as? [String: Any]) ?? [:]
      result(bleScanner.startScan(config))

    case "stopScan":
      result(bleScanner.stopScan())

    case "isScanning":
      result(bleScanner.isScanning)

    case "getScanResults":
      result(bleScanner.getScanResults())

    case "clearScanResults":
      bleScanner.clearCache()
      result(true)

    default:
      result(FlutterMethodNotImplemented)
    }
  }

  public func detachFromEngine(for registrar: FlutterPluginRegistrar) {
    bleScanner.detachSink()
    bleScanner.detachAdapterStateSink()
    adapterStateStreamHandler = nil
  }
}
