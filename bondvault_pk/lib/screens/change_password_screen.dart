import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import '../config/app_theme.dart';
import '../config/responsive.dart';
import '../widgets/widgets.dart';
import 'login_screen.dart';

class ChangePasswordScreen extends StatefulWidget {
  final String accessToken;
  final bool isAdmin;

  const ChangePasswordScreen({
    super.key,
    required this.accessToken,
    this.isAdmin = false,
  });

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _oldPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscureOld = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  double _calculatePasswordStrength(String password) {
    if (password.isEmpty) return 0.0;
    double score = 0.0;
    if (password.length >= 6) score += 0.25;
    if (password.length >= 10) score += 0.25;
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
    if (score < 0.4) return 'Weak Password';
    if (score < 0.7) return 'Medium Strength';
    return 'Strong Password';
  }

  Future<void> _handleChangePassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    final endpoint = widget.isAdmin
        ? AppConfig.adminChangePasswordEndpoint
        : AppConfig.userChangePasswordEndpoint;

    try {
      final res = await http.post(
        Uri.parse('${AppConfig.baseUrl}$endpoint'),
        headers: {
          'Authorization': 'Bearer ${widget.accessToken}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'old_password': _oldPasswordController.text.trim(),
          'new_password': _newPasswordController.text.trim(),
        }),
      );

      if (!mounted) return;

      if (res.statusCode == 200) {
        showAppNotificationSheet(
          context: context,
          title: 'Password Changed Successfully',
          message: 'Your password has been updated. Please sign in again with your new credentials.',
          type: AppNotificationType.success,
          dismissLabel: 'Sign In Again',
          onDismiss: () async {
            final prefs = await SharedPreferences.getInstance();
            await prefs.clear();
            if (!mounted) return;
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => const LoginScreen()),
              (route) => false,
            );
          },
        );
      } else {
        dynamic data;
        try {
          data = jsonDecode(res.body);
        } catch (_) {}

        String rawDetail = '';
        if (data is Map && data.containsKey('detail')) {
          rawDetail = data['detail'].toString();
        } else if (data is Map && data.containsKey('message')) {
          rawDetail = data['message'].toString();
        } else if (data != null) {
          rawDetail = data.toString();
        }

        final lowerDetail = rawDetail.toLowerCase();
        String errorMessage = 'Failed to change password.';

        if (res.statusCode == 403 ||
            res.statusCode == 401 ||
            res.statusCode == 400 ||
            lowerDetail.contains('invalid') ||
            lowerDetail.contains('old') ||
            lowerDetail.contains('incorrect') ||
            lowerDetail.contains('password')) {
          errorMessage = 'Invalid current password. Please enter your correct existing password.';
        } else if (res.statusCode == 409 ||
            lowerDetail.contains('same') ||
            lowerDetail.contains('conflict')) {
          errorMessage =
              'New password cannot be the same as your current password.';
        } else if (rawDetail.isNotEmpty) {
          errorMessage = rawDetail;
        }

        showAppNotificationSheet(
          context: context,
          title: 'Password Change Failed',
          message: errorMessage,
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
        title: Text(
          widget.isAdmin ? 'Admin Change Password' : 'Change Password',
          style: const TextStyle(fontWeight: FontWeight.bold),
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
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Banner Header Card
                  AppCard(
                    padding: const EdgeInsets.all(20),
                    borderRadius: 20,
                    gradient: LinearGradient(
                      colors: widget.isAdmin
                          ? const [Color(0xFF0F5132), Color(0xFF022C22)]
                          : const [Color(0xFF003527), Color(0xFF064E3B)],
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
                            children: [
                              Text(
                                widget.isAdmin
                                    ? 'Change Admin Password'
                                    : 'Update Account Password',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                'Re-authenticate with current password to set a new one',
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

                  // Form Container
                  AppCard(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'CURRENT PASSWORD',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        AppTextField(
                          controller: _oldPasswordController,
                          obscureText: _obscureOld,
                          labelText: 'Enter current password',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureOld
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                            ),
                            onPressed: () =>
                                setState(() => _obscureOld = !_obscureOld),
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Current password is required';
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
                              _obscureNew
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                            ),
                            onPressed: () =>
                                setState(() => _obscureNew = !_obscureNew),
                          ),
                          validator: (v) {
                            if (v == null || v.trim().length < 8) {
                              return 'New password must be at least 8 characters';
                            }
                            if (v.trim() ==
                                _oldPasswordController.text.trim()) {
                              return 'New password cannot be identical to current password';
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
                              _obscureConfirm
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                            ),
                            onPressed: () => setState(
                              () => _obscureConfirm = !_obscureConfirm,
                            ),
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Confirm new password';
                            }
                            if (v.trim() !=
                                _newPasswordController.text.trim()) {
                              return 'Passwords do not match';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),

                        AppButton(
                          label: 'Update Password',
                          isLoading: _isSubmitting,
                          icon: const Icon(Icons.save_outlined, size: 18),
                          onPressed: _handleChangePassword,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
