import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../main.dart';
import '../widgets/widgets.dart';

class SystemHealthMonitor {
  static Timer? _timer;
  static Future<bool>? _inFlightCheck;
  static bool _sheetShown = false;
  static VoidCallback? onRetryCallback;

  /// Start periodic background health monitoring task.
  static void start() {
    _timer?.cancel();
    checkHealth();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => checkHealth());
  }

  /// Stop background health monitoring task.
  static void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// Manually check health, returns true if healthy, false otherwise.
  static Future<bool> checkHealth() {
    if (_inFlightCheck != null) {
      return _inFlightCheck!;
    }
    _inFlightCheck = _doCheckHealth();
    return _inFlightCheck!;
  }

  static Future<bool> _doCheckHealth() async {
    try {
      final uri = Uri.parse('${AppConfig.baseUrl}${AppConfig.healthEndpoint}');
      final res = await http.get(uri).timeout(const Duration(seconds: 5));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final isHealthy = data['status'] == 'healthy';
        if (isHealthy) {
          _sheetShown = false;
          return true;
        } else {
          final dbDown = data['database']?['status'] == 'down';
          final redisDown = data['redis']?['status'] == 'down';
          String detail = 'Service is undergoing maintenance.';
          if (dbDown && redisDown) {
            detail =
                'PostgreSQL database and Redis cache services are offline.';
          } else if (dbDown) {
            detail = 'PostgreSQL database service is currently offline.';
          } else if (redisDown) {
            detail = 'Redis caching service is currently offline.';
          }
          _showErrorSheet(title: 'Service Error', message: detail);
          return false;
        }
      } else {
        _showErrorSheet(
          title: 'Service Error',
          message:
              'Unable to connect to backend services. Server returned status code ${res.statusCode}.',
        );
        return false;
      }
    } catch (_) {
      _showErrorSheet(
        title: 'Service Error',
        message:
            'Cannot connect to BondVault PK server at ${AppConfig.baseUrl}. Please check your internet connection or server status.',
      );
      return false;
    } finally {
      _inFlightCheck = null;
    }
  }

  static void _showErrorSheet({
    required String title,
    required String message,
  }) {
    if (_sheetShown) return;
    final context = navigatorKey.currentContext;
    if (context == null) return;
    _sheetShown = true;

    showAppNotificationSheet(
      context: context,
      title: title,
      message: message,
      type: AppNotificationType.error,
      dismissLabel: 'Close App',
      onDismiss: () {
        _sheetShown = false;
        SystemNavigator.pop();
      },
      customAction: AppButton(
        label: 'Retry Connection',
        icon: const Icon(Icons.refresh, size: 18),
        onPressed: () {
          Navigator.pop(context);
          _sheetShown = false;
          if (onRetryCallback != null) {
            onRetryCallback!();
          } else {
            checkHealth();
          }
        },
      ),
    );
  }
}
