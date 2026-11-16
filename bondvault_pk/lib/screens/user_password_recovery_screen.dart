import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../config/app_theme.dart';
import '../config/responsive.dart';
import '../widgets/widgets.dart';
import 'login_screen.dart';

class UserPasswordRecoveryScreen extends StatefulWidget {
  const UserPasswordRecoveryScreen({super.key});

  @override
  State<UserPasswordRecoveryScreen> createState() =>
      _UserPasswordRecoveryScreenState();
}

class _UserPasswordRecoveryScreenState
    extends State<UserPasswordRecoveryScreen> {
  int _step = 1; // 1: Email Request, 2: OTP & New Password Reset
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  final _step1FormKey = GlobalKey<FormState>();
  final _step2FormKey = GlobalKey<FormState>();

  bool _isSubmitting = false;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  Timer? _resendTimer;
  int _resendCountdown = 60;

  @override
  void dispose() {
    _resendTimer?.cancel();
    _emailController.dispose();
    _codeController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _startResendTimer() {
    _resendTimer?.cancel();
    setState(() => _resendCountdown = 60);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_resendCountdown <= 1) {
        timer.cancel();
        setState(() => _resendCountdown = 0);
      } else {
        setState(() => _resendCountdown--);
      }
    });
  }

  double _calculatePasswordStrength(String password) {
    if (password.isEmpty) return 0.0;
    double score = 0.0;
    if (password.length >= 8) score += 0.25;
    if (password.length >= 12) score += 0.25;
    if (RegExp(r'[A-Z]').hasMatch(password)) score += 0.15;
    if (RegExp(r'[0-9]').hasMatch(password)) score += 0.15;
    if (RegExp(r'[!@#$&*~_]').hasMatch(password)) score += 0.20;
    return score.clamp(0.0, 1.0);
  }

  Color _getStrengthColor(double score) {
    if (score < 0.4) return AppColors.error;
    if (score < 0.7) return AppColors.warning;
    return AppColors.success;
  }

  String _getStrengthLabel(double score) {
    if (score == 0.0) return '';
    if (score < 0.4) return 'Weak';
    if (score < 0.7) return 'Medium';
    return 'Strong';
  }

  String _parseErrorMessage(
    dynamic data, [
    String fallback = 'Password recovery failed.',
  ]) {
    if (data == null) return fallback;
    if (data is Map<String, dynamic>) {
      final detail = data['detail'];
      if (detail is String && detail.isNotEmpty) return detail;
      if (detail is List && detail.isNotEmpty) {
        final first = detail[0];
        if (first is Map) {
          final msg = first['msg']?.toString() ?? '';
          final loc = first['loc'] is List ? (first['loc'] as List) : [];
          final field = loc.isNotEmpty ? loc.last.toString() : '';
          if (field == 'new_password') {
            return 'New password must be at least 8 characters long.';
          }
          if (field == 'code') {
            return 'Invalid 6-digit recovery code.';
          }
          return field.isNotEmpty ? '$field: $msg' : msg;
        }
        return detail[0].toString();
      }
      if (data.containsKey('message')) return data['message'].toString();
    }
    return data.toString();
  }

  Future<void> _requestRecoveryCode() async {
    if (!_step1FormKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    final email = _emailController.text.trim();

    try {
      final res = await http.post(
        Uri.parse(
          '${AppConfig.baseUrl}${AppConfig.userPasswordRecoveryEndpoint}',
        ),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email}),
      );

      if (!mounted) return;

      if (res.statusCode == 202 || res.statusCode == 200) {
        _startResendTimer();
        setState(() => _step = 2);
        showAppToast(
          context,
          'Password recovery code sent to $email.',
          type: AppNotificationType.info,
        );
      } else {
        final data = jsonDecode(res.body);
        showAppToast(
          context,
          _parseErrorMessage(data, 'Password recovery request failed.'),
          type: AppNotificationType.error,
        );
      }
    } catch (e) {
      if (!mounted) return;
      showAppToast(
        context,
        'Connection Error: $e',
        type: AppNotificationType.error,
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _completePasswordRecovery() async {
    if (!_step2FormKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    final email = _emailController.text.trim();
    final code = _codeController.text.trim();
    final newPassword = _newPasswordController.text.trim();

    try {
      final res = await http.post(
        Uri.parse(
          '${AppConfig.baseUrl}${AppConfig.userPasswordRecoveryCompleteEndpoint}',
        ),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'code': code,
          'new_password': newPassword,
        }),
      );

      if (!mounted) return;

      if (res.statusCode == 200) {
        showAppNotificationSheet(
          context: context,
          title: 'Password Reset Complete',
          message: 'Your password has been reset successfully. You can now sign in with your new credentials.',
          type: AppNotificationType.success,
          dismissLabel: 'Go to Sign In',
          onDismiss: () {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => const LoginScreen()),
              (route) => false,
            );
          },
        );
      } else {
        final data = jsonDecode(res.body);
        showAppToast(
          context,
          _parseErrorMessage(data, 'Password recovery reset failed.'),
          type: AppNotificationType.error,
        );
      }
    } catch (e) {
      if (!mounted) return;
      showAppToast(
        context,
        'Connection Error: $e',
        type: AppNotificationType.error,
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final newPassword = _newPasswordController.text;
    final strength = _calculatePasswordStrength(newPassword);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'Password Recovery',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: Responsive.w(context, 16),
          vertical: Responsive.h(context, 16),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: Responsive.maxContentWidth(context),
            ),
            child: _step == 1
                ? _buildStep1RequestForm()
                : _buildStep2ResetForm(newPassword, strength),
          ),
        ),
      ),
    );
  }

  Widget _buildStep1RequestForm() {
    return Form(
      key: _step1FormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner Header Card
          AppCard(
            padding: const EdgeInsets.all(20),
            borderRadius: 20,
            gradient: const LinearGradient(
              colors: [Color(0xFF003527), Color(0xFF064E3B)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.lock_reset,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Forgot Your Password?',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Enter your registered email address to receive a 6-digit recovery code',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFFD1FAE5),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Email Input Card
          AppCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ACCOUNT EMAIL ADDRESS',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 6),
                AppTextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  labelText: 'Enter account email',
                  hintText: 'e.g. user@example.com',
                  prefixIcon: const Icon(Icons.email_outlined),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty || !v.contains('@')) {
                      return 'Valid email address required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                AppButton(
                  label: 'Send Recovery Code',
                  isLoading: _isSubmitting,
                  icon: const Icon(Icons.send_outlined, size: 18),
                  onPressed: _requestRecoveryCode,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep2ResetForm(String newPassword, double strength) {
    return Form(
      key: _step2FormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner Header Card
          AppCard(
            padding: const EdgeInsets.all(20),
            borderRadius: 20,
            gradient: const LinearGradient(
              colors: [Color(0xFF003527), Color(0xFF064E3B)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: const [
                        Icon(
                          Icons.mark_email_read_outlined,
                          color: Colors.white,
                          size: 20,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'STEP 2 OF 2',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                            color: Color(0xFFD1FAE5),
                          ),
                        ),
                      ],
                    ),
                    TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.zero,
                      ),
                      onPressed: () => setState(() => _step = 1),
                      child: const Text(
                        'Change Email',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Recovery code sent to ${_emailController.text.trim()}',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Code & Reset Form
          AppCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '6-DIGIT RECOVERY CODE',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                        color: AppColors.primary,
                      ),
                    ),
                    if (_resendCountdown > 0)
                      Text(
                        'Resend in ${_resendCountdown}s',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.grey,
                        ),
                      )
                    else
                      GestureDetector(
                        onTap: _requestRecoveryCode,
                        child: const Text(
                          'Resend Code',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                AppTextField(
                  controller: _codeController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  labelText: '6-digit OTP code',
                  prefixIcon: const Icon(Icons.dialpad),
                  validator: (v) {
                    if (v == null || v.trim().length != 6) {
                      return 'Must be a 6-digit code';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                const Text(
                  'NEW PASSWORD',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 6),
                AppTextField(
                  controller: _newPasswordController,
                  obscureText: _obscureNew,
                  labelText: 'Enter new password (min 8 chars)',
                  prefixIcon: const Icon(Icons.key),
                  onChanged: (_) => setState(() {}),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureNew ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () => setState(() => _obscureNew = !_obscureNew),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().length < 8) {
                      return 'New password must be at least 8 characters';
                    }
                    return null;
                  },
                ),
                if (newPassword.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: strength,
                            color: _getStrengthColor(strength),
                            backgroundColor: Colors.grey.shade200,
                            minHeight: 5,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        _getStrengthLabel(strength),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: _getStrengthColor(strength),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),

                const Text(
                  'CONFIRM NEW PASSWORD',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 6),
                AppTextField(
                  controller: _confirmPasswordController,
                  obscureText: _obscureConfirm,
                  labelText: 'Re-enter new password',
                  prefixIcon: const Icon(Icons.check_circle_outline),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureConfirm ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () =>
                        setState(() => _obscureConfirm = !_obscureConfirm),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Confirm new password';
                    }
                    if (v.trim() != _newPasswordController.text.trim()) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                AppButton(
                  label: 'Reset Password & Sign In',
                  isLoading: _isSubmitting,
                  icon: const Icon(Icons.lock_open_outlined, size: 18),
                  onPressed: _completePasswordRecovery,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
