import 'package:permission_handler/permission_handler.dart';

class PermissionUtils {
  /// Prompt native OS default system permission dialogs on app start.
  static Future<void> requestAppPermissions() async {
    try {
      await [
        Permission.notification,
        Permission.camera,
        Permission.storage,
      ].request();
    } catch (_) {}
  }
}
