import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:location/location.dart' as location;

/// Comprehensive BLE permissions manager for background service
class BlePermissions {
  /// Check if all required permissions are granted
  static Future<bool> areAllPermissionsGranted() async {
    final permissions = await _getRequiredPermissions();
    final statuses = await permissions.request();

    return statuses.values.every((status) => status.isGranted);
  }

  /// Request all required permissions
  static Future<bool> requestAllPermissions() async {
    try {
      // Request location permissions first (required for BLE scanning)
      final locationPermission = await _requestLocationPermission();
      if (!locationPermission) {
        return false;
      }

      // Request Bluetooth permissions using alternative method
      final bluetoothPermission =
          await requestBluetoothPermissionsAlternative();
      if (!bluetoothPermission) {
        print('Bluetooth permissions failed, trying fallback...');
        // Try the original method as fallback
        final fallbackResult = await _requestBluetoothPermissions();
        if (!fallbackResult) {
          return false;
        }
      }

      // Request notification permissions
      final notificationPermission = await _requestNotificationPermission();
      if (!notificationPermission) {
        return false;
      }

      // Request battery optimization exemption (Android only)
      await _requestBatteryOptimizationExemption();

      return true;
    } catch (e) {
      print('Error requesting permissions: $e');
      return false;
    }
  }

  /// Get list of required permissions
  static Future<List<Permission>> _getRequiredPermissions() async {
    return [
      Permission.bluetooth,
      Permission.bluetoothConnect,
      Permission.bluetoothScan,
      Permission.location,
      Permission.locationWhenInUse,
      Permission.notification,
    ];
  }

