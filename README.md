# Flutter Blue Background

A professional, generic Flutter package for enabling BLE (Bluetooth Low Energy) functionality in background services for both Android and iOS platforms.

## Features

- 🔄 **Generic Configuration**: Highly configurable BLE service with support for custom UUIDs, device names, and connection parameters
- 🔋 **Battery Monitoring**: Built-in battery level and health monitoring with customizable thresholds
- 📱 **Cross-Platform**: Works on both Android and iOS with platform-specific optimizations
- 🔔 **Smart Notifications**: Configurable notification system with customizable importance levels
- 📊 **Data Management**: Built-in data storage and retrieval with automatic cleanup
- 🔌 **Auto-Reconnection**: Automatic device reconnection with configurable timeouts
- 🎯 **Callback System**: Comprehensive callback system for handling device events, data, and errors
- 🔧 **Legacy Support**: Backward compatibility with existing implementations

## Installation

Add this to your package's `pubspec.yaml` file:

```yaml
dependencies:
  flutter_blue_background: ^0.0.2
```

## Quick Start

### 1. Basic Usage

```dart
import 'package:flutter_blue_background/flutter_blue_background.dart';

// Create configuration
final config = BleConfig(
  serviceUuid: '6e400001-b5a3-f393-e0a9-e50e24dcca9e',
  sendCharacteristicUuid: '6e400002-b5a3-f393-e0a9-e50e24dcca9e',
  receiveCharacteristicUuid: '6e400003-b5a3-f393-e0a9-e50e24dcca9e',
  deviceName: 'Your Device Name',
  autoReconnect: true,
  enableBatteryMonitoring: true,
);

// Initialize and start service
await FlutterBlueBackground.initialize(config: config);
await FlutterBlueBackground.start();
```

### 2. Advanced Configuration

```dart
final config = BleConfig(
  serviceUuid: '6e400001-b5a3-f393-e0a9-e50e24dcca9e',
  sendCharacteristicUuid: '6e400002-b5a3-f393-e0a9-e50e24dcca9e',
  receiveCharacteristicUuid: '6e400003-b5a3-f393-e0a9-e50e24dcca9e',
  deviceName: 'My BLE Device',
  deviceId: 'AA:BB:CC:DD:EE:FF', // Optional, takes precedence over deviceName
  autoReconnect: true,
  scanTimeoutSeconds: 15,
  connectionTimeoutSeconds: 30,
  mtuSize: 512,
  enableBatteryMonitoring: true,
  enableBatteryHealthCalculation: true,
  batteryHealthThreshold: 30,
  batteryCapacity: 3000.0, // mAh
  chargeLimit: 98,
  enableCustomChargeLimit: true,
  notificationConfig: const NotificationConfig(
    channelId: 'my_ble_service',
    channelName: 'My BLE Service',
    channelDescription: 'Background BLE communication service',
    title: 'BLE Service',
    content: 'Service is running',
    importance: NotificationImportance.low,
    showBadge: false,
    enableVibration: false,
    enableLights: false,
    playSound: false,
  ),
  dataProcessingConfig: const DataProcessingConfig(
    enableLogging: true,
    maxDataEntries: 1000,
    processingIntervalSeconds: 1,
    enableDataFiltering: false,
    enableDataValidation: true,
  ),
);
```

### 3. Using Callbacks

```dart
final callbacks = BleCallbacks(
  onDeviceConnection: (device, isConnected) {
    print('Device ${device.platformName} ${isConnected ? 'connected' : 'disconnected'}');
  },
  onDataReceived: (data, characteristicUuid) {
    print('Received: ${String.fromCharCodes(data)} from $characteristicUuid');
  },
  onDataSent: (data, characteristicUuid) {
    print('Sent: $data to $characteristicUuid');
  },
  onBatteryEvent: (event) {
    print('Battery event: $event');
  },
  onServiceEvent: (event) {
    print('Service event: $event');
  },
  onError: (error, exception) {
    print('Error: $error');
  },
  onDataProcessing: (rawData) {
    // Custom data processing
    try {
      return String.fromCharCodes(rawData);
    } catch (e) {
      return null;
    }
  },
);

await FlutterBlueBackground.initialize(
  config: config,
  callbacks: callbacks,
);
```

## API Reference

### Core Methods

#### `initialize({required BleConfig config, BleCallbacks? callbacks})`
Initialize the BLE background service with configuration and optional callbacks.

#### `start()`
Start the background service.

#### `stop()`
Stop the background service.

#### `isRunning()`
Check if the service is currently running.

#### `sendData(String data)`
Send data to the connected device.

#### `getReceivedData()`
Get all received data as a list of `BleData` objects.

#### `getBatteryData()`
Get battery monitoring data as a list of `BatteryData` objects.

#### `clearReceivedData()`
Clear all stored received data.

#### `getServiceStatus()`
Get current service status information.

### Configuration Classes

#### `BleConfig`
Main configuration class for the BLE service.

