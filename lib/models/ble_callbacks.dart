import 'package:flutter_blue_plus/flutter_blue_plus.dart';

/// Callback function type for device connection events
typedef DeviceConnectionCallback = void Function(
    BluetoothDevice device, bool isConnected);

/// Callback function type for data received events
typedef DataReceivedCallback = void Function(
    List<int> data, String characteristicUuid);

/// Callback function type for data sent events
typedef DataSentCallback = void Function(
    String data, String characteristicUuid);

/// Callback function type for scan results
typedef ScanResultCallback = void Function(List<BluetoothDevice> devices);

/// Callback function type for service events
typedef ServiceEventCallback = void Function(ServiceEvent event);

/// Callback function type for error events
typedef ErrorCallback = void Function(String error, Exception? exception);

/// Callback function type for data processing
typedef DataProcessingCallback = String? Function(List<int> rawData);

/// Service event types
enum ServiceEventType {
  started,
  stopped,
  paused,
  resumed,
  error,
  configurationChanged,
}

/// Service event data
class ServiceEvent {
  final ServiceEventType type;
  final String? message;
  final Map<String, dynamic>? data;
  final DateTime timestamp;

  const ServiceEvent({
    required this.type,
    this.message,
    this.data,
    required this.timestamp,
  });

  @override
  String toString() {
    return 'ServiceEvent(type: $type, message: $message, data: $data, timestamp: $timestamp)';
  }
}

/// BLE callbacks configuration
class BleCallbacks {
  /// Called when a device connects or disconnects
  final DeviceConnectionCallback? onDeviceConnection;

  /// Called when data is received from a characteristic
  final DataReceivedCallback? onDataReceived;

  /// Called when data is successfully sent to a characteristic
  final DataSentCallback? onDataSent;

  /// Called when scan results are available
  final ScanResultCallback? onScanResults;

  /// Called when service events occur
  final ServiceEventCallback? onServiceEvent;

  /// Called when errors occur
  final ErrorCallback? onError;

  /// Called to process raw data before storing
  final DataProcessingCallback? onDataProcessing;

  const BleCallbacks({
    this.onDeviceConnection,
    this.onDataReceived,
    this.onDataSent,
    this.onScanResults,
    this.onServiceEvent,
    this.onError,
    this.onDataProcessing,
  });

  /// Create a copy with updated callbacks
  BleCallbacks copyWith({
    DeviceConnectionCallback? onDeviceConnection,
    DataReceivedCallback? onDataReceived,
    DataSentCallback? onDataSent,
    ScanResultCallback? onScanResults,
    ServiceEventCallback? onServiceEvent,
    ErrorCallback? onError,
    DataProcessingCallback? onDataProcessing,
  }) {
    return BleCallbacks(
      onDeviceConnection: onDeviceConnection ?? this.onDeviceConnection,
      onDataReceived: onDataReceived ?? this.onDataReceived,
      onDataSent: onDataSent ?? this.onDataSent,
      onScanResults: onScanResults ?? this.onScanResults,
      onServiceEvent: onServiceEvent ?? this.onServiceEvent,
      onError: onError ?? this.onError,
      onDataProcessing: onDataProcessing ?? this.onDataProcessing,
    );
  }

  /// Check if any callbacks are registered
  bool get hasCallbacks =>
      onDeviceConnection != null ||
      onDataReceived != null ||
      onDataSent != null ||
      onScanResults != null ||
      onServiceEvent != null ||
      onError != null ||
      onDataProcessing != null;
}
