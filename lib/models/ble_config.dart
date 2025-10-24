/// Configuration class for BLE background service
class BleConfig {
  /// Service UUID for BLE communication
  final String serviceUuid;

  /// Characteristic UUID for sending data
  final String sendCharacteristicUuid;

  /// Characteristic UUID for receiving data
  final String receiveCharacteristicUuid;

  /// Device name to connect to (optional)
  final String? deviceName;

  /// Device ID to connect to (optional, takes precedence over deviceName)
  final String? deviceId;

  /// Auto-reconnect enabled
  final bool autoReconnect;

  /// Scan timeout in seconds
  final int scanTimeoutSeconds;

  /// Connection timeout in seconds
  final int connectionTimeoutSeconds;

  /// MTU size for Android
  final int mtuSize;

  /// Notification configuration
  final NotificationConfig notificationConfig;

  /// Data processing configuration
  final DataProcessingConfig dataProcessingConfig;

  const BleConfig({
    required this.serviceUuid,
    required this.sendCharacteristicUuid,
    required this.receiveCharacteristicUuid,
    this.deviceName,
    this.deviceId,
    this.autoReconnect = true,
    this.scanTimeoutSeconds = 10,
    this.connectionTimeoutSeconds = 30,
    this.mtuSize = 512,
    this.notificationConfig = const NotificationConfig(),
    this.dataProcessingConfig = const DataProcessingConfig(),
  });

  /// Create a copy with updated values
  BleConfig copyWith({
    String? serviceUuid,
    String? sendCharacteristicUuid,
    String? receiveCharacteristicUuid,
    String? deviceName,
    String? deviceId,
    bool? autoReconnect,
    int? scanTimeoutSeconds,
    int? connectionTimeoutSeconds,
    int? mtuSize,
    NotificationConfig? notificationConfig,
    DataProcessingConfig? dataProcessingConfig,
  }) {
    return BleConfig(
      serviceUuid: serviceUuid ?? this.serviceUuid,
      sendCharacteristicUuid:
          sendCharacteristicUuid ?? this.sendCharacteristicUuid,
      receiveCharacteristicUuid:
          receiveCharacteristicUuid ?? this.receiveCharacteristicUuid,
      deviceName: deviceName ?? this.deviceName,
      deviceId: deviceId ?? this.deviceId,
      autoReconnect: autoReconnect ?? this.autoReconnect,
      scanTimeoutSeconds: scanTimeoutSeconds ?? this.scanTimeoutSeconds,
      connectionTimeoutSeconds:
          connectionTimeoutSeconds ?? this.connectionTimeoutSeconds,
      mtuSize: mtuSize ?? this.mtuSize,
      notificationConfig: notificationConfig ?? this.notificationConfig,
      dataProcessingConfig: dataProcessingConfig ?? this.dataProcessingConfig,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'serviceUuid': serviceUuid,
      'sendCharacteristicUuid': sendCharacteristicUuid,
      'receiveCharacteristicUuid': receiveCharacteristicUuid,
      'deviceName': deviceName,
      'deviceId': deviceId,
      'autoReconnect': autoReconnect,
      'scanTimeoutSeconds': scanTimeoutSeconds,
      'connectionTimeoutSeconds': connectionTimeoutSeconds,
      'mtuSize': mtuSize,
      'notificationConfig': notificationConfig.toJson(),
      'dataProcessingConfig': dataProcessingConfig.toJson(),
    };
  }

  /// Create from JSON
  factory BleConfig.fromJson(Map<String, dynamic> json) {
    return BleConfig(
      serviceUuid: json['serviceUuid'] as String,
      sendCharacteristicUuid: json['sendCharacteristicUuid'] as String,
      receiveCharacteristicUuid: json['receiveCharacteristicUuid'] as String,
      deviceName: json['deviceName'] as String?,
      deviceId: json['deviceId'] as String?,
      autoReconnect: json['autoReconnect'] as bool? ?? true,
      scanTimeoutSeconds: json['scanTimeoutSeconds'] as int? ?? 10,
      connectionTimeoutSeconds: json['connectionTimeoutSeconds'] as int? ?? 30,
      mtuSize: json['mtuSize'] as int? ?? 512,
      notificationConfig: NotificationConfig.fromJson(
          json['notificationConfig'] as Map<String, dynamic>? ?? {}),
      dataProcessingConfig: DataProcessingConfig.fromJson(
          json['dataProcessingConfig'] as Map<String, dynamic>? ?? {}),
    );
  }
}

