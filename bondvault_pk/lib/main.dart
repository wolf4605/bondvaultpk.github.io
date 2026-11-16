import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'config/app_theme.dart';
import 'screens/pin_unlock_screen.dart';
import 'screens/splash_screen.dart';
import 'utils/system_health_monitor.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final appPin = prefs.getString('app_pin');
  final cachedToken = prefs.getString('cached_access_token') ?? '';
  final cachedUserInfoStr = prefs.getString('cached_user_info') ?? '';
  Map<String, dynamic> userInfo = {};

  if (cachedUserInfoStr.isNotEmpty) {
    try {
      final decoded = jsonDecode(cachedUserInfoStr);
      if (decoded is Map) {
        userInfo = Map<String, dynamic>.from(decoded);
      }
    } catch (_) {}
  }

  SystemHealthMonitor.start();
  runApp(
    BondVaultApp(
      initialPin: appPin,
      accessToken: cachedToken,
      userInfo: userInfo,
    ),
  );
}

class BondVaultApp extends StatelessWidget {
  final String? initialPin;
  final String accessToken;
  final Map<String, dynamic>? userInfo;

  const BondVaultApp({
    super.key,
    this.initialPin,
    this.accessToken = '',
    this.userInfo,
  });

  @override
  Widget build(BuildContext context) {
    final bool hasPin = initialPin != null && initialPin!.isNotEmpty;
    final safeUserInfo = userInfo ?? <String, dynamic>{};
    final bool isAdmin = safeUserInfo['role'] != null;

    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'BondVault PK',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      themeMode: ThemeMode.light,
      builder: (context, child) {
        final mediaData = MediaQueryData.fromView(View.of(context));
        return MediaQuery(
          data: mediaData.copyWith(
            textScaler: mediaData.textScaler.clamp(
              minScaleFactor: 0.90,
              maxScaleFactor: 1.08,
            ),
          ),
          child: child!,
        );
      },
      home: hasPin
          ? PinUnlockScreen(
              accessToken: accessToken,
              userInfo: safeUserInfo,
              correctPin: initialPin!,
              isAdmin: isAdmin,
            )
          : const SplashScreen(),
    );
  }
}
