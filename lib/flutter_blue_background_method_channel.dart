import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'flutter_blue_background_platform_interface.dart';

/// An implementation of [FlutterBlueBackgroundPlatform] that uses method channels.
class MethodChannelFlutterBlueBackground extends FlutterBlueBackgroundPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('flutter_blue_background');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>(
      'getPlatformVersion',
    );
    return version;
  }

  @override
  Future<bool> startService({
    String? notificationTitle,
    String? notificationContent,
  }) async {
    final started = await methodChannel.invokeMethod<bool>('startService', {
      'notificationTitle': notificationTitle,
      'notificationContent': notificationContent,
    });
    return started ?? false;
  }

  @override
  Future<bool> stopService() async {
    final stopped = await methodChannel.invokeMethod<bool>('stopService');
    return stopped ?? false;
  }

  @override
  Future<bool> isServiceRunning() async {
    final running = await methodChannel.invokeMethod<bool>('isServiceRunning');
    return running ?? false;
  }
}
