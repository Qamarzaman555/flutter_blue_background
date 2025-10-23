# Flutter Blue Background Example

This example demonstrates how to use the `flutter_blue_background` package with proper permissions and background service functionality.

## Features Demonstrated

- ✅ **Permission Management**: Comprehensive permission handling for BLE, location, and notifications
- ✅ **Background Service**: BLE communication in background with foreground service
- ✅ **Battery Monitoring**: Real-time battery level and health monitoring
- ✅ **Data Management**: Send/receive data with automatic storage
- ✅ **Cross-Platform**: Works on both Android and iOS

## Required Permissions

### Android Permissions
The app requires the following permissions (already configured in `AndroidManifest.xml`):

- **Bluetooth**: `BLUETOOTH`, `BLUETOOTH_CONNECT`, `BLUETOOTH_SCAN`, `BLUETOOTH_ADVERTISE`
- **Location**: `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION`, `ACCESS_BACKGROUND_LOCATION`
- **Foreground Service**: `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_DATA_SYNC`
- **Notifications**: `POST_NOTIFICATIONS`, `VIBRATE`
- **Battery**: `WAKE_LOCK`, `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`
- **Storage**: `WRITE_EXTERNAL_STORAGE`, `READ_EXTERNAL_STORAGE`

### iOS Permissions
The app requires the following permissions (already configured in `Info.plist`):

- **Bluetooth**: `NSBluetoothAlwaysUsageDescription`, `NSBluetoothPeripheralUsageDescription`
- **Location**: `NSLocationAlwaysAndWhenInUseUsageDescription`, `NSLocationWhenInUseUsageDescription`
- **Background Modes**: `bluetooth-central`, `bluetooth-peripheral`, `background-fetch`

## Setup Instructions

### 1. Configure Your BLE Device
Update the device configuration in `lib/main.dart`:

```dart
const config = BleConfig(
  serviceUuid: '6e400001-b5a3-f393-e0a9-e50e24dcca9e',
  sendCharacteristicUuid: '6e400002-b5a3-f393-e0a9-e50e24dcca9e',
  receiveCharacteristicUuid: '6e400003-b5a3-f393-e0a9-e50e24dcca9e',
  deviceName: 'Your Device Name', // Replace with your device name
  autoReconnect: true,
  enableBatteryMonitoring: true,
);
```

### 2. Run the App
```bash
flutter run
```

### 3. Grant Permissions
1. Tap "Request Permissions" button
2. Grant all required permissions when prompted
3. For Android: Disable battery optimization for the app
4. Tap "Initialize & Start" to begin the background service

## Usage Guide

### 1. Permission Management
- **Check Permissions**: View current permission status
- **Request Permissions**: Request all required permissions

### 2. Service Control
- **Initialize & Start**: Start the background BLE service
- **Stop**: Stop the background service

### 3. Data Communication
- **Send Data**: Send data to connected BLE device
- **Get Data**: Retrieve received data from device
- **Get Battery Data**: View battery monitoring data
- **Clear Data**: Clear all stored data

## Key Features

### Permission Handling
The app includes comprehensive permission management:
- Automatic permission requests
- Permission status checking
- User-friendly error messages
- Settings redirection for denied permissions

### Background Service
- Runs continuously in background
- Foreground service with persistent notification
- Auto-reconnection to BLE devices
- Battery optimization handling

### Data Management
- Automatic data storage and retrieval
- Real-time data processing
- Battery monitoring and health calculation
- Error handling and logging

## Troubleshooting

### Common Issues

1. **Permissions Denied**
   - Go to app settings and manually grant permissions
   - For Android: Disable battery optimization
   - For iOS: Enable background app refresh

2. **BLE Device Not Found**
   - Check device name in configuration
   - Ensure device is in pairing mode
   - Verify service and characteristic UUIDs

3. **Background Service Stops**
   - Check battery optimization settings
   - Ensure all permissions are granted
   - Verify foreground service notification is visible

### Debug Information
- Check console logs for detailed error messages
- Use "Check Permissions" to verify permission status
- Monitor notification for service status

## Platform-Specific Notes

### Android
- Requires Android 6.0+ (API level 23+)
- Battery optimization must be disabled
- Location services must be enabled for BLE scanning

### iOS
- Requires iOS 12.0+
- Background app refresh must be enabled
- Location services must be enabled for BLE scanning

## Dependencies

The example uses the following key dependencies:
- `flutter_blue_background`: Main BLE background service package
- `permission_handler`: Permission management
- `location`: Location services for BLE scanning
- `flutter_local_notifications`: Background service notifications

## Support

For issues or questions:
1. Check the console logs for error messages
2. Verify all permissions are granted
3. Ensure BLE device is properly configured
4. Check platform-specific requirements

## License

This example is part of the flutter_blue_background package and follows the same license terms.