/// Notification configuration
class NotificationConfig {
  /// Notification channel ID
  final String channelId;

  /// Notification channel name
  final String channelName;

  /// Notification channel description
  final String channelDescription;

  /// Notification importance
  final NotificationImportance importance;

  /// Show badge
  final bool showBadge;

  /// Enable vibration
  final bool enableVibration;

  /// Enable lights
  final bool enableLights;

  /// Play sound
  final bool playSound;

  /// Notification title
  final String title;

  /// Notification content
  final String content;

  /// Notification ID
  final int notificationId;

  /// Update interval in seconds
  final int updateIntervalSeconds;

  /// Show connection status in notification content
  final bool showConnectionStatus;

  const NotificationConfig({
    this.channelId = 'ble_background_service',
    this.channelName = 'BLE Background Service',
    this.channelDescription = 'Background service for BLE communication',
    this.importance = NotificationImportance.low,
    this.showBadge = false,
    this.enableVibration = false,
    this.enableLights = false,
    this.playSound = false,
    this.title = 'BLE Service',
    this.content = 'Background service is active',
    this.notificationId = 888,
    this.updateIntervalSeconds = 2,
    this.showConnectionStatus = true,
  });

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'channelId': channelId,
      'channelName': channelName,
      'channelDescription': channelDescription,
      'importance': importance.name,
      'showBadge': showBadge,
      'enableVibration': enableVibration,
      'enableLights': enableLights,
      'playSound': playSound,
      'title': title,
      'content': content,
      'notificationId': notificationId,
      'updateIntervalSeconds': updateIntervalSeconds,
      'showConnectionStatus': showConnectionStatus,
    };
  }

  /// Create from JSON
  factory NotificationConfig.fromJson(Map<String, dynamic> json) {
    return NotificationConfig(
      channelId: json['channelId'] as String? ?? 'ble_background_service',
      channelName: json['channelName'] as String? ?? 'BLE Background Service',
      channelDescription: json['channelDescription'] as String? ??
          'Background service for BLE communication',
      importance: NotificationImportance.values.firstWhere(
        (e) => e.name == json['importance'],
        orElse: () => NotificationImportance.low,
      ),
      showBadge: json['showBadge'] as bool? ?? false,
      enableVibration: json['enableVibration'] as bool? ?? false,
      enableLights: json['enableLights'] as bool? ?? false,
      playSound: json['playSound'] as bool? ?? false,
      title: json['title'] as String? ?? 'BLE Service',
      content: json['content'] as String? ?? 'Background service is active',
      notificationId: json['notificationId'] as int? ?? 888,
      updateIntervalSeconds: json['updateIntervalSeconds'] as int? ?? 2,
      showConnectionStatus: json['showConnectionStatus'] as bool? ?? true,
    );
  }
}

/// Notification importance levels
enum NotificationImportance {
  none,
  min,
  low,
  defaultImportance,
  high,
  max,
}

/// Data processing configuration
class DataProcessingConfig {
  /// Enable data logging
  final bool enableLogging;

  /// Maximum number of data entries to keep
  final int maxDataEntries;

  /// Data processing interval in seconds
  final int processingIntervalSeconds;

  /// Enable data filtering
  final bool enableDataFiltering;

  /// Data validation enabled
  final bool enableDataValidation;

  const DataProcessingConfig({
    this.enableLogging = true,
    this.maxDataEntries = 1000,
    this.processingIntervalSeconds = 1,
    this.enableDataFiltering = false,
    this.enableDataValidation = true,
  });

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'enableLogging': enableLogging,
      'maxDataEntries': maxDataEntries,
      'processingIntervalSeconds': processingIntervalSeconds,
      'enableDataFiltering': enableDataFiltering,
      'enableDataValidation': enableDataValidation,
    };
  }

  /// Create from JSON
  factory DataProcessingConfig.fromJson(Map<String, dynamic> json) {
    return DataProcessingConfig(
      enableLogging: json['enableLogging'] as bool? ?? true,
      maxDataEntries: json['maxDataEntries'] as int? ?? 1000,
      processingIntervalSeconds: json['processingIntervalSeconds'] as int? ?? 1,
      enableDataFiltering: json['enableDataFiltering'] as bool? ?? false,
      enableDataValidation: json['enableDataValidation'] as bool? ?? true,
    );
  }
}
