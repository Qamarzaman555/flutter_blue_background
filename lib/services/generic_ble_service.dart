import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/ble_config.dart';
import '../models/ble_callbacks.dart';
import '../models/ble_data.dart';

/// Generic BLE background service
class GenericBleService {
  static const String _configKey = 'ble_config';
  static const String _dataKey = 'ble_data';

  static BleConfig? _config;
  static SharedPreferences? _prefs;

  /// Initialize the service with configuration
  static Future<void> initialize({
    required BleConfig config,
    BleCallbacks? callbacks,
  }) async {
    _config = config;
    _prefs = await SharedPreferences.getInstance();

    // Save configuration
    await _prefs!.setString(_configKey, config.toJson().toString());

    // Initialize background service
    await _initializeBackgroundService();
  }

  /// Start the background service
  static Future<void> start() async {
    if (_config == null) {
      throw Exception('Service not initialized. Call initialize() first.');
    }

    final service = FlutterBackgroundService();

    // Add a small delay to ensure notification channel is ready
    await Future.delayed(const Duration(milliseconds: 500));

    await service.startService();
  }

  /// Stop the background service
  static Future<void> stop() async {
    final service = FlutterBackgroundService();
    service.invoke('stopService');
  }

  /// Check if service is running
  static Future<bool> isRunning() async {
    final service = FlutterBackgroundService();
    return await service.isRunning();
  }

  /// Send data to device
  static Future<void> sendData(String data) async {
    if (_prefs != null) {
      await _prefs!.setString('send_data', data);
      await _prefs!.setBool('send_data_flag', true);
    }
  }

