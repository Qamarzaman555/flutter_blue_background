import 'flutter_blue_background_platform_interface.dart';
import 'src/models/ble_adapter_state.dart';
import 'src/models/ble_connection_state.dart';
import 'src/models/ble_gatt_service.dart';
import 'src/models/ble_scan_result.dart';
import 'src/models/connect_config.dart';
import 'src/models/scan_config.dart';

export 'src/models/ble_adapter_state.dart';
export 'src/models/ble_connection_state.dart';
export 'src/models/ble_gatt_service.dart';
export 'src/models/ble_scan_result.dart';
export 'src/models/connect_config.dart';
export 'src/models/scan_config.dart';

class FlutterBlueBackground {
  Future<String?> getPlatformVersion() {
    return FlutterBlueBackgroundPlatform.instance.getPlatformVersion();
  }

  /// Starts the native background (foreground) service so the app keeps
  /// running in the background. On Android this shows a persistent
  /// notification.
  ///
  /// Optionally customize the notification [notificationTitle] and
  /// [notificationContent].
  Future<bool> startService({
    String? notificationTitle,
    String? notificationContent,
  }) {
    return FlutterBlueBackgroundPlatform.instance.startService(
      notificationTitle: notificationTitle,
      notificationContent: notificationContent,
    );
  }

  /// Stops the native background service.
  Future<bool> stopService() {
    return FlutterBlueBackgroundPlatform.instance.stopService();
  }

  /// Returns whether the native background service is currently running.
  Future<bool> isServiceRunning() {
    return FlutterBlueBackgroundPlatform.instance.isServiceRunning();
  }

  /// Returns the current Bluetooth adapter (radio) state.
  Future<BleAdapterState> getAdapterState() {
    return FlutterBlueBackgroundPlatform.instance.getAdapterState();
  }

  /// A stream of Bluetooth adapter state changes.
  Stream<BleAdapterState> get adapterState =>
      FlutterBlueBackgroundPlatform.instance.adapterState;

  /// Starts a BLE scan using [config].
  ///
  /// Discovered devices are delivered on [scanResults]. Calling this while a
  /// scan is already running restarts the scan with the new [config].
  Future<bool> startScan([ScanConfig config = const ScanConfig()]) {
    return FlutterBlueBackgroundPlatform.instance.startScan(config);
  }

  /// Stops an in-progress BLE scan.
  Future<bool> stopScan() {
    return FlutterBlueBackgroundPlatform.instance.stopScan();
  }

  /// Whether a BLE scan is currently running.
  Future<bool> isScanning() {
    return FlutterBlueBackgroundPlatform.instance.isScanning();
  }

  /// A broadcast stream of BLE devices discovered during a scan.
  Stream<BleScanResult> get scanResults =>
      FlutterBlueBackgroundPlatform.instance.scanResults;

  /// Returns the cached snapshot of devices discovered during the current or
  /// most recent scan. On Android this includes devices found while the app UI
  /// was gone but the foreground service kept scanning.
  Future<List<BleScanResult>> getScanResults() {
    return FlutterBlueBackgroundPlatform.instance.getScanResults();
  }

  /// Clears the cached scan results.
  Future<bool> clearScanResults() {
    return FlutterBlueBackgroundPlatform.instance.clearScanResults();
  }

  /// Connects to [deviceId] (from [BleScanResult.deviceId]) using [config].
  ///
  /// Requires [startService] to be running first. When [ConnectConfig.autoConnect]
  /// is true, this returns once the native connect is initiated; listen to
  /// [connectionState] for the connected event.
  Future<bool> connect(
    String deviceId, [
    ConnectConfig config = const ConnectConfig(),
  ]) {
    return FlutterBlueBackgroundPlatform.instance.connect(deviceId, config);
  }

  /// Disconnects from [deviceId].
  Future<bool> disconnect(
    String deviceId, [
    DisconnectConfig config = const DisconnectConfig(),
  ]) {
    return FlutterBlueBackgroundPlatform.instance.disconnect(deviceId, config);
  }

  /// Cached connection state for [deviceId].
  Future<BleConnectionState> getConnectionState(String deviceId) {
    return FlutterBlueBackgroundPlatform.instance.getConnectionState(deviceId);
  }

  /// Device ids currently connected.
  Future<List<String>> getConnectedDevices() {
    return FlutterBlueBackgroundPlatform.instance.getConnectedDevices();
  }

  /// Broadcast stream of GATT connection state changes.
  Stream<BleConnectionEvent> get connectionState =>
      FlutterBlueBackgroundPlatform.instance.connectionState;

  /// Requests a larger ATT MTU (Android only).
  Future<int> requestMtu(String deviceId, int mtu) {
    return FlutterBlueBackgroundPlatform.instance.requestMtu(deviceId, mtu);
  }

  /// Requests a connection priority update (Android only).
  Future<void> requestConnectionPriority(
    String deviceId,
    ConnectionPriority priority,
  ) {
    return FlutterBlueBackgroundPlatform.instance.requestConnectionPriority(
      deviceId,
      priority,
    );
  }

  /// Discovers GATT services on a connected device.
  Future<List<BleGattService>> discoverServices(
    String deviceId, {
    Duration timeout = const Duration(seconds: 15),
    bool subscribeToServicesChanged = true,
  }) {
    return FlutterBlueBackgroundPlatform.instance.discoverServices(
      deviceId,
      timeout: timeout,
      subscribeToServicesChanged: subscribeToServicesChanged,
    );
  }
}
