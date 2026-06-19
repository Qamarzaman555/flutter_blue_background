import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'flutter_blue_background_platform_interface.dart';
import 'src/models/ble_adapter_state.dart';
import 'src/models/ble_connection_state.dart';
import 'src/models/ble_gatt_service.dart';
import 'src/models/ble_scan_result.dart';
import 'src/models/connect_config.dart';
import 'src/models/scan_config.dart';

/// An implementation of [FlutterBlueBackgroundPlatform] that uses method channels.
class MethodChannelFlutterBlueBackground extends FlutterBlueBackgroundPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('flutter_blue_background');

  /// The event channel that streams BLE scan results from the native platform.
  @visibleForTesting
  final scanResultsChannel =
      const EventChannel('flutter_blue_background/scan_results');

  /// The event channel that streams Bluetooth adapter state changes.
  @visibleForTesting
  final adapterStateChannel =
      const EventChannel('flutter_blue_background/adapter_state');

  /// The event channel that streams GATT connection state changes.
  @visibleForTesting
  final connectionStateChannel =
      const EventChannel('flutter_blue_background/connection_state');

  Stream<BleScanResult>? _scanResults;
  Stream<BleAdapterState>? _adapterState;
  Stream<BleConnectionEvent>? _connectionState;

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>(
      'getPlatformVersion',
    );
    return version;
  }

  @override
  Future<bool> startService({
    String? notificationTitle,
    String? notificationContent,
  }) async {
    final started = await methodChannel.invokeMethod<bool>('startService', {
      'notificationTitle': notificationTitle,
      'notificationContent': notificationContent,
    });
    return started ?? false;
  }

  @override
  Future<bool> stopService() async {
    final stopped = await methodChannel.invokeMethod<bool>('stopService');
    return stopped ?? false;
  }

  @override
  Future<bool> isServiceRunning() async {
    final running = await methodChannel.invokeMethod<bool>('isServiceRunning');
    return running ?? false;
  }

  @override
  Future<BleAdapterState> getAdapterState() async {
    final state = await methodChannel.invokeMethod<String>('getAdapterState');
    return BleAdapterState.fromNative(state);
  }

  @override
  Stream<BleAdapterState> get adapterState {
    _adapterState ??= adapterStateChannel
        .receiveBroadcastStream()
        .map((event) => BleAdapterState.fromNative(event as String?));
    return _adapterState!;
  }

  @override
  Future<bool> startScan(ScanConfig config) async {
    final started = await methodChannel.invokeMethod<bool>(
      'startScan',
      config.toMap(),
    );
    return started ?? false;
  }

  @override
  Future<bool> stopScan() async {
    final stopped = await methodChannel.invokeMethod<bool>('stopScan');
    return stopped ?? false;
  }

  @override
  Future<bool> isScanning() async {
    final scanning = await methodChannel.invokeMethod<bool>('isScanning');
    return scanning ?? false;
  }

  @override
  Stream<BleScanResult> get scanResults {
    _scanResults ??= scanResultsChannel
        .receiveBroadcastStream()
        .map((event) => BleScanResult.fromMap(event as Map<dynamic, dynamic>));
    return _scanResults!;
  }

  @override
  Future<List<BleScanResult>> getScanResults() async {
    final results = await methodChannel.invokeMethod<List<dynamic>>(
      'getScanResults',
    );
    if (results == null) return const [];
    return results
        .map((e) => BleScanResult.fromMap(e as Map<dynamic, dynamic>))
        .toList();
  }

  @override
  Future<bool> clearScanResults() async {
    final cleared = await methodChannel.invokeMethod<bool>('clearScanResults');
    return cleared ?? false;
  }

  @override
  Future<bool> connect(String deviceId, ConnectConfig config) async {
    final connected = await methodChannel.invokeMethod<bool>('connect', {
      'deviceId': deviceId,
      'config': config.toMap(),
    });
    return connected ?? false;
  }

  @override
  Future<bool> disconnect(String deviceId, DisconnectConfig config) async {
    final disconnected = await methodChannel.invokeMethod<bool>('disconnect', {
      'deviceId': deviceId,
      'config': config.toMap(),
    });
    return disconnected ?? false;
  }

  @override
  Future<BleConnectionState> getConnectionState(String deviceId) async {
    final state = await methodChannel.invokeMethod<String>(
      'getConnectionState',
      {'deviceId': deviceId},
    );
    return BleConnectionState.fromNative(state);
  }

  @override
  Future<List<String>> getConnectedDevices() async {
    final devices = await methodChannel.invokeMethod<List<dynamic>>(
      'getConnectedDevices',
    );
    if (devices == null) return const [];
    return devices.map((e) => e.toString()).toList();
  }

  @override
  Stream<BleConnectionEvent> get connectionState {
    _connectionState ??= connectionStateChannel.receiveBroadcastStream().map(
        (event) => BleConnectionEvent.fromMap(event as Map<dynamic, dynamic>));
    return _connectionState!;
  }

  @override
  Future<int> requestMtu(String deviceId, int mtu) async {
    final result = await methodChannel.invokeMethod<int>('requestMtu', {
      'deviceId': deviceId,
      'mtu': mtu,
    });
    return result ?? 23;
  }

  @override
  Future<void> requestConnectionPriority(
    String deviceId,
    ConnectionPriority priority,
  ) async {
    await methodChannel.invokeMethod<void>('requestConnectionPriority', {
      'deviceId': deviceId,
      'priority': priority.nativeValue,
    });
  }

  @override
  Future<List<BleGattService>> discoverServices(
    String deviceId, {
    Duration timeout = const Duration(seconds: 15),
    bool subscribeToServicesChanged = true,
  }) async {
    final services = await methodChannel.invokeMethod<List<dynamic>>(
      'discoverServices',
      {
        'deviceId': deviceId,
        'timeoutMillis': timeout.inMilliseconds,
        'subscribeToServicesChanged': subscribeToServicesChanged,
      },
    );
    if (services == null) return const [];
    return services
        .map((e) => BleGattService.fromMap(e as Map<dynamic, dynamic>))
        .toList();
  }
}
