import 'package:flutter/services.dart';

class LocalNotificationUtils {
  static const MethodChannel _channel = MethodChannel(
    'bondvault_pk/notifications',
  );

  /// Send an Android system notification when a PDF download starts.
  static Future<void> showDownloadStartedNotification({
    required int denomination,
    required String drawDate,
  }) async {
    try {
      await _channel.invokeMethod('showNotification', {
        'title': 'PDF Download Started',
        'body':
            'Downloading official Rs. $denomination ($drawDate) Gazette PDF...',
      });
    } catch (_) {
      // Fallback gracefully on desktop or platform targets without native channel
    }
  }
}
