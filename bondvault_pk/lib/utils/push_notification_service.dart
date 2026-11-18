import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_service.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
  } catch (_) {}

  final notification = message.notification;
  if (notification != null) {
    await PushNotificationService.showNotification(
      id: notification.hashCode,
      title: notification.title ?? 'BondVault PK Support',
      body: notification.body ?? 'You received a support update.',
      payload: message.data['ticket_id']?.toString(),
    );
  }
}

class PushNotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static const String _channelId = 'bondvault_user_reports_channel';
  static const String _channelName = 'Support & Reports Notifications';
  static const String _channelDescription =
      'Notifications for support ticket updates, admin replies, and ticket status changes.';

  static bool _initialized = false;

  /// Initialize system push notification channel and request permissions on user device.
  static Future<void> initialize() async {
    if (_initialized) return;

    try {
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(
        _firebaseMessagingBackgroundHandler,
      );
    } catch (_) {}

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
    );

    await _notificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Handle notification click if needed
      },
    );

    // Request Android 13+ Notification Permission
    if (Platform.isAndroid) {
      final androidImplementation = _notificationsPlugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await androidImplementation?.requestNotificationsPermission();

      try {
        await FirebaseMessaging.instance.requestPermission(
          alert: true,
          badge: true,
          sound: true,
        );
      } catch (_) {}
    }

    // Handle foreground FCM messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final notification = message.notification;
      if (notification != null) {
        showNotification(
          id: notification.hashCode,
          title: notification.title ?? 'BondVault PK Support',
          body: notification.body ?? 'New support update.',
          payload: message.data['ticket_id']?.toString(),
        );
      }
    });

    _initialized = true;
  }

  /// Show a system push notification in the mobile device's top notification panel.
  static Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    await initialize();

    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'BondVault PK Support Notification',
      styleInformation: BigTextStyleInformation(''),
      color: Color(0xFF003527),
      icon: '@mipmap/ic_launcher',
      visibility: NotificationVisibility.public,
      channelShowBadge: true,
      enableVibration: true,
      playSound: true,
    );

    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
    );

    await _notificationsPlugin.show(
      id,
      title,
      body,
      notificationDetails,
      payload: payload,
    );
  }

  /// Register user's FCM device token with backend for closed-app messaging.
  static Future<void> registerDeviceToken(String accessToken) async {
    if (accessToken.isEmpty) return;
    try {
      await initialize();
      String? token;
      try {
        token = await FirebaseMessaging.instance.getToken();
      } catch (_) {}

      // Fallback: If Firebase token is null/unavailable, generate a stable local device token
      if (token == null || token.isEmpty) {
        final prefs = await SharedPreferences.getInstance();
        token = prefs.getString('local_device_token');
        if (token == null || token.isEmpty) {
          token =
              'device_${DateTime.now().millisecondsSinceEpoch}_${accessToken.length > 8 ? accessToken.substring(0, 8) : accessToken}';
          await prefs.setString('local_device_token', token);
        }
      }

      if (token.isNotEmpty) {
        await ApiService.saveFcmToken(accessToken, token);
      }
    } catch (_) {}
  }

  /// Remove user's FCM device token from backend on logout.
  static Future<void> unregisterDeviceToken(String accessToken) async {
    if (accessToken.isEmpty) return;
    try {
      await ApiService.removeFcmToken(accessToken);
    } catch (_) {}
  }

  /// Trigger system notification when a user receives an admin reply on their ticket.
  static Future<void> showTicketReplyNotification({
    required String ticketId,
    required String ticketTitle,
    required String replyText,
  }) async {
    final shortId = ticketId.length >= 8 ? ticketId.substring(0, 8) : ticketId;
    final int notifyId = shortId.hashCode.abs() % 100000;

    await showNotification(
      id: notifyId,
      title: '💬 New Admin Reply on Ticket #$shortId',
      body: '"$ticketTitle"\n$replyText',
      payload: ticketId,
    );
  }

  /// Trigger system notification when a user's support ticket is closed by support.
  static Future<void> showTicketClosedNotification({
    required String ticketId,
    required String ticketTitle,
  }) async {
    final shortId = ticketId.length >= 8 ? ticketId.substring(0, 8) : ticketId;
    final int notifyId = (shortId.hashCode.abs() + 1) % 100000;

    await showNotification(
      id: notifyId,
      title: '✅ Support Ticket #$shortId Resolved',
      body: 'Your ticket "$ticketTitle" has been marked as closed/resolved.',
      payload: ticketId,
    );
  }

  /// Trigger system notification when a user has winning bonds in a newly uploaded gazette draw.
  static Future<void> showWinningDrawNotification({
    required int denomination,
    required int winningCount,
    required String drawDate,
  }) async {
    final int notifyId =
        (denomination + winningCount + drawDate.hashCode).abs() % 100000;

    await showNotification(
      id: notifyId,
      title: '🎉 Prize Bond Winning Alert!',
      body:
          'Found $winningCount winning bond(s) from your saved bonds in the latest Rs. $denomination draw!',
      payload: 'draw_result_$denomination',
    );
  }
}
