import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import '../config/app_config.dart';
import 'api_service.dart';
import 'push_notification_service.dart';

const String userReportWorkTask = 'bondvault_user_reports_background_task';

Future<String?> _refreshTokenInBackground(
  String username,
  String password,
) async {
  try {
    final loginUri = Uri.parse(
      '${AppConfig.baseUrl}${AppConfig.loginEndpoint}',
    );
    final response = await http
        .post(
          loginUri,
          headers: {'Content-Type': 'application/x-www-form-urlencoded'},
          body: {'username': username, 'password': password},
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final loginData = jsonDecode(response.body);
      final accessToken = loginData['access_token'];
      if (accessToken is String && accessToken.isNotEmpty) {
        return accessToken;
      }
    }
  } catch (_) {}
  return null;
}

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();
    try {
      final prefs = await SharedPreferences.getInstance();
      var cachedToken = prefs.getString('cached_access_token') ?? '';
      final savedUsername = prefs.getString('saved_username') ?? '';
      final savedPassword = prefs.getString('saved_password') ?? '';

      // If user credentials are saved, refresh token to guarantee access_token is valid
      if (savedUsername.isNotEmpty && savedPassword.isNotEmpty) {
        final freshToken = await _refreshTokenInBackground(
          savedUsername,
          savedPassword,
        );
        if (freshToken != null && freshToken.isNotEmpty) {
          cachedToken = freshToken;
          await prefs.setString('cached_access_token', freshToken);
        }
      }

      if (cachedToken.isNotEmpty) {
        await UserNotificationMonitor.checkUserTicketUpdatesDirect(cachedToken);
      }

      // Re-queue next 60-second background check so it loops continuously even when app is turned off
      Workmanager().registerOneOffTask(
        "closed_app_loop_${DateTime.now().millisecondsSinceEpoch}",
        userReportWorkTask,
        initialDelay: const Duration(seconds: 60),
        existingWorkPolicy: ExistingWorkPolicy.replace,
        constraints: Constraints(networkType: NetworkType.connected),
      );
    } catch (_) {}
    return Future.value(true);
  });
}

class UserNotificationMonitor {
  static Timer? _timer;
  static bool _isChecking = false;

  /// Start background push notification monitor for the authenticated user.
  static void start(String accessToken) {
    _timer?.cancel();
    if (accessToken.isEmpty) return;

    PushNotificationService.initialize();

    // 1. Active app timer check (runs every 10s while app is active)
    checkUserTicketUpdatesDirect(accessToken);
    _timer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => checkUserTicketUpdatesDirect(accessToken),
    );

