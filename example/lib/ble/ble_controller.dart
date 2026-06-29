import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter_blue_background/flutter_blue_background.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';

import 'ble_log_entry.dart';
import 'ble_notification_builder.dart';

/// Shared BLE state for the example app: service, scan, and GATT connections.
class BleController extends GetxController {
  BleController({FlutterBlueBackground? plugin})
      : _plugin = plugin ?? FlutterBlueBackground();

  final FlutterBlueBackground _plugin;

  static const _maxLogEntries = 40;

  final isRunning = false.obs;
  final isScanning = false.obs;
  final adapterState = BleAdapterState.unknown.obs;
  final polledAdapterState = Rxn<BleAdapterState>();
  final status = 'Idle'.obs;
  final platformVersion = RxnString();
  final gattStatusMessage = ''.obs;

  final RxMap<String, BleScanResult> devices = <String, BleScanResult>{}.obs;
  final RxMap<String, BleConnectionState> connectionStates =
      <String, BleConnectionState>{}.obs;
  final RxMap<String, int> deviceMtu = <String, int>{}.obs;
  final RxMap<String, List<BleGattService>> discoveredServices =
      <String, List<BleGattService>>{}.obs;
  final RxMap<String, bool> isDiscoveringServices = <String, bool>{}.obs;

  final RxList<String> queriedConnectedDeviceIds = <String>[].obs;
  final RxMap<String, BleConnectionState> queriedConnectionStates =
      <String, BleConnectionState>{}.obs;

  final queryStatusMessage = ''.obs;
  final isQueryingConnections = false.obs;

  final RxList<AdapterStateLogEntry> adapterStateLog =
      <AdapterStateLogEntry>[].obs;
  final RxList<ConnectionLogEntry> connectionEventLog =
      <ConnectionLogEntry>[].obs;

  StreamSubscription<BleScanResult>? _scanSub;
  StreamSubscription<BleAdapterState>? _adapterSub;
  StreamSubscription<BleConnectionEvent>? _connectionSub;

  static const skipUnnamedDevices = true;

  String? _lastNotificationContent;
  bool _notificationUpdateInFlight = false;

  List<BleScanResult> get sortedDevices {
    final list = devices.values.toList();
    list.sort((a, b) => (b.rssi ?? -999).compareTo(a.rssi ?? -999));
    return list;
  }

  BleScanResult? deviceFor(String deviceId) => devices[deviceId];

  String displayNameFor(String deviceId) =>
      devices[deviceId]?.displayName ?? deviceId;

  @override
  void onInit() {
    super.onInit();
    _restoreState();
    _scanSub = _plugin.scanResults.listen(_addScanResult);
    _adapterSub = _plugin.adapterState.listen(_onAdapterStreamEvent);
    _connectionSub = _plugin.connectionState.listen(_onConnectionEvent);
    _logAdapterState(adapterState.value, source: 'initial');
    unawaited(fetchPlatformVersion());
  }

  @override
  void onClose() {
    _scanSub?.cancel();
    _adapterSub?.cancel();
    _connectionSub?.cancel();
    super.onClose();
  }

  void _logAdapterState(BleAdapterState state, {required String source}) {
    adapterStateLog.insert(
      0,
      AdapterStateLogEntry(
        timestamp: DateTime.now(),
        state: state,
        source: source,
      ),
    );
    if (adapterStateLog.length > _maxLogEntries) {
      adapterStateLog.removeRange(_maxLogEntries, adapterStateLog.length);
    }
    adapterStateLog.refresh();
  }

  void _logConnectionEvent(BleConnectionEvent event) {
    connectionEventLog.insert(
      0,
      ConnectionLogEntry(timestamp: DateTime.now(), event: event),
    );
    if (connectionEventLog.length > _maxLogEntries) {
      connectionEventLog.removeRange(_maxLogEntries, connectionEventLog.length);
    }
    connectionEventLog.refresh();
  }

  Future<void> _onAdapterStreamEvent(BleAdapterState state) async {
    if (state == adapterState.value) return;

    adapterState.value = state;
    _logAdapterState(state, source: 'stream');

    if (state.requiresBleTeardown) {
      await _handleAdapterUnavailable(state);
      return;
    }

    if (state == BleAdapterState.turningOn) {
      status.value = BleNotificationBuilder.adapterStatusMessage(
        state,
        currentStatus: status.value,
      );
      await _updateNotification();
      return;
    }

    if (state.isOn) {
      await _syncBleStateFromNative();
    }
  }

