import 'dart:typed_data';

/// BLE data model for storing received data
class BleData {
  final String characteristicUuid;
  final List<int> rawData;
  final String? processedData;
  final DateTime timestamp;
  final String? deviceId;
  final String? deviceName;

  const BleData({
    required this.characteristicUuid,
    required this.rawData,
    this.processedData,
    required this.timestamp,
    this.deviceId,
    this.deviceName,
  });

  /// Create from raw data
  factory BleData.fromRawData({
    required String characteristicUuid,
    required List<int> rawData,
    String? deviceId,
    String? deviceName,
    String? processedData,
  }) {
    return BleData(
      characteristicUuid: characteristicUuid,
      rawData: rawData,
      processedData: processedData,
      timestamp: DateTime.now(),
      deviceId: deviceId,
      deviceName: deviceName,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'characteristicUuid': characteristicUuid,
      'rawData': rawData,
      'processedData': processedData,
      'timestamp': timestamp.toIso8601String(),
      'deviceId': deviceId,
      'deviceName': deviceName,
    };
  }

  /// Create from JSON
  factory BleData.fromJson(Map<String, dynamic> json) {
    return BleData(
      characteristicUuid: json['characteristicUuid'] as String,
      rawData: List<int>.from(json['rawData'] as List),
      processedData: json['processedData'] as String?,
      timestamp: DateTime.parse(json['timestamp'] as String),
      deviceId: json['deviceId'] as String?,
      deviceName: json['deviceName'] as String?,
    );
  }

  /// Get data as string
  String get dataAsString {
    if (processedData != null) {
      return processedData!;
    }
    try {
      return String.fromCharCodes(rawData);
    } catch (e) {
      return rawData.toString();
    }
  }

  /// Get data as bytes
  Uint8List get dataAsBytes => Uint8List.fromList(rawData);

  @override
  String toString() {
    return 'BleData(characteristic: $characteristicUuid, data: $dataAsString, timestamp: $timestamp)';
  }
}

/// Battery data model
class BatteryData {
  final int level;
  final String state;
  final double? health;
  final double? mah;
  final DateTime timestamp;
  final String? deviceId;

  const BatteryData({
    required this.level,
    required this.state,
    this.health,
    this.mah,
    required this.timestamp,
    this.deviceId,
  });

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'level': level,
      'state': state,
      'health': health,
      'mah': mah,
      'timestamp': timestamp.toIso8601String(),
      'deviceId': deviceId,
    };
  }

  /// Create from JSON
  factory BatteryData.fromJson(Map<String, dynamic> json) {
    return BatteryData(
      level: json['level'] as int,
      state: json['state'] as String,
      health: json['health'] as double?,
      mah: json['mah'] as double?,
      timestamp: DateTime.parse(json['timestamp'] as String),
      deviceId: json['deviceId'] as String?,
    );
  }

  @override
  String toString() {
    return 'BatteryData(level: $level%, state: $state, health: $health%, mah: $mah, timestamp: $timestamp)';
  }
}

/// Device connection data
class DeviceConnectionData {
  final String deviceId;
  final String? deviceName;
  final bool isConnected;
  final DateTime timestamp;
  final String? error;

  const DeviceConnectionData({
    required this.deviceId,
    this.deviceName,
    required this.isConnected,
    required this.timestamp,
    this.error,
  });

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'deviceId': deviceId,
      'deviceName': deviceName,
      'isConnected': isConnected,
      'timestamp': timestamp.toIso8601String(),
      'error': error,
    };
  }

  /// Create from JSON
  factory DeviceConnectionData.fromJson(Map<String, dynamic> json) {
    return DeviceConnectionData(
      deviceId: json['deviceId'] as String,
      deviceName: json['deviceName'] as String?,
      isConnected: json['isConnected'] as bool,
      timestamp: DateTime.parse(json['timestamp'] as String),
      error: json['error'] as String?,
    );
  }

  @override
  String toString() {
    return 'DeviceConnectionData(id: $deviceId, name: $deviceName, connected: $isConnected, timestamp: $timestamp)';
  }
}

/// Service status data
class ServiceStatusData {
  final bool isRunning;
  final bool isForeground;
  final DateTime lastUpdate;
  final Map<String, dynamic>? metadata;

  const ServiceStatusData({
    required this.isRunning,
    required this.isForeground,
    required this.lastUpdate,
    this.metadata,
  });

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'isRunning': isRunning,
      'isForeground': isForeground,
      'lastUpdate': lastUpdate.toIso8601String(),
      'metadata': metadata,
    };
  }

  /// Create from JSON
  factory ServiceStatusData.fromJson(Map<String, dynamic> json) {
    return ServiceStatusData(
      isRunning: json['isRunning'] as bool,
      isForeground: json['isForeground'] as bool,
      lastUpdate: DateTime.parse(json['lastUpdate'] as String),
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  @override
  String toString() {
    return 'ServiceStatusData(running: $isRunning, foreground: $isForeground, lastUpdate: $lastUpdate)';
  }
}
