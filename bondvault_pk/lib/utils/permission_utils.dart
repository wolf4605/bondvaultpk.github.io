import 'package:flutter/services.dart';

class PermissionUtils {
  static const MethodChannel _channel = MethodChannel(
    'plugins.flutter.io/permission_handler',
  );

  /// Prompt native OS default system permission dialogs on every app start if not allowed.
  static Future<void> requestAppPermissions() async {
    try {
      // Native Android permission IDs:
      // 1: Camera (Take pictures & record video)
      // 9: Storage (Save PDF gazettes)
      // 14: Photos / Media
      // 32: Notifications (Draw alerts)
      final permissionIds = [1, 9, 14, 32];
      await _channel.invokeMethod('requestPermissions', permissionIds);
    } catch (_) {
      // Fallback gracefully on unhandled platforms
    }
  }
}
