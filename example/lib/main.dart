import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:flutter_blue_background/flutter_blue_background.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(const MyApp());
}

/// Holds all BLE service + scan state reactively so the UI can rebuild with
/// [Obx] instead of [State.setState].
class BleController extends GetxController {
  final _plugin = FlutterBlueBackground();

  final isRunning = false.obs;
  final isScanning = false.obs;
  final adapterState = BleAdapterState.unknown.obs;
  final status = 'Idle'.obs;

  /// Keyed by deviceId so repeated advertisements update in place.
  final RxMap<String, BleScanResult> devices = <String, BleScanResult>{}.obs;

  StreamSubscription<BleScanResult>? _scanSub;
  StreamSubscription<BleAdapterState>? _adapterSub;

  /// Devices sorted by signal strength (strongest first).
  List<BleScanResult> get sortedDevices {
    final list = devices.values.toList();
    list.sort((a, b) => (b.rssi ?? -999).compareTo(a.rssi ?? -999));
    return list;
  }

  /// Matches [ScanConfig.skipUnnamedDevices] in [startScan].
  static const _skipUnnamedDevices = true;

  @override
  void onInit() {
    super.onInit();
    _restoreState();
    _scanSub = _plugin.scanResults.listen(_addResult);
    _adapterSub = _plugin.adapterState.listen((state) {
      adapterState.value = state;
      if (!state.canScan && isScanning.value) {
        isScanning.value = false;
        status.value = 'Bluetooth off — scan stopped';
      }
    });
  }

  void _addResult(BleScanResult result) {
    if (_skipUnnamedDevices && !result.hasAdvertisedName) return;
    devices[result.deviceId] = result;
  }

  @override
  void onClose() {
    _scanSub?.cancel();
    _adapterSub?.cancel();
    super.onClose();
  }

  /// Re-syncs the UI with whatever the native side is actually doing. After the
  /// app is swiped from recents the foreground service keeps scanning, so on
  /// reopen we restore the running/scanning flags and any devices found while
  /// the UI was gone.
  Future<void> _restoreState() async {
    isRunning.value = await _plugin.isServiceRunning();
    isScanning.value = await _plugin.isScanning();
    adapterState.value = await _plugin.getAdapterState();

    final cached = await _plugin.getScanResults();
    for (final result in cached) {
      _addResult(result);
    }

    if (isScanning.value) {
      status.value = 'Scanning...';
    } else if (isRunning.value) {
      status.value = 'Service started';
    }
  }

  Future<void> _refreshRunningState() async {
    isRunning.value = await _plugin.isServiceRunning();
  }

  Future<bool> _ensurePermissions() async {
    final statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.notification,
    ].request();

    // bluetoothScan covers Android 12+; older versions fall back to location.
    final scanOk = statuses[Permission.bluetoothScan]?.isGranted ?? false;
    final connectOk = statuses[Permission.bluetoothConnect]?.isGranted ?? false;
    return scanOk || connectOk;
  }

  Future<void> startService() async {
    status.value = 'Requesting permissions...';
    if (!await _ensurePermissions()) {
      status.value = 'Bluetooth permission denied';
      return;
    }

    final started = await _plugin.startService(
      notificationTitle: 'Flutter Blue Background',
      notificationContent: 'Service is running',
    );
    status.value = started ? 'Service started' : 'Failed to start';
    await _refreshRunningState();
  }

  Future<void> stopService() async {
    final stopped = await _plugin.stopService();
    isScanning.value = await _plugin.isScanning();
    status.value = stopped ? 'Service stopped' : 'Failed to stop';
    await _refreshRunningState();
  }

  Future<void> startScan() async {
    if (!isRunning.value) {
      status.value = 'Start the service first';
      return;
    }

    if (!await _ensurePermissions()) {
      status.value = 'Bluetooth permission denied';
      return;
    }

    if (!adapterState.value.canScan) {
      status.value = 'Bluetooth is ${adapterState.value.name}';
      return;
    }

    devices.clear();

    // Example config: no service filter (finds everything in the foreground),
    // low-latency scanning on Android, and a -90 dBm floor to drop very weak
    // signals. Add serviceUuids for reliable background discovery on iOS.
    const config = ScanConfig(
      serviceUuids: [],
      skipUnnamedDevices: _skipUnnamedDevices,
      rssiThreshold: -180,
      android: AndroidScanSettings(scanMode: AndroidScanMode.lowLatency),
      ios: IosScanOptions(allowDuplicates: true),
    );

    final started = await _plugin.startScan(config);
    isScanning.value = started;
    status.value =
        started ? 'Scanning...' : 'Failed to start scan (is Bluetooth on?)';
  }

  Future<void> stopScan() async {
    await _plugin.stopScan();
    isScanning.value = false;
    status.value = 'Scan stopped';
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Background service example',
      home: const HomePage(),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(BleController());

    return Scaffold(
      appBar: AppBar(title: const Text('Background service example')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Obx(
              () => Text(
                controller.isRunning.value
                    ? 'Service: RUNNING'
                    : 'Service: STOPPED',
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 4),
            Obx(
              () => Text(
                'Bluetooth: ${controller.adapterState.value.name.toUpperCase()}',
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 4),
            Obx(
              () => Text(controller.status.value, textAlign: TextAlign.center),
            ),
            const SizedBox(height: 16),
            Obx(
              () => Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: controller.isRunning.value
                          ? null
                          : controller.startService,
                      child: const Text('Start service'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: controller.isRunning.value
                          ? controller.stopService
                          : null,
                      child: const Text('Stop service'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Obx(
              () => Row(
                children: [
                  Expanded(
                    child: FilledButton.tonal(
                      onPressed: !controller.isRunning.value ||
                              controller.isScanning.value ||
                              !controller.adapterState.value.canScan
                          ? null
                          : controller.startScan,
                      child: const Text('Start scan'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: controller.isScanning.value
                          ? controller.stopScan
                          : null,
                      child: const Text('Stop scan'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Obx(
              () => Text(
                'Discovered devices (${controller.devices.length})',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            const Divider(),
            Expanded(
              child: Obx(() {
                final devices = controller.sortedDevices;
                if (devices.isEmpty) {
                  return const Center(child: Text('No devices yet'));
                }
                return ListView.builder(
                  itemCount: devices.length,
                  itemBuilder: (context, index) {
                    final d = devices[index];
                    return ListTile(
                      dense: true,
                      title: Text(d.displayName),
                      subtitle: Text(d.deviceId),
                      trailing: Text('${d.rssi ?? '--'} dBm'),
                    );
                  },
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}