**Properties:**
- `serviceUuid`: BLE service UUID
- `sendCharacteristicUuid`: Characteristic UUID for sending data
- `receiveCharacteristicUuid`: Characteristic UUID for receiving data
- `deviceName`: Device name to connect to (optional)
- `deviceId`: Device ID to connect to (optional, takes precedence)
- `autoReconnect`: Enable automatic reconnection
- `scanTimeoutSeconds`: Scan timeout in seconds
- `connectionTimeoutSeconds`: Connection timeout in seconds
- `mtuSize`: MTU size for Android
- `enableBatteryMonitoring`: Enable battery monitoring
- `enableBatteryHealthCalculation`: Enable battery health calculation
- `batteryHealthThreshold`: Battery health calculation threshold
- `batteryCapacity`: Battery capacity in mAh
- `chargeLimit`: Charge limit percentage
- `enableCustomChargeLimit`: Enable custom charge limit
- `notificationConfig`: Notification configuration
- `dataProcessingConfig`: Data processing configuration

#### `NotificationConfig`
Configuration for notifications.

**Properties:**
- `channelId`: Notification channel ID
- `channelName`: Notification channel name
- `channelDescription`: Notification channel description
- `importance`: Notification importance level
- `showBadge`: Show notification badge
- `enableVibration`: Enable vibration
- `enableLights`: Enable LED lights
- `playSound`: Play notification sound
- `title`: Notification title
- `content`: Notification content
- `notificationId`: Notification ID
- `updateIntervalSeconds`: Update interval in seconds

#### `DataProcessingConfig`
Configuration for data processing.

**Properties:**
- `enableLogging`: Enable data logging
- `maxDataEntries`: Maximum number of data entries to keep
- `processingIntervalSeconds`: Data processing interval
- `enableDataFiltering`: Enable data filtering
- `enableDataValidation`: Enable data validation

### Data Models

#### `BleData`
Represents received BLE data.

**Properties:**
- `characteristicUuid`: Characteristic UUID
- `rawData`: Raw data bytes
- `processedData`: Processed data string
- `timestamp`: Data timestamp
- `deviceId`: Device ID
- `deviceName`: Device name

#### `BatteryData`
Represents battery monitoring data.

**Properties:**
- `level`: Battery level percentage
- `state`: Battery state (charging/discharging)
- `health`: Battery health percentage
- `mah`: Current in mAh
- `timestamp`: Data timestamp
- `deviceId`: Device ID

#### `ServiceStatusData`
Represents service status information.

**Properties:**
- `isRunning`: Service running status
- `isForeground`: Foreground service status
- `lastUpdate`: Last update timestamp
- `metadata`: Additional metadata

### Callback Types

#### `DeviceConnectionCallback`
Called when device connects or disconnects.

#### `DataReceivedCallback`
Called when data is received from a characteristic.

#### `DataSentCallback`
Called when data is successfully sent.

#### `ScanResultCallback`
Called when scan results are available.

#### `BatteryEventCallback`
Called when battery events occur.

#### `ServiceEventCallback`
Called when service events occur.

#### `ErrorCallback`
Called when errors occur.

#### `DataProcessingCallback`
Called to process raw data before storing.

## Platform-Specific Setup

### Android

1. Add permissions to `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.BLUETOOTH" />
<uses-permission android:name="android.permission.BLUETOOTH_ADMIN" />
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
<uses-permission android:name="android.permission.BLUETOOTH_SCAN" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.WAKE_LOCK" />
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />
<uses-permission android:name="android.permission.BATTERY_STATS" />
```

2. Add service declaration to `android/app/src/main/AndroidManifest.xml`:

```xml
<service
    android:name="id.flutter.flutter_background_service.BackgroundService"
    android:foregroundServiceType="dataSync"
    android:exported="false" />
```

### iOS

1. Add capabilities in Xcode:
   - Background Modes
   - Bluetooth LE

2. Add to `ios/Runner/Info.plist`:

```xml
<key>UIBackgroundModes</key>
<array>
    <string>bluetooth-central</string>
    <string>background-fetch</string>
</array>
```

## Legacy Support

The package maintains backward compatibility with existing implementations:

```dart
// Legacy methods still work
await FlutterBlueBackground.connectToDevice(
  deviceName: 'My Device',
  serviceUuid: '6e400001-b5a3-f393-e0a9-e50e24dcca9e',
  characteristicUuid: '6e400002-b5a3-f393-e0a9-e50e24dcca9e',
);

await FlutterBlueBackground.writeData(
  serviceUuid: '6e400001-b5a3-f393-e0a9-e50e24dcca9e',
  characteristicUuid: '6e400002-b5a3-f393-e0a9-e50e24dcca9e',
  data: 'Hello World',
);

final data = await FlutterBlueBackground.readData(
  serviceUuid: '6e400001-b5a3-f393-e0a9-e50e24dcca9e',
  characteristicUuid: '6e400003-b5a3-f393-e0a9-e50e24dcca9e',
);
```

## Example

See the `example/` directory for a complete example application demonstrating all features.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Support

For support, please open an issue on the GitHub repository.