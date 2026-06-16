import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_blue_background/flutter_blue_background.dart';
import 'package:flutter_blue_background/flutter_blue_background_platform_interface.dart';
import 'package:flutter_blue_background/flutter_blue_background_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockFlutterBlueBackgroundPlatform
    with MockPlatformInterfaceMixin
    implements FlutterBlueBackgroundPlatform {
  bool running = false;

  @override
  Future<String?> getPlatformVersion() => Future.value('42');

  @override
  Future<bool> startService({
    String? notificationTitle,
    String? notificationContent,
  }) {
    running = true;
    return Future.value(true);
  }

  @override
  Future<bool> stopService() {
    running = false;
    return Future.value(true);
  }

  @override
  Future<bool> isServiceRunning() => Future.value(running);

  bool scanning = false;

  @override
  Future<bool> startScan(ScanConfig config) {
    scanning = true;
    return Future.value(true);
  }

  @override
  Future<bool> stopScan() {
    scanning = false;
    return Future.value(true);
  }

  @override
  Future<bool> isScanning() => Future.value(scanning);

  @override
  Stream<BleScanResult> get scanResults => const Stream.empty();
}

void main() {
  final FlutterBlueBackgroundPlatform initialPlatform = FlutterBlueBackgroundPlatform.instance;

  test('$MethodChannelFlutterBlueBackground is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelFlutterBlueBackground>());
  });

  test('getPlatformVersion', () async {
    FlutterBlueBackground flutterBlueBackgroundPlugin = FlutterBlueBackground();
    MockFlutterBlueBackgroundPlatform fakePlatform = MockFlutterBlueBackgroundPlatform();
    FlutterBlueBackgroundPlatform.instance = fakePlatform;

    expect(await flutterBlueBackgroundPlugin.getPlatformVersion(), '42');
  });

  test('start/stop service updates running state', () async {
    FlutterBlueBackground flutterBlueBackgroundPlugin = FlutterBlueBackground();
    MockFlutterBlueBackgroundPlatform fakePlatform = MockFlutterBlueBackgroundPlatform();
    FlutterBlueBackgroundPlatform.instance = fakePlatform;

    expect(await flutterBlueBackgroundPlugin.isServiceRunning(), false);

    expect(await flutterBlueBackgroundPlugin.startService(), true);
    expect(await flutterBlueBackgroundPlugin.isServiceRunning(), true);

    expect(await flutterBlueBackgroundPlugin.stopService(), true);
    expect(await flutterBlueBackgroundPlugin.isServiceRunning(), false);
  });
}