  void _onConnectionEvent(BleConnectionEvent event) {
    _logConnectionEvent(event);
    _setConnectionState(event.deviceId, event.state);

    if (event.mtu != null) {
      deviceMtu[event.deviceId] = event.mtu!;
    }

    if (event.state == BleConnectionState.connected) {
      status.value =
          'Connected to ${event.deviceId} (mtu ${event.mtu ?? '?'})';
      unawaited(discoverServicesFor(event.deviceId));
    } else if (event.state == BleConnectionState.disconnected) {
      discoveredServices.remove(event.deviceId);
      isDiscoveringServices.remove(event.deviceId);
      if (event.errorMessage != null) {
        status.value = 'Disconnected: ${event.errorMessage}';
      }
    }

    _updateNotification();
  }

  void _setConnectionState(String deviceId, BleConnectionState state) {
    connectionStates[deviceId] = state;
    connectionStates.refresh();
  }

  void _clearAllConnectionStates() {
    connectionStates.clear();
    connectionStates.refresh();
    deviceMtu.clear();
    discoveredServices.clear();
    isDiscoveringServices.clear();
  }

  Future<void> _handleAdapterUnavailable(BleAdapterState state) async {
    isScanning.value = false;
    _clearAllConnectionStates();
    queriedConnectedDeviceIds.clear();
    queriedConnectionStates.clear();
    status.value = BleNotificationBuilder.adapterStatusMessage(
      state,
      currentStatus: status.value,
    );
    await _updateNotification();
  }

  Future<void> _syncBleStateFromNative() async {
    isScanning.value = await _plugin.isScanning();
    _clearAllConnectionStates();

    final connected = await _plugin.getConnectedDevices();
    for (final id in connected) {
      _setConnectionState(id, BleConnectionState.connected);
    }

    if (isScanning.value) {
      status.value = 'Scanning…';
    } else if (connected.isNotEmpty) {
      status.value = 'Connected to ${connected.length} device(s)';
    } else if (isRunning.value) {
      status.value = 'Bluetooth on — ready';
    }

    await _updateNotification();
  }

  String _buildNotificationContent() {
    if (!adapterState.value.isOn) {
      return BleNotificationBuilder.forAdapterState(
        adapterState.value,
        buildWhenOn: () => '',
      );
    }

    return BleNotificationBuilder.whenAdapterOn(
      isScanning: isScanning.value,
      connectionStates: Map<String, BleConnectionState>.from(connectionStates),
      devices: Map<String, BleScanResult>.from(devices),
    );
  }

  Future<void> _updateNotification() async {
    if (!isRunning.value || _notificationUpdateInFlight) return;

    final content = _buildNotificationContent();
    if (content == _lastNotificationContent) return;

    _notificationUpdateInFlight = true;
    try {
      await _plugin.startService(
        notificationTitle: 'Flutter Blue Background',
        notificationContent: content,
      );
      _lastNotificationContent = content;
    } finally {
      _notificationUpdateInFlight = false;
    }
  }

  void _addScanResult(BleScanResult result) {
    if (skipUnnamedDevices && !result.hasAdvertisedName) return;
    devices[result.deviceId] = result;
  }

  Future<void> _restoreState() async {
    isRunning.value = await _plugin.isServiceRunning();
    isScanning.value = await _plugin.isScanning();
    adapterState.value = await _plugin.getAdapterState();
    _logAdapterState(adapterState.value, source: 'poll');

    final cached = await _plugin.getScanResults();
    for (final result in cached) {
      _addScanResult(result);
    }

    if (adapterState.value.isOn) {
      await _syncBleStateFromNative();
    } else {
      isScanning.value = false;
      _clearAllConnectionStates();
      status.value = BleNotificationBuilder.adapterStatusMessage(
        adapterState.value,
        currentStatus: status.value,
      );
    }

    if (isRunning.value && adapterState.value.isOn && !isScanning.value) {
      status.value = 'Service running — Bluetooth on';
    } else if (!isRunning.value) {
      status.value = 'Idle';
    }

    await _updateNotification();
  }

  Future<void> _refreshRunningState() async {
    isRunning.value = await _plugin.isServiceRunning();
  }

  Future<bool> ensurePermissions() async {
    final statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.notification,
    ].request();

    if (!Platform.isAndroid) {
      return true;
    }

    final scanOk = statuses[Permission.bluetoothScan]?.isGranted ?? false;
    final connectOk =
        statuses[Permission.bluetoothConnect]?.isGranted ?? false;

