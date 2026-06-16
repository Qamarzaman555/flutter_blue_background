
import 'flutter_blue_background_platform_interface.dart';

class FlutterBlueBackground {
  Future<String?> getPlatformVersion() {
    return FlutterBlueBackgroundPlatform.instance.getPlatformVersion();
  }

  /// Starts the native background (foreground) service so the app keeps
  /// running in the background. On Android this shows a persistent
  /// notification.
  ///
  /// Optionally customize the notification [notificationTitle] and
  /// [notificationContent].
  Future<bool> startService({
    String? notificationTitle,
    String? notificationContent,
  }) {
    return FlutterBlueBackgroundPlatform.instance.startService(
      notificationTitle: notificationTitle,
      notificationContent: notificationContent,
    );
  }

  /// Stops the native background service.
  Future<bool> stopService() {
    return FlutterBlueBackgroundPlatform.instance.stopService();
  }

  /// Returns whether the native background service is currently running.
  Future<bool> isServiceRunning() {
    return FlutterBlueBackgroundPlatform.instance.isServiceRunning();
  }
}
