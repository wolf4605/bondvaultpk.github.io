import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import '../config/app_theme.dart';
import '../utils/permission_utils.dart';
import '../widgets/widgets.dart';
import 'login_screen.dart';
import 'pin_unlock_screen.dart';
import 'user_screens/home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  String _statusMessage = 'Initializing BondVault PK...';
  bool _hasError = false;
  bool _sheetShown = false;

  @override
  void initState() {
    super.initState();
    PermissionUtils.requestAppPermissions();
    _checkSystemHealth();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    precacheImage(const AssetImage('assets/logo.png'), context);
  }

  void _showErrorSheet({required String title, required String message}) {
    if (_sheetShown) return;
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
          _checkSystemHealth();
        },
      ),
    );
  }

  Future<void> _checkSystemHealth() async {
    final prefs = await SharedPreferences.getInstance();
    final appPin = prefs.getString('app_pin');
    final cachedToken = prefs.getString('cached_access_token');
    final cachedUserInfoStr = prefs.getString('cached_user_info');

    // If an app PIN is set and session exists, show Pin Unlock Screen immediately before splash checks
    if (appPin != null &&
        appPin.isNotEmpty &&
        cachedToken != null &&
        cachedToken.isNotEmpty &&
        cachedUserInfoStr != null &&
        cachedUserInfoStr.isNotEmpty) {
      try {
        final userInfo = jsonDecode(cachedUserInfoStr);
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => PinUnlockScreen(
                accessToken: cachedToken,
                userInfo: userInfo,
                correctPin: appPin,
              ),
            ),
          );
          return;
        }
      } catch (_) {}
    }

    setState(() {
      _hasError = false;
      _statusMessage = 'Checking internet connection...';
    });

    try {
      // 1. Check Internet Connection
      final connectivityResults = await Connectivity().checkConnectivity();
      final isConnected = connectivityResults.any(
        (result) => result != ConnectivityResult.none,
      );

      if (!isConnected) {
        setState(() {
          _hasError = true;
          _statusMessage = 'No internet connection available.';
        });
        _showErrorSheet(
          title: 'Connection Error',
          message: 'No internet connection available. Please check your Wi-Fi or cellular network.',
        );
        return;
      }

      // 2. Check Backend, Database, and Redis health
      setState(() {
        _statusMessage = 'Connecting to backend services...';
      });

      final uri = Uri.parse('${AppConfig.baseUrl}${AppConfig.healthEndpoint}');
      final response = await http.get(uri).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200 || response.statusCode == 503) {
        final data = jsonDecode(response.body);
        final backendStatus = data['backend']?['status'] == 'up';
        final dbStatus = data['database']?['status'] == 'up';
        final redisStatus = data['redis']?['status'] == 'up';

        if (backendStatus && dbStatus && redisStatus) {
          setState(() {
            _statusMessage = 'System online! Checking session...';
          });

          // Check if saved username and password exist locally
          final savedUsername = prefs.getString('saved_username');
          final savedPassword = prefs.getString('saved_password');

          await Future.delayed(const Duration(milliseconds: 800));
          if (!mounted) return;

          if (savedUsername != null &&
              savedUsername.isNotEmpty &&
              savedPassword != null &&
              savedPassword.isNotEmpty) {
            setState(() {
              _statusMessage = 'Signing in automatically...';
            });

            try {
              final loginUri = Uri.parse(
                '${AppConfig.baseUrl}${AppConfig.loginEndpoint}',
              );
              final loginResponse = await http
                  .post(
                    loginUri,
                    headers: {
                      'Content-Type': 'application/x-www-form-urlencoded',
                    },
                    body: {
                      'username': savedUsername,
                      'password': savedPassword,
                    },
                  )
                  .timeout(const Duration(seconds: 10));

              if (!mounted) return;

              if (loginResponse.statusCode == 200) {
                final loginData = jsonDecode(loginResponse.body);
                final accessToken = loginData['access_token'];
                final userInfo = loginData['payload'];

                await prefs.setString('cached_access_token', accessToken);
                await prefs.setString('cached_user_info', jsonEncode(userInfo));

                if (!mounted) return;
                final currentPin = prefs.getString('app_pin');
                if (currentPin != null && currentPin.isNotEmpty) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PinUnlockScreen(
                        accessToken: accessToken,
                        userInfo: userInfo,
                        correctPin: currentPin,
                      ),
                    ),
                  );
                } else {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => HomeScreen(
                        accessToken: accessToken,
                        userInfo: userInfo,
                      ),
                    ),
                  );
                }
                return;
              }
            } catch (_) {}
          }

          if (!mounted) return;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const LoginScreen()),
          );
        } else {
          setState(() {
            _hasError = true;
            _statusMessage = 'Unable to connect to backend services.';
          });
          _showErrorSheet(
            title: 'Service Error',
            message: 'Unable to connect to backend services. Backend, database, or cache health check failed.',
          );
        }
      } else {
        setState(() {
          _hasError = true;
          _statusMessage = 'Unable to connect to backend services.';
        });
        _showErrorSheet(
          title: 'Service Error',
          message:
              'Unable to connect to backend services. Server returned status code ${response.statusCode}.',
        );
      }
    } catch (_) {
      setState(() {
        _hasError = true;
        _statusMessage = 'Unable to connect to backend services.';
      });
      _showErrorSheet(
        title: 'Service Error',
        message: 'Could not reach backend server. Please try again later.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFF),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Circular Logo Card
                Container(
                  width: 130,
                  height: 130,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Image.asset('assets/logo.png', fit: BoxFit.contain),
                ),
                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Text(
                      'BondVault ',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: AppColors.primary,
                        letterSpacing: -0.5,
                      ),
                    ),
                    Text(
                      'PK',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: AppColors.warning,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Secure Prize Bond Management',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 64),
                const AppLoadingIndicator(),
                const SizedBox(height: 20),
                Text(
                  _statusMessage,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _hasError
                        ? AppColors.error
                        : AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
