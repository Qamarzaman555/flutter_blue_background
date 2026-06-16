import 'flutter_blue_background_platform_interface.dart';
import 'src/models/ble_scan_result.dart';
import 'src/models/scan_config.dart';

export 'src/models/ble_scan_result.dart';
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
}
