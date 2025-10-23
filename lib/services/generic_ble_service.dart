import 'dart:async';
import 'dart:convert';
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
@pragma('vm:entry-point')
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
    debugPrint('[BG] Initializing BLE background service...');
    debugPrint(
        '[BG] Config: Service=${config.serviceUuid}, Device=${config.deviceName}');

    _config = config;
    _prefs = await SharedPreferences.getInstance();
    debugPrint('[BG] SharedPreferences initialized');

    // Save configuration
    await _prefs!.setString(_configKey, jsonEncode(config.toJson()));
    debugPrint('[BG] Configuration saved to SharedPreferences');

    // Initialize background service
    await _initializeBackgroundService();
    debugPrint('[BG] BLE background service initialization completed');
  }

  /// Start the background service
  static Future<void> start() async {
    debugPrint('[BG] Starting background service...');

    if (_config == null) {
      debugPrint(
          '[BG] ERROR: Service not initialized. Call initialize() first.');
      throw Exception('Service not initialized. Call initialize() first.');
    }

    final service = FlutterBackgroundService();
    debugPrint('[BG] FlutterBackgroundService instance created');

    // Add a small delay to ensure notification channel is ready
    debugPrint('[BG] Waiting for notification channel to be ready...');
    await Future.delayed(const Duration(milliseconds: 500));

    await service.startService();
    debugPrint('[BG] Background service started successfully');
  }

  /// Stop the background service
  static Future<void> stop() async {
    debugPrint('[BG] Stopping background service...');
    final service = FlutterBackgroundService();
    service.invoke('stopService');
    debugPrint('[BG] Background service stop command sent');
  }

  /// Check if service is running
  static Future<bool> isRunning() async {
    debugPrint('[BG] Checking if background service is running...');
    final service = FlutterBackgroundService();
    final running = await service.isRunning();
    debugPrint('[BG] Service running status: $running');
    return running;
  }

  /// Send data to device
  static Future<void> sendData(String data) async {
    debugPrint('[BG] Sending data to device: ${data.length} characters');
    if (_prefs != null) {
      await _prefs!.setString('send_data', data);
      await _prefs!.setBool('send_data_flag', true);
      debugPrint('[BG] Data saved to SharedPreferences for background service');
    } else {
      debugPrint('[BG] WARNING: SharedPreferences not initialized');
    }
  }

  /// Get received data
  static Future<List<BleData>> getReceivedData() async {
    debugPrint('[BG] Retrieving received data...');
    if (_prefs == null) {
      debugPrint(
          '[BG] WARNING: SharedPreferences not initialized, returning empty list');
      return [];
    }

    final dataList = _prefs!.getStringList(_dataKey) ?? [];
    final bleData = dataList
        .map((json) => BleData.fromJson(json as Map<String, dynamic>))
        .toList();
    debugPrint('[BG] Retrieved ${bleData.length} data entries');
    return bleData;
  }

  /// Clear received data
  static Future<void> clearReceivedData() async {
    debugPrint('[BG] Clearing received data...');
    if (_prefs != null) {
      await _prefs!.remove(_dataKey);
      debugPrint('[BG] Received data cleared from SharedPreferences');
    } else {
      debugPrint('[BG] WARNING: SharedPreferences not initialized');
    }
  }

  /// Get battery data
  static Future<List<BatteryData>> getBatteryData() async {
    debugPrint('[BG] Retrieving battery data...');
    if (_prefs == null) {
      debugPrint(
          '[BG] WARNING: SharedPreferences not initialized, returning empty list');
      return [];
    }

    final dataList = _prefs!.getStringList('battery_data') ?? [];
    final batteryData = dataList
        .map((json) => BatteryData.fromJson(json as Map<String, dynamic>))
        .toList();
    debugPrint('[BG] Retrieved ${batteryData.length} battery data entries');
    return batteryData;
  }

  /// Get service status
  static Future<ServiceStatusData> getServiceStatus() async {
    debugPrint('[BG] Getting service status...');
    final service = FlutterBackgroundService();
    final isRunning = await service.isRunning();

    final status = ServiceStatusData(
      isRunning: isRunning,
      isForeground: false, // This would need to be implemented differently
      lastUpdate: DateTime.now(),
    );

    debugPrint(
        '[BG] Service status: Running=$isRunning, LastUpdate=${status.lastUpdate}');
    return status;
  }

  /// Initialize background service
  static Future<void> _initializeBackgroundService() async {
    debugPrint('[BG] Initializing background service configuration...');
    final service = FlutterBackgroundService();
    final config = _config!;
    final notificationConfig = config.notificationConfig;
    debugPrint(
        '[BG] Notification config: Channel=${notificationConfig.channelId}, Title=${notificationConfig.title}');

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
    debugPrint('[BG] Notification channel created');

    debugPrint('[BG] Configuring FlutterBackgroundService...');
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
    debugPrint('[BG] FlutterBackgroundService configuration completed');
  }

  /// iOS background handler
  @pragma('vm:entry-point')
  static Future<bool> _onIosBackground(ServiceInstance service) async {
    debugPrint('[BG] iOS background handler started');
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();
    debugPrint('[BG] iOS Flutter binding and plugin registrant initialized');

    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    debugPrint('[BG] iOS SharedPreferences reloaded');
    final log = prefs.getStringList('log') ?? <String>[];
    log.add(DateTime.now().toIso8601String());
    await prefs.setStringList('log', log);

    return true;
  }

  /// Main service start handler
  @pragma('vm:entry-point')
  static void _onStart(ServiceInstance service) async {
    debugPrint('[BG] Background service started - _onStart called');
    DartPluginRegistrant.ensureInitialized();
    debugPrint('[BG] Dart plugin registrant initialized');

    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    debugPrint('[BG] SharedPreferences reloaded in background service');

    // Load configuration
    debugPrint('[BG] Loading configuration from SharedPreferences...');
    final configJson = prefs.getString(_configKey);
    if (configJson == null) {
      debugPrint('[BG] ERROR: No configuration found in SharedPreferences');
      return;
    }
    debugPrint('[BG] Configuration loaded successfully');

    final configMap = jsonDecode(configJson) as Map<String, dynamic>;
    final config = BleConfig.fromJson(configMap);
    final notificationConfig = config.notificationConfig;

    // Initialize notification plugin
    debugPrint(
        '[BG] Initializing notification plugin in background service...');
    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();

    if (service is AndroidServiceInstance) {
      debugPrint(
          '[BG] Android service instance detected, setting up foreground service');
      service.on('setAsForeground').listen((event) {
        debugPrint('[BG] Setting service as foreground');
        service.setAsForegroundService();
      });

      service.on('setAsBackground').listen((event) {
        debugPrint('[BG] Setting service as background');
        service.setAsBackgroundService();
      });
    }

    // BLE variables
    debugPrint('[BG] Initializing BLE variables...');
    List<BluetoothDevice> scannedDevicesList = <BluetoothDevice>[];
    StreamSubscription? streamSubscription;
    BluetoothDevice? connectedDevice;
    List<BluetoothService> bleServices = <BluetoothService>[];
    StreamSubscription? dataSubscription;
    StreamSubscription? connectionSubscription;
    bool isDeviceConnected = false;
    debugPrint('[BG] BLE variables initialized');

    // Battery monitoring variables
    debugPrint('[BG] Initializing battery monitoring variables...');
    Timer? notificationTimer;
    int batteryLevel = 0;
    String batteryState = 'unknown';
    double mah = 0.0;
    debugPrint('[BG] Battery monitoring variables initialized');

    // Initialize battery monitoring if enabled
    if (config.enableBatteryMonitoring) {
      debugPrint('[BG] Battery monitoring enabled, initializing...');
      await _initializeBatteryMonitoring(config, prefs);
    } else {
      debugPrint('[BG] Battery monitoring disabled');
    }

    // Start scanning for devices
    debugPrint('[BG] Starting BLE device scanning...');
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
    debugPrint(
        '[BG] Starting notification timer with ${notificationConfig.updateIntervalSeconds}s interval');
    notificationTimer = Timer.periodic(
      Duration(seconds: notificationConfig.updateIntervalSeconds),
      (timer) async {
        debugPrint('[BG] Notification timer tick - updating notification');
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
    debugPrint('[BG] Setting up service stop handler...');
    service.on('stopService').listen((event) {
      debugPrint('[BG] Service stop requested - cleaning up...');
      // Cancel notification timer
      notificationTimer?.cancel();
      debugPrint('[BG] Notification timer cancelled');
      // Cleanup will be handled by the service itself
    });
  }

  /// Initialize battery monitoring
  static Future<void> _initializeBatteryMonitoring(
    BleConfig config,
    SharedPreferences prefs,
  ) async {
    debugPrint('[BG] Initializing battery monitoring system...');
    // This would integrate with battery monitoring packages
    // For now, we'll set up the basic structure
    debugPrint('[BG] Battery monitoring system initialized');
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
    debugPrint('[BG] Starting BLE device scanning process...');
    debugPrint(
        '[BG] Target device: ${config.deviceName}, Service: ${config.serviceUuid}');

    // Stop any ongoing scan
    if (FlutterBluePlus.isScanningNow) {
      debugPrint('[BG] Stopping existing scan before starting new one');
      await FlutterBluePlus.stopScan();
    }

    // Clear existing data
    scannedDevicesList.clear();
    bleServices.clear();

    // Cancel existing subscriptions
    await streamSubscription?.cancel();
    await dataSubscription?.cancel();
    await connectionSubscription?.cancel();

    debugPrint('[BG] Setting up scan results listener...');
    streamSubscription = FlutterBluePlus.scanResults.listen(
      (results) async {
        debugPrint('[BG] Received ${results.length} scan results');
        for (ScanResult result in results) {
          if (result.device.remoteId.str.isNotEmpty &&
              !scannedDevicesList.contains(result.device)) {
            debugPrint(
                '[BG] Found device: ${result.device.platformName} (${result.device.remoteId.str})');
            // Check if this is the device we want to connect to
            bool shouldConnect = false;
            if (config.deviceId != null &&
                result.device.remoteId.str == config.deviceId) {
              debugPrint('[BG] Device matches by ID: ${config.deviceId}');
              shouldConnect = true;
            } else if (config.deviceName != null &&
                result.device.platformName == config.deviceName) {
              debugPrint('[BG] Device matches by name: ${config.deviceName}');
              shouldConnect = true;
            }

            if (shouldConnect) {
              debugPrint(
                  '[BG] Attempting to connect to device: ${result.device.platformName}');
              await streamSubscription?.cancel();
              scannedDevicesList.add(result.device);
              connectedDevice = result.device;

              await FlutterBluePlus.stopScan();
              debugPrint('[BG] Scan stopped, attempting device connection...');

              try {
                // Connect to device
                debugPrint(
                    '[BG] Connecting to device: ${connectedDevice!.remoteId.str}');
                await connectedDevice!.connect(autoConnect: false);

                // Discover services
                debugPrint('[BG] Discovering services...');
                bleServices = await connectedDevice!.discoverServices();
                debugPrint('[BG] Found ${bleServices.length} services');

                // Set up MTU for Android
                if (Platform.isAndroid) {
                  debugPrint(
                      '[BG] Setting MTU to ${config.mtuSize} for Android');
                  await connectedDevice!.requestMtu(config.mtuSize);
                }

                // Set up connection state listener
                debugPrint('[BG] Setting up connection state listener...');
                connectionSubscription = connectedDevice?.connectionState
                    .listen((BluetoothConnectionState state) async {
                  debugPrint('[BG] Connection state changed: $state');
                  if (state == BluetoothConnectionState.disconnected) {
                    debugPrint('[BG] Device disconnected');
                    dataSubscription?.cancel();
                    isDeviceConnected = false;

                    // Auto-reconnect if enabled
                    if (config.autoReconnect) {
                      debugPrint(
                          '[BG] Auto-reconnect enabled, restarting scan...');
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
                    debugPrint('[BG] Device connected successfully');
                    isDeviceConnected = true;

                    // Start data communication
                    debugPrint('[BG] Starting data communication...');
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