    // Android 12+ needs both Nearby Devices permissions for scan + adapter access.
    return scanOk && connectOk;
  }

  void clearLogs() {
    adapterStateLog.clear();
    connectionEventLog.clear();
    adapterStateLog.refresh();
    connectionEventLog.refresh();
    _logAdapterState(adapterState.value, source: 'stream');
  }

  // — Platform / adapter —

  Future<void> fetchPlatformVersion() async {
    platformVersion.value = await _plugin.getPlatformVersion();
  }

  Future<void> fetchAdapterState() async {
    final state = await _plugin.getAdapterState();
    polledAdapterState.value = state;
    _logAdapterState(state, source: 'poll');
    queryStatusMessage.value = 'getAdapterState(): ${state.name}';
  }

  // — Service —

  Future<void> startService() async {
    status.value = 'Requesting permissions...';
    if (!await ensurePermissions()) {
      status.value = 'Bluetooth permission denied';
      return;
    }

    // Adapter stream only updates on radio changes — re-poll after grant.
    adapterState.value = await _plugin.getAdapterState();
    _logAdapterState(adapterState.value, source: 'poll');

    if (adapterState.value == BleAdapterState.unauthorized) {
      status.value = 'Bluetooth permission denied — grant Nearby devices '
          'in system settings';
      return;
    }

    final started = await _plugin.startService(
      notificationTitle: 'Flutter Blue Background',
      notificationContent: _buildNotificationContent(),
    );
    status.value = started ? 'Service started' : 'Failed to start';
    await _refreshRunningState();
  }

  Future<void> stopService() async {
    final stopped = await _plugin.stopService();
    isScanning.value = await _plugin.isScanning();
    _lastNotificationContent = null;
    status.value = stopped ? 'Service stopped' : 'Failed to stop';
    await _refreshRunningState();
  }

  Future<void> refreshServiceFlags() async {
    isRunning.value = await _plugin.isServiceRunning();
    isScanning.value = await _plugin.isScanning();
    status.value = 'Refreshed — service ${isRunning.value}, '
        'scanning ${isScanning.value}';
  }

  // — Scan —

  Future<void> startScan() async {
    if (!isRunning.value) {
      status.value = 'Start the service first';
      return;
    }

    if (!await ensurePermissions()) {
      status.value = 'Bluetooth permission denied';
      return;
    }

    adapterState.value = await _plugin.getAdapterState();
    _logAdapterState(adapterState.value, source: 'poll');

    if (!adapterState.value.canScan) {
      status.value = 'Bluetooth is ${adapterState.value.name}';
      return;
    }

    devices.clear();

    const config = ScanConfig(
      serviceUuids: [],
      skipUnnamedDevices: skipUnnamedDevices,
      rssiThreshold: -180,
      android: AndroidScanSettings(scanMode: AndroidScanMode.lowLatency),
      ios: IosScanOptions(allowDuplicates: true),
    );

    final started = await _plugin.startScan(config);
    isScanning.value = started;
    status.value =
        started ? 'Scanning...' : 'Failed to start scan (is Bluetooth on?)';
    await _updateNotification();
  }

  Future<void> stopScan() async {
    await _plugin.stopScan();
    isScanning.value = false;
    status.value = 'Scan stopped';
    await _updateNotification();
  }

  Future<void> refreshCachedScanResults() async {
    final cached = await _plugin.getScanResults();
    for (final result in cached) {
      _addScanResult(result);
    }
    status.value = 'getScanResults(): ${cached.length} device(s) in cache';
  }

  Future<void> clearCachedScanResults() async {
    await _plugin.clearScanResults();
    devices.clear();
    status.value = 'clearScanResults(): cache cleared';
  }

  Future<void> connectTo(BleScanResult device) async {
    if (!isRunning.value) {
      status.value = 'Start the service first';
      return;
    }

    if (!adapterState.value.canConnect) {
      status.value = BleNotificationBuilder.adapterStatusMessage(
        adapterState.value,
        currentStatus: status.value,
      );
      return;
    }

    status.value = 'Connecting to ${device.displayName}...';
    _setConnectionState(device.deviceId, BleConnectionState.connecting);
    await _updateNotification();

    const config = ConnectConfig(
      timeout: Duration(seconds: 15),
      discoverServicesOnConnect: true,
      android: AndroidConnectOptions(
        mtu: 512,
        connectionPriority: ConnectionPriority.high,
      ),
      ios: IosConnectOptions(enableAutoReconnect: true),
    );

    final started = await _plugin.connect(device.deviceId, config);
    if (!started) {
      status.value = 'Failed to start connection';
      _setConnectionState(device.deviceId, BleConnectionState.disconnected);
      await _updateNotification();
    }
  }

  Future<void> connectToDeviceId(String deviceId) async {
    final device = devices[deviceId] ?? BleScanResult(deviceId: deviceId);
    await connectTo(device);
  }

  Future<void> disconnectFrom(String deviceId) async {
    _setConnectionState(deviceId, BleConnectionState.disconnecting);
    await _updateNotification();
    await _plugin.disconnect(deviceId);
    _setConnectionState(deviceId, BleConnectionState.disconnected);
    discoveredServices.remove(deviceId);
    status.value = 'Disconnected';
    await _updateNotification();
  }

  // — GATT —

  Future<void> discoverServicesFor(String deviceId) async {
    if (connectionStates[deviceId] != BleConnectionState.connected) {
      gattStatusMessage.value = 'Device must be connected to discover services';
      return;
    }

    isDiscoveringServices[deviceId] = true;
    isDiscoveringServices.refresh();
    gattStatusMessage.value = 'discoverServices($deviceId)…';

    try {
      final services = await _plugin.discoverServices(deviceId);
      discoveredServices[deviceId] = services;
      discoveredServices.refresh();
      gattStatusMessage.value = services.isEmpty
          ? 'discoverServices(): no services found'
          : 'discoverServices(): ${services.length} service(s), '
              '${services.fold<int>(0, (n, s) => n + s.characteristics.length)} '
              'characteristic(s)';
    } catch (e) {
      gattStatusMessage.value = 'discoverServices() failed: $e';
    } finally {
      isDiscoveringServices[deviceId] = false;
      isDiscoveringServices.refresh();
    }
  }

  Future<void> requestMtuFor(String deviceId, {int mtu = 512}) async {
    gattStatusMessage.value = 'requestMtu($deviceId, $mtu)…';
    try {
      final negotiated = await _plugin.requestMtu(deviceId, mtu);
      deviceMtu[deviceId] = negotiated;
      gattStatusMessage.value = 'requestMtu(): negotiated $negotiated';
    } catch (e) {
      gattStatusMessage.value = 'requestMtu() failed: $e';
    }
  }

  Future<void> requestConnectionPriorityFor(
    String deviceId,
    ConnectionPriority priority,
  ) async {
    gattStatusMessage.value =
        'requestConnectionPriority($deviceId, ${priority.name})…';
    try {
      await _plugin.requestConnectionPriority(deviceId, priority);
      gattStatusMessage.value =
          'requestConnectionPriority(): ${priority.name} applied';
    } catch (e) {
      gattStatusMessage.value = 'requestConnectionPriority() failed: $e';
    }
  }

  // — Connection queries —

  Future<void> fetchConnectedDevices() async {
    isQueryingConnections.value = true;
    queryStatusMessage.value = 'Calling getConnectedDevices()…';

    try {
      final ids = await _plugin.getConnectedDevices();
      queriedConnectedDeviceIds.assignAll(ids);
      queryStatusMessage.value = ids.isEmpty
          ? 'getConnectedDevices(): no devices connected'
          : 'getConnectedDevices(): ${ids.length} device(s)';
    } catch (e) {
      queryStatusMessage.value = 'getConnectedDevices() failed: $e';
      queriedConnectedDeviceIds.clear();
    } finally {
      isQueryingConnections.value = false;
    }
  }

  Future<void> fetchConnectionState(String deviceId) async {
    if (deviceId.isEmpty) {
      queryStatusMessage.value = 'Enter or pick a device id first';
      return;
    }

    isQueryingConnections.value = true;
    queryStatusMessage.value = 'Calling getConnectionState($deviceId)…';

    try {
      final state = await _plugin.getConnectionState(deviceId);
      queriedConnectionStates[deviceId] = state;
      queriedConnectionStates.refresh();
      queryStatusMessage.value =
          'getConnectionState($deviceId): ${state.name}';
    } catch (e) {
      queryStatusMessage.value = 'getConnectionState() failed: $e';
    } finally {
      isQueryingConnections.value = false;
    }
  }

  Future<void> fetchAllKnownConnectionStates() async {
    final ids = <String>{
      ...devices.keys,
      ...connectionStates.keys,
      ...queriedConnectedDeviceIds,
    };

    if (ids.isEmpty) {
      queryStatusMessage.value = 'No devices to query — scan or connect first';
      return;
    }

    isQueryingConnections.value = true;
    queryStatusMessage.value = 'Querying ${ids.length} device(s)…';

    try {
      for (final id in ids) {
        queriedConnectionStates[id] = await _plugin.getConnectionState(id);
      }
      queriedConnectionStates.refresh();
      queryStatusMessage.value =
          'Queried getConnectionState() for ${ids.length} device(s)';
    } catch (e) {
      queryStatusMessage.value = 'Batch getConnectionState() failed: $e';
    } finally {
      isQueryingConnections.value = false;
    }
  }
}
