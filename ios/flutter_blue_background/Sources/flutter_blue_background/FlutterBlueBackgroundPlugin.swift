import Flutter
import UIKit

public class FlutterBlueBackgroundPlugin: NSObject, FlutterPlugin {
  private let backgroundService = BackgroundService.shared
  private let bleScanner = BleScanner()
  private lazy var bleConnector = BleConnector(scanner: bleScanner)
  private var adapterStateStreamHandler: BleAdapterStateStreamHandler?

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "flutter_blue_background", binaryMessenger: registrar.messenger())
    let instance = FlutterBlueBackgroundPlugin()
    instance.bleScanner.connector = instance.bleConnector
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

    let connectionStateChannel = FlutterEventChannel(
      name: "flutter_blue_background/connection_state",
      binaryMessenger: registrar.messenger()
    )
    connectionStateChannel.setStreamHandler(instance.bleConnector)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    FbbLog.debug("onMethodCall: \(call.method)")
    switch call.method {
    case "setLogLevel":
      let idx = call.arguments as? Int ?? FbbLogLevel.debug.rawValue
      FbbLog.setLevel(idx)
      result(nil)

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
      bleConnector.dispose()
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
      guard bleScanner.isAdapterReady() else {
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

    case "connect":
      guard backgroundService.isServiceRunning() else {
        result(false)
        return
      }
      guard bleScanner.isAdapterReady() else {
        result(false)
        return
      }
      guard let args = call.arguments as? [String: Any],
            let deviceId = args["deviceId"] as? String,
            !deviceId.isEmpty else {
        result(false)
        return
      }
      let config = (args["config"] as? [String: Any]) ?? [:]
      result(bleConnector.connect(deviceId: deviceId, config: config))

    case "disconnect":
      guard let args = call.arguments as? [String: Any],
            let deviceId = args["deviceId"] as? String,
            !deviceId.isEmpty else {
        result(false)
        return
      }
      let config = (args["config"] as? [String: Any]) ?? [:]
      result(bleConnector.disconnect(deviceId: deviceId, config: config))

    case "getConnectionState":
      let args = call.arguments as? [String: Any]
      let deviceId = args?["deviceId"] as? String ?? ""
      result(bleConnector.getConnectionState(deviceId: deviceId))

    case "getConnectedDevices":
      result(bleConnector.getConnectedDeviceIds())

    case "requestMtu":
      guard let args = call.arguments as? [String: Any],
            let deviceId = args["deviceId"] as? String,
            let mtu = args["mtu"] as? Int,
            bleScanner.isAdapterReady() else {
        result(23)
        return
      }
      result(bleConnector.requestMtu(deviceId: deviceId, mtu: mtu))

    case "requestConnectionPriority":
      guard let args = call.arguments as? [String: Any],
            let deviceId = args["deviceId"] as? String,
            let priority = args["priority"] as? Int else {
        result(nil)
        return
      }
      bleConnector.requestConnectionPriority(deviceId: deviceId, priority: priority)
      result(nil)

    case "discoverServices":
      guard let args = call.arguments as? [String: Any],
            let deviceId = args["deviceId"] as? String,
            bleScanner.isAdapterReady() else {
        result([])
        return
      }
      let timeoutMillis = args["timeoutMillis"] as? Int ?? 15_000
      let subscribe = args["subscribeToServicesChanged"] as? Bool ?? true
      let services = bleConnector.discoverServices(
        deviceId: deviceId,
        timeoutMillis: timeoutMillis,
        subscribeToServicesChanged: subscribe
      ) ?? []
      result(services)

    default:
      result(FlutterMethodNotImplemented)
    }
  }

  public func detachFromEngine(for registrar: FlutterPluginRegistrar) {
    bleScanner.detachSink()
    bleScanner.detachAdapterStateSink()
    bleConnector.detachSink()
    adapterStateStreamHandler = nil
  }
}
