import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_background/flutter_blue_background.dart';
import 'package:flutter_blue_background/models/ble_config.dart';
import 'package:flutter_blue_background/models/ble_callbacks.dart';
import 'package:flutter_blue_background/models/ble_data.dart';
import 'permissions/ble_permissions.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Blue Background Example',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const MyHomePage(title: 'Flutter Blue Background Example'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  bool _isServiceRunning = false;
  List<BleData> _receivedData = [];
  ServiceStatusData? _serviceStatus;

  @override
  void initState() {
    super.initState();
    _checkServiceStatus();
    _diagnosePermissions();
  }

  Future<void> _diagnosePermissions() async {
    // Run permission diagnosis in the background
    await BlePermissions.diagnosePermissions();

    // Also test if permissions are actually working
    await BlePermissions.testBluetoothPermissions();
  }

  Future<void> _checkServiceStatus() async {
    final isRunning = await FlutterBlueBackground.isRunning();
    final status = await FlutterBlueBackground.getServiceStatus();
    setState(() {
      _isServiceRunning = isRunning;
      _serviceStatus = status;
    });
  }

  Future<void> _initializeService() async {
    try {
      // Request permissions first
      final permissionsGranted = await BlePermissions.requestAllPermissions();
      if (!permissionsGranted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Permissions not granted. Please grant all required permissions.',
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Create configuration
      final config = BleConfig(
        serviceUuid: '6e400001-b5a3-f393-e0a9-e50e24dcca9e',
        sendCharacteristicUuid: '6e400002-b5a3-f393-e0a9-e50e24dcca9e',
        receiveCharacteristicUuid: '6e400003-b5a3-f393-e0a9-e50e24dcca9e',
        deviceName: 'Leo USB EVNC1O6P6',
        // deviceId: 'YOUR_DEVICE_ID_HERE', // Uncomment and add your device ID if needed
        autoReconnect: true,
        // Temporarily disable notification to test if service works without it
        notificationConfig: NotificationConfig(
          // channelId: 'ble_service',
          channelName: 'BLE Service',
          channelDescription: 'BLE background service',
          title: 'BLE Service',
          content: '${DateTime.now().toIso8601String()}',
          importance: NotificationImportance.low,
          showBadge: false,
          enableVibration: false,
          enableLights: false,
          playSound: false,
          notificationId: 1,
          updateIntervalSeconds: 10,
          showConnectionStatus:
              false, // Use custom content instead of connection status
        ),
        dataProcessingConfig: DataProcessingConfig(
          enableLogging: true,
          maxDataEntries: 1000,
          enableDataValidation: true,
        ),
      );

      // Create callbacks
      final callbacks = BleCallbacks(
        onDeviceConnection: (device, isConnected) {
          print(
            'Device ${device.platformName} ${isConnected ? 'connected' : 'disconnected'}',
          );
        },
        onDataReceived: (data, characteristicUuid) {
          print(
            'Received data: ${String.fromCharCodes(data)} from $characteristicUuid',
          );
        },
        onDataSent: (data, characteristicUuid) {
          print('Sent data: $data to $characteristicUuid');
        },
        onServiceEvent: (event) {
          print('Service event: $event');
        },
        onError: (error, exception) {
          print('Error: $error');
          if (exception != null) {
            print('Exception: $exception');
          }
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

      // Initialize service
      await FlutterBlueBackground.initialize(
        config: config,
        callbacks: callbacks,
      );

      // Start service
      await FlutterBlueBackground.start();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Service initialized and started')),
      );

      await _checkServiceStatus();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _stopService() async {
    try {
      await FlutterBlueBackground.stop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Service stopped')));

      // Wait a moment for the service to actually stop
      await Future.delayed(const Duration(milliseconds: 500));
      await _checkServiceStatus();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _getReceivedData() async {
    try {
      final data = await FlutterBlueBackground.getReceivedData();
      setState(() {
        _receivedData = data;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Received ${data.length} data entries')),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _clearData() async {
    try {
      await FlutterBlueBackground.clearReceivedData();
      setState(() {
        _receivedData.clear();
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Data cleared')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _checkPermissions() async {
    try {
      final statusSummary = await BlePermissions.getPermissionStatusSummary();
      final grantedCount = statusSummary.values
          .where((granted) => granted)
          .length;
      final totalCount = statusSummary.length;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Permissions: $grantedCount/$totalCount granted'),
          backgroundColor: grantedCount == totalCount
              ? Colors.green
              : Colors.orange,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error checking permissions: $e')));
    }
  }

  Future<void> _requestPermissions() async {
    try {
      final permissionsGranted = await BlePermissions.requestAllPermissions();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            permissionsGranted
                ? 'All permissions granted!'
                : 'Some permissions were denied. Please check app settings.',
          ),
          backgroundColor: permissionsGranted ? Colors.green : Colors.red,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error requesting permissions: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Service Status',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text('Running: $_isServiceRunning'),
                    if (_serviceStatus != null) ...[
                      Text('Foreground: ${_serviceStatus!.isForeground}'),
                      Text('Last Update: ${_serviceStatus!.lastUpdate}'),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isServiceRunning ? null : _initializeService,
                    child: const Text('Initialize & Start'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isServiceRunning ? _stopService : null,
                    child: const Text('Stop'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _checkPermissions,
                    child: const Text('Check Permissions'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _requestPermissions,
                    child: const Text('Request Permissions'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _checkServiceStatus,
                    child: const Text('Refresh Status'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _getReceivedData,
                    child: const Text('Get Data'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _clearData,
                    child: const Text('Clear Data'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_receivedData.isNotEmpty) ...[
              Text(
                'Received Data (${_receivedData.length})',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  itemCount: _receivedData.length,
                  itemBuilder: (context, index) {
                    final data = _receivedData[index];
                    return Card(
                      child: ListTile(
                        title: Text(data.dataAsString),
                        subtitle: Text(
                          '${data.characteristicUuid} - ${data.timestamp}',
                        ),
                        trailing: Text('${data.rawData.length} bytes'),
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
