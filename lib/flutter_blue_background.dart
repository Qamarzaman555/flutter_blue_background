
import 'flutter_blue_background_platform_interface.dart';

class FlutterBlueBackground {
  Future<String?> getPlatformVersion() {
    return FlutterBlueBackgroundPlatform.instance.getPlatformVersion();
  }
}
