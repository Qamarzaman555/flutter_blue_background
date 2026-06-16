import 'package:flutter/material.dart';

import 'package:flutter_blue_background/flutter_blue_background.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _flutterBlueBackgroundPlugin = FlutterBlueBackground();

  bool _isRunning = false;
  String _status = 'Idle';

  @override
  void initState() {
    super.initState();
    _refreshRunningState();
  }

  Future<void> _refreshRunningState() async {
    final running = await _flutterBlueBackgroundPlugin.isServiceRunning();
    if (!mounted) return;
    setState(() => _isRunning = running);
  }

  Future<bool> _ensurePermissions() async {
    // The connectedDevice foreground service type needs a nearby-devices
    // permission granted at runtime, and Android 13+ needs notification
    // permission for the foreground notification to be visible.
    final statuses = await [
      Permission.bluetoothConnect,
      Permission.notification,
    ].request();

    return statuses[Permission.bluetoothConnect]?.isGranted ?? false;
  }

  Future<void> _start() async {
    setState(() => _status = 'Requesting permissions...');
    final granted = await _ensurePermissions();
    if (!granted) {
      setState(() => _status = 'Nearby devices permission denied');
      return;
    }

    final started = await _flutterBlueBackgroundPlugin.startService(
      notificationTitle: 'Flutter Blue Background',
      notificationContent: 'Service is running',
    );
    if (!mounted) return;
    setState(() {
      _status = started ? 'Service started' : 'Failed to start';
    });
    await _refreshRunningState();
  }

  Future<void> _stop() async {
    final stopped = await _flutterBlueBackgroundPlugin.stopService();
    if (!mounted) return;
    setState(() {
      _status = stopped ? 'Service stopped' : 'Failed to stop';
    });
    await _refreshRunningState();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Background service example')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _isRunning ? 'Service: RUNNING' : 'Service: STOPPED',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(_status),
                const SizedBox(height: 32),
                FilledButton(
                  onPressed: _isRunning ? null : _start,
                  child: const Text('Start service'),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: _isRunning ? _stop : null,
                  child: const Text('Stop service'),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _refreshRunningState,
                  child: const Text('Refresh status'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