  /// Request location permissions
  static Future<bool> _requestLocationPermission() async {
    try {
      final locationService = location.Location();

      // Check if location service is enabled
      bool serviceEnabled = await locationService.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await locationService.requestService();
        if (!serviceEnabled) {
          return false;
        }
      }

      // Check location permission
      location.PermissionStatus permissionGranted = await locationService
          .hasPermission();
      if (permissionGranted == location.PermissionStatus.denied) {
        permissionGranted = await locationService.requestPermission();
        if (permissionGranted != location.PermissionStatus.granted) {
          return false;
        }
      }

      return true;
    } catch (e) {
      print('Error requesting location permission: $e');
      return false;
    }
  }

  /// Request Bluetooth permissions
  static Future<bool> _requestBluetoothPermissions() async {
    try {
      // Check Android version to determine which permissions to request
      final permissions = <Permission>[];

      // Always add basic bluetooth permission
      permissions.add(Permission.bluetooth);

      // Add Android 12+ specific permissions
      permissions.add(Permission.bluetoothConnect);
      permissions.add(Permission.bluetoothScan);

      print(
        'Requesting Bluetooth permissions: ${permissions.map((p) => p.toString()).join(', ')}',
      );

      // Try to request permissions individually to handle plugin detection issues
      bool allGranted = true;
      final Map<Permission, PermissionStatus> statuses = {};

      for (final permission in permissions) {
        try {
          print('Checking permission: $permission');
          final status = await permission.status;
          print('Current status of $permission: $status');

          if (!status.isGranted) {
            print('Requesting permission: $permission');
            final newStatus = await permission.request();
            print('New status of $permission: $newStatus');
            statuses[permission] = newStatus;

            if (!newStatus.isGranted) {
              allGranted = false;
              print('Permission $permission was not granted: $newStatus');
            }
          } else {
            statuses[permission] = status;
            print('Permission $permission already granted');
          }
        } catch (e) {
          print('Error handling permission $permission: $e');
          allGranted = false;
        }
      }

      // Log the final status of each permission
      for (final entry in statuses.entries) {
        print('Final permission ${entry.key}: ${entry.value}');
      }

      if (!allGranted) {
        print('Some Bluetooth permissions were not granted');
        // Check which specific permissions failed
        for (final entry in statuses.entries) {
          if (!entry.value.isGranted) {
            print('Failed permission: ${entry.key} - Status: ${entry.value}');
          }
        }
      }

      return allGranted;
    } catch (e) {
      print('Error requesting Bluetooth permissions: $e');
      return false;
    }
  }

  /// Request notification permission
  static Future<bool> _requestNotificationPermission() async {
    try {
      final status = await Permission.notification.request();
      return status.isGranted;
    } catch (e) {
      print('Error requesting notification permission: $e');
      return false;
    }
  }

  /// Request battery optimization exemption (Android only)
  static Future<void> _requestBatteryOptimizationExemption() async {
    try {
      // This will open the battery optimization settings
      // User needs to manually disable battery optimization for the app
      await Permission.ignoreBatteryOptimizations.request();
    } catch (e) {
      print('Error requesting battery optimization exemption: $e');
    }
  }

  /// Check specific permission status
  static Future<PermissionStatus> checkPermission(Permission permission) async {
    return await permission.status;
  }

  /// Open app settings if permissions are denied
  static Future<void> openAppSettings() async {
    await openAppSettings();
  }

  /// Show permission explanation dialog
  static Future<void> showPermissionExplanationDialog(
    BuildContext context, {
    required String title,
    required String message,
    VoidCallback? onContinue,
  }) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Continue'),
              onPressed: () {
                Navigator.of(context).pop();
                onContinue?.call();
              },
            ),
          ],
        );
      },
    );
  }

  /// Get permission status summary
  static Future<Map<String, bool>> getPermissionStatusSummary() async {
    final permissions = await _getRequiredPermissions();
    final statuses = <String, bool>{};

    for (final permission in permissions) {
      final status = await permission.status;
      statuses[permission.toString()] = status.isGranted;
    }

    return statuses;
  }

  /// Diagnostic method to check if permissions are properly declared
  static Future<void> diagnosePermissions() async {
    print('=== Permission Diagnosis ===');

    final permissions = await _getRequiredPermissions();

    for (final permission in permissions) {
      try {
        final status = await permission.status;
        print('${permission.toString()}: $status');

        // Check if permission is permanently denied
        if (status.isPermanentlyDenied) {
          print('  ⚠️  ${permission.toString()} is permanently denied');
        }

        // Check if permission is restricted
        if (status.isRestricted) {
          print('  ⚠️  ${permission.toString()} is restricted');
        }
      } catch (e) {
        print('  ❌ Error checking ${permission.toString()}: $e');
      }
    }

    print('=== End Permission Diagnosis ===');
  }

  /// Alternative permission request method that works around plugin detection issues
  static Future<bool> requestBluetoothPermissionsAlternative() async {
    try {
      print('=== Alternative Bluetooth Permission Request ===');

      // Try the standard approach first
      final standardResult = await _requestBluetoothPermissions();
      if (standardResult) {
        print('Standard permission request succeeded');
        return true;
      }

      print(
        'Standard permission request failed, trying alternative approach...',
      );

      // Alternative approach: request permissions one by one with delays
      final permissions = [
        Permission.bluetooth,
        Permission.bluetoothConnect,
        Permission.bluetoothScan,
      ];

      bool allGranted = true;

      for (int i = 0; i < permissions.length; i++) {
        final permission = permissions[i];
        print(
          'Processing permission ${i + 1}/${permissions.length}: $permission',
        );

        try {
          // Add a small delay between requests
          if (i > 0) {
            await Future.delayed(const Duration(milliseconds: 500));
          }

          final status = await permission.request();
          print('Permission $permission result: $status');

          if (!status.isGranted) {
            allGranted = false;
            print('Permission $permission was not granted: $status');
          }
        } catch (e) {
          print('Error requesting $permission: $e');
          allGranted = false;
        }
      }

      print('Alternative permission request result: $allGranted');
      return allGranted;
    } catch (e) {
      print('Error in alternative permission request: $e');
      return false;
    }
  }

  /// Test if Bluetooth permissions are actually working
  static Future<bool> testBluetoothPermissions() async {
    try {
      print('=== Testing Bluetooth Permissions ===');

      // Check if we can access Bluetooth functionality
      final permissions = [
        Permission.bluetooth,
        Permission.bluetoothConnect,
        Permission.bluetoothScan,
      ];

      bool allWorking = true;

      for (final permission in permissions) {
        try {
          final status = await permission.status;
          print('Permission $permission status: $status');

          if (status.isDenied || status.isPermanentlyDenied) {
            print('❌ Permission $permission is not granted');
            allWorking = false;
          } else if (status.isGranted) {
            print('✅ Permission $permission is granted');
          } else {
            print('⚠️  Permission $permission status unclear: $status');
          }
        } catch (e) {
          print('❌ Error checking permission $permission: $e');
          allWorking = false;
        }
      }

      print('Bluetooth permissions test result: $allWorking');
      return allWorking;
    } catch (e) {
      print('Error testing Bluetooth permissions: $e');
      return false;
    }
  }
}