  /// Get received data
  static Future<List<BleData>> getReceivedData() async {
    if (_prefs == null) return [];

    final dataList = _prefs!.getStringList(_dataKey) ?? [];
    return dataList
        .map((json) => BleData.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Clear received data
  static Future<void> clearReceivedData() async {
    if (_prefs != null) {
      await _prefs!.remove(_dataKey);
    }
  }

  /// Get battery data
  static Future<List<BatteryData>> getBatteryData() async {
    if (_prefs == null) return [];

    final dataList = _prefs!.getStringList('battery_data') ?? [];
    return dataList
        .map((json) => BatteryData.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Get service status
  static Future<ServiceStatusData> getServiceStatus() async {
    final service = FlutterBackgroundService();
    final isRunning = await service.isRunning();

    return ServiceStatusData(
      isRunning: isRunning,
      isForeground: false, // This would need to be implemented differently
      lastUpdate: DateTime.now(),
    );
  }

  /// Initialize background service
  static Future<void> _initializeBackgroundService() async {
    final service = FlutterBackgroundService();
    final config = _config!;
    final notificationConfig = config.notificationConfig;

    // Create notification channel
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'ble_background_service',
      'BLE Background Service',
      description: 'Background service for BLE communication',
      importance: Importance.high,
      playSound: false,
      enableVibration: false,
    );

    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();

    if (Platform.isIOS || Platform.isAndroid) {
      await flutterLocalNotificationsPlugin.initialize(
        const InitializationSettings(
          iOS: DarwinInitializationSettings(),
          android: AndroidInitializationSettings('@drawable/ic_notification'),
        ),
      );
    }

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: _onStart,
        autoStart: false,
        isForegroundMode: true,
        notificationChannelId: notificationConfig.channelId,
        initialNotificationTitle: notificationConfig.title,
        initialNotificationContent: notificationConfig.content,
        foregroundServiceNotificationId: notificationConfig.notificationId,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: _onStart,
        onBackground: _onIosBackground,
      ),
    );
  }

  /// iOS background handler
  @pragma('vm:entry-point')
  static Future<bool> _onIosBackground(ServiceInstance service) async {
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();

    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final log = prefs.getStringList('log') ?? <String>[];
    log.add(DateTime.now().toIso8601String());
    await prefs.setStringList('log', log);

    return true;
  }

  /// Main service start handler
  @pragma('vm:entry-point')
  static void _onStart(ServiceInstance service) async {
    DartPluginRegistrant.ensureInitialized();

    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();

    // Load configuration
    final configJson = prefs.getString(_configKey);
    if (configJson == null) {
      print('[BLE Service] No configuration found');
      return;
    }

    final config = BleConfig.fromJson(configJson as Map<String, dynamic>);
    final notificationConfig = config.notificationConfig;

    // Initialize notification plugin
    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();

    if (service is AndroidServiceInstance) {
      service.on('setAsForeground').listen((event) {
        service.setAsForegroundService();
      });

      service.on('setAsBackground').listen((event) {
        service.setAsBackgroundService();
      });
    }

    // BLE variables
    List<BluetoothDevice> scannedDevicesList = <BluetoothDevice>[];
    StreamSubscription? streamSubscription;
    BluetoothDevice? connectedDevice;
    List<BluetoothService> bleServices = <BluetoothService>[];
    StreamSubscription? dataSubscription;
    StreamSubscription? connectionSubscription;
    bool isDeviceConnected = false;

    // Battery monitoring variables
    Timer? notificationTimer;
    int batteryLevel = 0;
    String batteryState = 'unknown';
    double mah = 0.0;

    // Initialize battery monitoring if enabled
    if (config.enableBatteryMonitoring) {
      await _initializeBatteryMonitoring(config, prefs);
    }

    // Start scanning for devices
    await _startScanning(
      config: config,
      scannedDevicesList: scannedDevicesList,
      streamSubscription: streamSubscription,
      connectedDevice: connectedDevice,
      bleServices: bleServices,
      dataSubscription: dataSubscription,
      connectionSubscription: connectionSubscription,
      isDeviceConnected: isDeviceConnected,
      prefs: prefs,
    );

    // Start notification updates
    notificationTimer = Timer.periodic(
      Duration(seconds: notificationConfig.updateIntervalSeconds),
      (timer) async {
        if (service is AndroidServiceInstance) {
          await _updateNotification(
            flutterLocalNotificationsPlugin,
            notificationConfig,
            isDeviceConnected,
            batteryLevel,
            batteryState,
            mah,
          );
        }
      },
    );

    // Cleanup on service stop
    service.on('stopService').listen((event) {
      // Cancel notification timer
      notificationTimer?.cancel();
      // Cleanup will be handled by the service itself
    });
  }

  /// Initialize battery monitoring
  static Future<void> _initializeBatteryMonitoring(
    BleConfig config,
    SharedPreferences prefs,
  ) async {
    // This would integrate with battery monitoring packages
    // For now, we'll set up the basic structure
    print('[BLE Service] Battery monitoring initialized');
  }

  /// Start scanning for devices
  static Future<void> _startScanning({
    required BleConfig config,
    required List<BluetoothDevice> scannedDevicesList,
    required StreamSubscription? streamSubscription,
    required BluetoothDevice? connectedDevice,
    required List<BluetoothService> bleServices,
    required StreamSubscription? dataSubscription,
    required StreamSubscription? connectionSubscription,
    required bool isDeviceConnected,
    required SharedPreferences prefs,
  }) async {
    // Stop any ongoing scan
    if (FlutterBluePlus.isScanningNow) {
      await FlutterBluePlus.stopScan();
    }

    // Clear existing data
    scannedDevicesList.clear();
    bleServices.clear();

    // Cancel existing subscriptions
    await streamSubscription?.cancel();
    await dataSubscription?.cancel();
    await connectionSubscription?.cancel();

    streamSubscription = FlutterBluePlus.scanResults.listen(
      (results) async {
        for (ScanResult result in results) {
          if (result.device.remoteId.str.isNotEmpty &&
              !scannedDevicesList.contains(result.device)) {
            // Check if this is the device we want to connect to
            bool shouldConnect = false;
            if (config.deviceId != null &&
                result.device.remoteId.str == config.deviceId) {
              shouldConnect = true;
            } else if (config.deviceName != null &&
                result.device.platformName == config.deviceName) {
              shouldConnect = true;
            }

            if (shouldConnect) {
              await streamSubscription?.cancel();
              scannedDevicesList.add(result.device);
              connectedDevice = result.device;

              await FlutterBluePlus.stopScan();

              try {
                // Connect to device
                await connectedDevice!.connect(autoConnect: false);

                // Discover services
                bleServices = await connectedDevice!.discoverServices();

                // Set up MTU for Android
                if (Platform.isAndroid) {
                  await connectedDevice!.requestMtu(config.mtuSize);
                }

                // Set up connection state listener
                connectionSubscription = connectedDevice?.connectionState
                    .listen((BluetoothConnectionState state) async {
                  if (state == BluetoothConnectionState.disconnected) {
                    print('[BLE Service] Device disconnected');
                    dataSubscription?.cancel();
                    isDeviceConnected = false;

                    // Auto-reconnect if enabled
                    if (config.autoReconnect) {
                      _startScanning(
                        config: config,
                        scannedDevicesList: scannedDevicesList,
                        streamSubscription: streamSubscription,
                        connectedDevice: connectedDevice,
                        bleServices: bleServices,
                        dataSubscription: dataSubscription,
                        connectionSubscription: connectionSubscription,
                        isDeviceConnected: isDeviceConnected,
                        prefs: prefs,
                      );
                    }
                    connectionSubscription?.cancel();
                  } else if (state == BluetoothConnectionState.connected) {
                    print('[BLE Service] Device connected');
                    isDeviceConnected = true;

                    // Start data communication
                    await _startDataCommunication(
                      connectedDevice!,
                      bleServices,
                      config,
                      dataSubscription,
                      prefs,
                    );
                  }
                });
              } catch (e) {
                print('[BLE Service] Connection error: $e');
                if (config.autoReconnect) {
                  _startScanning(
                    config: config,
                    scannedDevicesList: scannedDevicesList,
                    streamSubscription: streamSubscription,
                    connectedDevice: connectedDevice,
                    bleServices: bleServices,
                    dataSubscription: dataSubscription,
                    connectionSubscription: connectionSubscription,
                    isDeviceConnected: isDeviceConnected,
                    prefs: prefs,
                  );
                }
              }
            }
          }
        }
      },
    );

    // Start scanning with timeout
    await FlutterBluePlus.startScan(
      timeout: Duration(seconds: config.scanTimeoutSeconds),
    );
  }

  /// Start data communication
  static Future<void> _startDataCommunication(
    BluetoothDevice device,
    List<BluetoothService> services,
    BleConfig config,
    StreamSubscription? dataSubscription,
    SharedPreferences prefs,
  ) async {
    for (var service in services) {
      if (service.uuid.toString() == config.serviceUuid) {
        for (var characteristic in service.characteristics) {
          if (characteristic.uuid.toString() ==
              config.receiveCharacteristicUuid) {
            if (characteristic.properties.notify) {
              await characteristic.setNotifyValue(true);
              dataSubscription =
                  characteristic.onValueReceived.listen((value) async {
                await _handleReceivedData(
                    value, config.receiveCharacteristicUuid, prefs);
              });
            } else {
              // Read characteristic value
              final value = await characteristic.read();
              await _handleReceivedData(
                  value, config.receiveCharacteristicUuid, prefs);
            }
          }
        }
      }
    }
  }

  /// Handle received data
  static Future<void> _handleReceivedData(
    List<int> data,
    String characteristicUuid,
    SharedPreferences prefs,
  ) async {
    final bleData = BleData.fromRawData(
      characteristicUuid: characteristicUuid,
      rawData: data,
    );

    // Store data
    final dataList = prefs.getStringList('ble_data') ?? [];
    dataList.add(bleData.toJson().toString());

    // Keep only recent data (limit to 1000 entries)
    if (dataList.length > 1000) {
      dataList.removeRange(0, dataList.length - 1000);
    }

    await prefs.setStringList('ble_data', dataList);

    print('[BLE Service] Received data: ${bleData.dataAsString}');
  }

  /// Update notification
  static Future<void> _updateNotification(
    FlutterLocalNotificationsPlugin plugin,
    NotificationConfig config,
    bool isConnected,
    int batteryLevel,
    String batteryState,
    double mah,
  ) async {
    final content = 'Device: ${isConnected ? "Connected" : "Disconnected"} | '
        'Battery: $batteryLevel% ($batteryState) | '
        'mAh: ${mah.toStringAsFixed(2)}';

    await plugin.show(
      config.notificationId,
      config.title,
      content,
      NotificationDetails(
        android: AndroidNotificationDetails(
          config.channelId,
          config.channelName,
          channelDescription: config.channelDescription,
          importance: _getImportance(config.importance),
          priority: Priority.high,
          showWhen: false,
          enableVibration: config.enableVibration,
          enableLights: config.enableLights,
          playSound: config.playSound,
          sound: null,
          channelShowBadge: config.showBadge,
        ),
      ),
    );
  }

  /// Convert notification importance
  static Importance _getImportance(NotificationImportance importance) {
    switch (importance) {
      case NotificationImportance.none:
        return Importance.none;
      case NotificationImportance.min:
        return Importance.min;
      case NotificationImportance.low:
        return Importance.low;
      case NotificationImportance.defaultImportance:
        return Importance.defaultImportance;
      case NotificationImportance.high:
        return Importance.high;
      case NotificationImportance.max:
        return Importance.max;
    }
  }
}
