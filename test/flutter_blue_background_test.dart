import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_blue_background/flutter_blue_background.dart';
import 'package:flutter_blue_background/flutter_blue_background_platform_interface.dart';
import 'package:flutter_blue_background/flutter_blue_background_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockFlutterBlueBackgroundPlatform
    with MockPlatformInterfaceMixin
    implements FlutterBlueBackgroundPlatform {
  @override
  Future<String?> getPlatformVersion() => Future.value('42');
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
}
