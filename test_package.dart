import 'package:flutter/material.dart';
import 'package:flutter_blue_background/flutter_blue_background.dart';
import 'package:flutter_blue_background/models/ble_config.dart';
import 'package:flutter_blue_background/models/ble_callbacks.dart';

void main() {
  runApp(const TestApp());
}

class TestApp extends StatelessWidget {
  const TestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Blue Background Test',
      home: const TestHomePage(),
    );
  }
}

class TestHomePage extends StatefulWidget {
  const TestHomePage({super.key});

  @override
  State<TestHomePage> createState() => _TestHomePageState();
}

class _TestHomePageState extends State<TestHomePage> {
  bool _isServiceRunning = false;
  String _status = 'Not initialized';

  @override
  void initState() {
    super.initState();
    _checkServiceStatus();
  }

  Future<void> _checkServiceStatus() async {
    try {
      final isRunning = await FlutterBlueBackground.isRunning();
      setState(() {
        _isServiceRunning = isRunning;
        _status = isRunning ? 'Running' : 'Stopped';
      });
    } catch (e) {
      setState(() {
        _status = 'Error: $e';
      });
    }
  }

  Future<void> _testInitialize() async {
    try {
      setState(() {
        _status = 'Initializing...';
      });

      // Create a simple configuration
      const config = BleConfig(
        serviceUuid: '6e400001-b5a3-f393-e0a9-e50e24dcca9e',
        sendCharacteristicUuid: '6e400002-b5a3-f393-e0a9-e50e24dcca9e',
        receiveCharacteristicUuid: '6e400003-b5a3-f393-e0a9-e50e24dcca9e',
        deviceName: 'Test Device',
        autoReconnect: true,
        enableBatteryMonitoring: false, // Disable for testing
      );

      // Create simple callbacks
      final callbacks = BleCallbacks(
        onDeviceConnection: (device, isConnected) {
          print(
              'Device ${device.platformName} ${isConnected ? 'connected' : 'disconnected'}');
        },
        onDataReceived: (data, characteristicUuid) {
          print(
              'Received data: ${String.fromCharCodes(data)} from $characteristicUuid');
        },
        onError: (error, exception) {
          print('Error: $error');
        },
      );

      // Initialize service
      await FlutterBlueBackground.initialize(
        config: config,
        callbacks: callbacks,
      );

      // Start service
      await FlutterBlueBackground.start();

      setState(() {
        _status = 'Service started successfully';
      });

      await _checkServiceStatus();
    } catch (e) {
      setState(() {
        _status = 'Error initializing: $e';
      });
    }
  }

  Future<void> _testStop() async {
    try {
      await FlutterBlueBackground.stop();
      setState(() {
        _status = 'Service stopped';
      });
      await _checkServiceStatus();
    } catch (e) {
      setState(() {
        _status = 'Error stopping: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Flutter Blue Background Test'),
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
                    Text('Status: $_status'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _testInitialize,
              child: const Text('Initialize & Start Service'),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _testStop,
              child: const Text('Stop Service'),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _checkServiceStatus,
              child: const Text('Check Status'),
            ),
            const SizedBox(height: 16),
            const Text(
              'This is a simple test to verify the package works correctly.',
              style: TextStyle(fontStyle: FontStyle.italic),
            ),
          ],
        ),
      ),
    );
  }
}
