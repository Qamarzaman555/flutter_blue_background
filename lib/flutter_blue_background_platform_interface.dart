import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'flutter_blue_background_method_channel.dart';
import 'src/models/ble_scan_result.dart';
import 'src/models/scan_config.dart';

abstract class FlutterBlueBackgroundPlatform extends PlatformInterface {
  /// Constructs a FlutterBlueBackgroundPlatform.
  FlutterBlueBackgroundPlatform() : super(token: _token);

  static final Object _token = Object();

  static FlutterBlueBackgroundPlatform _instance = MethodChannelFlutterBlueBackground();

  /// The default instance of [FlutterBlueBackgroundPlatform] to use.
  ///
  /// Defaults to [MethodChannelFlutterBlueBackground].
  static FlutterBlueBackgroundPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [FlutterBlueBackgroundPlatform] when
  /// they register themselves.
  static set instance(FlutterBlueBackgroundPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }

  /// Starts the native background (foreground) service.
  ///
  /// Optionally customizes the persistent notification shown while the service
  /// is running.
  Future<bool> startService({
    String? notificationTitle,
    String? notificationContent,
  }) {
    throw UnimplementedError('startService() has not been implemented.');
  }

  /// Stops the native background service.
  Future<bool> stopService() {
    throw UnimplementedError('stopService() has not been implemented.');
  }

  /// Whether the native background service is currently running.
  Future<bool> isServiceRunning() {
    throw UnimplementedError('isServiceRunning() has not been implemented.');
  }

  /// Starts a BLE scan using [config].
  Future<bool> startScan(ScanConfig config) {
    throw UnimplementedError('startScan() has not been implemented.');
  }

  /// Stops an in-progress BLE scan.
  Future<bool> stopScan() {
    throw UnimplementedError('stopScan() has not been implemented.');
  }

  /// Whether a BLE scan is currently running.
  Future<bool> isScanning() {
    throw UnimplementedError('isScanning() has not been implemented.');
  }

  /// A broadcast stream of BLE devices discovered during a scan.
  Stream<BleScanResult> get scanResults {
    throw UnimplementedError('scanResults has not been implemented.');
  }

  /// Returns the cached snapshot of devices discovered during the current or
  /// most recent scan.
  ///
  /// Useful after returning to the foreground: on Android the scan keeps running
  /// inside the foreground service while the UI is gone, so this returns
  /// everything found in the meantime.
  Future<List<BleScanResult>> getScanResults() {
    throw UnimplementedError('getScanResults() has not been implemented.');
  }

  /// Clears the cached scan results.
  Future<bool> clearScanResults() {
    throw UnimplementedError('clearScanResults() has not been implemented.');
  }
}