    // 2. Closed-app Workmanager background tasks (runs when app is turned off / killed)
    try {
      Workmanager().initialize(callbackDispatcher);

      // Register periodic background task
      Workmanager().registerPeriodicTask(
        "user_reports_periodic_check",
        userReportWorkTask,
        frequency: const Duration(minutes: 15),
        existingWorkPolicy: ExistingPeriodicWorkPolicy.replace,
        constraints: Constraints(networkType: NetworkType.connected),
      );
    } catch (_) {}
  }

  /// Stop background user notification monitor (e.g. on logout or admin session).
  static void stop() {
    _timer?.cancel();
    _timer = null;
    try {
      Workmanager().cancelByUniqueName("user_reports_periodic_check");
    } catch (_) {}
  }

  /// Schedule a WorkManager background check when user pauses or closes the app
  static void scheduleClosedAppCheck(String accessToken) {
    if (accessToken.isEmpty) return;
    try {
      Workmanager().registerOneOffTask(
        "closed_app_check_${DateTime.now().millisecondsSinceEpoch}",
        userReportWorkTask,
        initialDelay: const Duration(seconds: 60),
        existingWorkPolicy: ExistingWorkPolicy.replace,
        constraints: Constraints(networkType: NetworkType.connected),
      );
    } catch (_) {}
  }

  static Future<void> checkUserTicketUpdatesDirect(String accessToken) async {
    if (_isChecking || accessToken.isEmpty) return;
    _isChecking = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      var reports = await ApiService.fetchUserReports(accessToken);

      // If token expired (reports is null), attempt refresh using saved credentials
      if (reports == null) {
        final savedUsername = prefs.getString('saved_username') ?? '';
        final savedPassword = prefs.getString('saved_password') ?? '';
        if (savedUsername.isNotEmpty && savedPassword.isNotEmpty) {
          final freshToken = await _refreshTokenInBackground(
            savedUsername,
            savedPassword,
          );
          if (freshToken != null && freshToken.isNotEmpty) {
            accessToken = freshToken;
            await prefs.setString('cached_access_token', freshToken);
            reports = await ApiService.fetchUserReports(freshToken);
          }
        }
      }

      if (reports == null || reports.isEmpty) return;

      for (final report in reports) {
        final String ticketId = report['id']?.toString() ?? '';
        final String subject =
            report['subject']?.toString() ?? 'Support Ticket';
        final String currentStatus =
            report['status']?.toString().toLowerCase() ?? 'open';

        if (ticketId.isEmpty) continue;

        final lastKnownStatus = prefs.getString('user_ticket_status_$ticketId');
        final lastKnownMsgId = prefs.getString(
          'user_ticket_last_msg_$ticketId',
        );

        // 1. Check for Ticket Closure (Only if ticket was previously tracked as open)
        if (currentStatus == 'closed' &&
            lastKnownStatus != null &&
            lastKnownStatus != 'closed') {
          await PushNotificationService.showTicketClosedNotification(
            ticketId: ticketId,
            ticketTitle: subject,
          );
        }
        await prefs.setString('user_ticket_status_$ticketId', currentStatus);

        // 2. Check for New Admin Replies
        final messages = await ApiService.fetchReportMessages(
          accessToken: accessToken,
          reportId: ticketId,
          isAdmin: false,
        );

        if (messages != null && messages.isNotEmpty) {
          final lastMsg = messages.last;
          final String msgId = lastMsg['id']?.toString() ?? '';
          final String senderType =
              lastMsg['sender_type']?.toString().toLowerCase() ?? 'user';
          final String msgText = lastMsg['message']?.toString() ?? '';

          final bool isNewAdminMsg =
              (senderType == 'admin') &&
              msgId.isNotEmpty &&
              (msgId != lastKnownMsgId);

          if (isNewAdminMsg) {
            await PushNotificationService.showTicketReplyNotification(
              ticketId: ticketId,
              ticketTitle: subject,
              replyText: msgText,
            );
          }
          if (msgId.isNotEmpty) {
            await prefs.setString('user_ticket_last_msg_$ticketId', msgId);
          }
        }
      }

      // 3. Check for New Winning Bond Alerts in User Portfolio
      try {
        final winningsData = await ApiService.fetchBondWinnings(accessToken);
        if (winningsData != null) {
          final results = winningsData['results'] as List? ?? [];
          final int currentTotalWins = results.length;
          final int? lastKnownWins = prefs.getInt('user_total_winning_bonds');

          if (lastKnownWins == null) {
            // Initial run: seed current total count without firing duplicate notifications for existing draws
            await prefs.setInt('user_total_winning_bonds', currentTotalWins);
          } else if (currentTotalWins > lastKnownWins) {
            // New winning bonds found since last check
            final int newWins = currentTotalWins - lastKnownWins;
            final lastWin = results.isNotEmpty ? results.last : {};
            final denom = lastWin['denomination'] as int? ?? 750;
            final dateStr = lastWin['draw_date']?.toString() ?? '';

            await PushNotificationService.showWinningDrawNotification(
              denomination: denom,
              winningCount: newWins,
              drawDate: dateStr,
            );
            await prefs.setInt('user_total_winning_bonds', currentTotalWins);
          }
        }
      } catch (_) {}
    } catch (_) {
    } finally {
      _isChecking = false;
    }
  }
}
