import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../config/app_config.dart';
import '../../config/app_theme.dart';
import '../../config/responsive.dart';
import '../../widgets/widgets.dart';
import '../edit_profile_screen.dart';
import 'admin_audit_logs_screen.dart';
import 'admin_reports_screen.dart';

class AdminSettingsScreen extends StatefulWidget {
  final String accessToken;
  final Map<String, dynamic> adminInfo;
  final VoidCallback onLogout;

  const AdminSettingsScreen({
    super.key,
    required this.accessToken,
    required this.adminInfo,
    required this.onLogout,
  });

  @override
  State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen> {
  bool _hasAppPin = false;
  int _toastDuration = 3;
  bool _isChangingPassword = false;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final pin = prefs.getString('app_pin');
    final duration = prefs.getInt('toast_duration_seconds') ?? 3;
    if (mounted) {
      setState(() {
        _hasAppPin = pin != null && pin.isNotEmpty;
        _toastDuration = duration;
      });
    }
  }

  Future<void> _showToastDurationDialog() async {
    final selected = await showDialog<int>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Toast Notification Duration'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 2),
            child: const Text('2 seconds (Fast)'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 3),
            child: const Text('3 seconds (Normal)'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 5),
            child: const Text('5 seconds (Extended)'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 8),
            child: const Text('8 seconds (Long)'),
          ),
        ],
      ),
    );

    if (selected != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('toast_duration_seconds', selected);
      setState(() => _toastDuration = selected);
      if (!mounted) return;
      showAppToast(
        context,
        'Toast display duration set to $selected seconds',
        type: AppNotificationType.success,
      );
    }
  }

  Future<void> _showPinDialog({bool isEdit = false}) async {
    final pinController = TextEditingController();
    final confirmPinController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool obscure = true;

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isEdit ? 'Edit MPIN' : 'Set MPIN'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isEdit
                      ? 'Enter your new 4-digit admin console MPIN.'
                      : 'Secure your application with a 4-digit MPIN.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                AppTextField(
                  controller: pinController,
                  obscureText: obscure,
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  labelText: 'New MPIN (4 digits)',
                  prefixIcon: const Icon(Icons.dialpad),
                  suffixIcon: IconButton(
                    icon: Icon(
                      obscure ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () => setDialogState(() => obscure = !obscure),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'MPIN is required';
                    if (v.length != 4 || !RegExp(r'^[0-9]+$').hasMatch(v)) {
                      return 'Must be 4 digits';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                AppTextField(
                  controller: confirmPinController,
                  obscureText: obscure,
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  labelText: 'Confirm MPIN',
                  prefixIcon: const Icon(Icons.check_circle_outline),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Confirm MPIN';
                    if (v != pinController.text) return 'MPINs do not match';
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            AppButton(
              label: isEdit ? 'Update' : 'Save',
              fullWidth: false,
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setString('app_pin', pinController.text.trim());
                  if (!dialogContext.mounted) return;
                  Navigator.pop(dialogContext);
                  await _loadPreferences();
                  if (!mounted) return;
                  showAppToast(
                    this.context,
                    isEdit ? 'MPIN updated.' : 'MPIN set.',
                    type: AppNotificationType.success,
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _removePin() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove MPIN'),
        content: const Text('Are you sure you want to disable MPIN security?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          AppButton(
            label: 'Remove',
            variant: AppButtonVariant.danger,
            fullWidth: false,
            onPressed: () => Navigator.pop(dialogContext, true),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('app_pin');
      await _loadPreferences();
      if (!mounted) return;
      showAppToast(
        context,
        ' protection disabled.',
        type: AppNotificationType.warning,
      );
    }
  }

  Future<void> _handlePinTileTap() async {
    if (_hasAppPin) {
      final action = await showDialog<String>(
        context: context,
        builder: (dialogContext) => SimpleDialog(
          title: const Text('MPIN Security Options'),
          children: [
            SimpleDialogOption(
              onPressed: () => Navigator.pop(dialogContext, 'edit'),
              child: const Row(
                children: [
                  Icon(Icons.edit_outlined, size: 18),
                  SizedBox(width: 10),
                  Text('Edit 4-Digit MPIN'),
                ],
              ),
            ),
            SimpleDialogOption(
              onPressed: () => Navigator.pop(dialogContext, 'remove'),
              child: const Row(
                children: [
                  Icon(Icons.delete_outline, color: Colors.red, size: 18),
                  SizedBox(width: 10),
                  Text(
                    'Remove MPIN Security',
                    style: TextStyle(color: Colors.red),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

      if (action == 'edit') {
        await _showPinDialog(isEdit: true);
      } else if (action == 'remove') {
        await _removePin();
      }
    } else {
      await _showPinDialog(isEdit: false);
    }
  }

  Future<void> _showChangeOwnPasswordDialog() async {
    final oldPasswordCtrl = TextEditingController();
    final newPasswordCtrl = TextEditingController();
    final confirmPasswordCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          clipBehavior: Clip.antiAlias,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: Responsive.maxContentWidth(context),
              maxHeight: MediaQuery.sizeOf(context).height * 0.85,
            ),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 18,
                    ),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppColors.primary, AppColors.primaryContainer],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.key, color: Colors.white, size: 22),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text(
                                'Change My Admin Password',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Re-authenticate with current password to update',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFFD1FAE5),
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white70),
                          onPressed: () => Navigator.pop(dialogContext),
                        ),
                      ],
                    ),
                  ),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AppTextField(
                            controller: oldPasswordCtrl,
                            obscureText: true,
                            labelText: 'Current Password',
                            prefixIcon: const Icon(Icons.lock_outline),
                            validator: (v) => (v == null || v.isEmpty)
                                ? 'Current password is required'
                                : null,
                          ),
                          const SizedBox(height: 12),
                          AppTextField(
                            controller: newPasswordCtrl,
                            obscureText: true,
                            labelText: 'New Password (min 12 chars)',
                            prefixIcon: const Icon(Icons.key),
                            validator: (v) => (v == null || v.length < 6)
                                ? 'Must be at least 6 characters'
                                : null,
                          ),
                          const SizedBox(height: 12),
                          AppTextField(
                            controller: confirmPasswordCtrl,
                            obscureText: true,
                            labelText: 'Confirm New Password',
                            prefixIcon: const Icon(Icons.check_circle_outline),
                            validator: (v) {
                              if (v == null || v.isEmpty) {
                                return 'Confirm new password';
                              }
                              if (v != newPasswordCtrl.text) {
                                return 'Passwords do not match';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 24),
                          AppButton(
                            label: 'Change Password',
                            isLoading: _isChangingPassword,
                            icon: const Icon(Icons.save_outlined, size: 18),
                            onPressed: () async {
                              if (formKey.currentState!.validate()) {
                                setDialogState(
                                  () => _isChangingPassword = true,
                                );
                                try {
                                  final res = await http.post(
                                    Uri.parse(
                                      '${AppConfig.baseUrl}/admins/change-password',
                                    ),
                                    headers: {
                                      'Authorization':
                                          'Bearer ${widget.accessToken}',
                                      'Content-Type': 'application/json',
                                    },
                                    body: jsonEncode({
                                      'old_password': oldPasswordCtrl.text
                                          .trim(),
                                      'new_password': newPasswordCtrl.text
                                          .trim(),
                                    }),
                                  );

                                  if (res.statusCode == 200) {
                                    if (dialogContext.mounted) {
                                      Navigator.pop(dialogContext);
                                    }
                                    if (!mounted) return;
                                    showAppNotificationSheet(
                                      context: this.context,
                                      title: 'Password Changed',
                                      message: 'Your administrator password has been updated successfully.',
                                      type: AppNotificationType.success,
                                    );
                                  } else {
                                    final data = jsonDecode(res.body);
                                    if (dialogContext.mounted) {
                                      showAppToast(
                                        dialogContext,
                                        data['detail'] ??
                                            'Password update failed.',
                                        type: AppNotificationType.error,
                                      );
                                    }
                                  }
                                } catch (e) {
                                  if (dialogContext.mounted) {
                                    showAppToast(
                                      dialogContext,
                                      'Error: $e',
                                      type: AppNotificationType.error,
                                    );
                                  }
                                } finally {
                                  if (dialogContext.mounted) {
                                    setDialogState(
                                      () => _isChangingPassword = false,
                                    );
                                  }
                                }
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    oldPasswordCtrl.dispose();
    newPasswordCtrl.dispose();
    confirmPasswordCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final username = widget.adminInfo['username']?.toString().trim() ?? 'Admin';
    final email =
        widget.adminInfo['email']?.toString().trim() ?? 'admin@bondvault.pk';
    final firstName = widget.adminInfo['first_name']?.toString().trim() ?? '';
    final lastName = widget.adminInfo['last_name']?.toString().trim() ?? '';
    final fullName = '$firstName $lastName'.trim().isEmpty
        ? username
        : '$firstName $lastName'.trim();
    final role = (widget.adminInfo['role']?.toString() ?? 'admin')
        .toUpperCase();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'Admin Settings',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: Responsive.maxContentWidth(context),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // SECTION 1: ADMIN PROFILE
                const AppSectionHeader(
                  title: 'Admin Profile',
                  tagline: 'ACCOUNT',
                ),
                const SizedBox(height: 8),
                AppCard(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  username,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                AppBadge.admin(),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              fullName.isNotEmpty && fullName != username
                                  ? '$fullName • Role: $role'
                                  : 'Role: $role',
                              style: TextStyle(
                                fontSize: 13,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Icon(
                                  Icons.email_outlined,
                                  size: 16,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  email,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 36,
                        height: 36,
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          icon: const Icon(
                            Icons.edit,
                            color: Colors.white,
                            size: 18,
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => EditProfileScreen(
                                  accessToken: widget.accessToken,
                                  profileData: widget.adminInfo,
                                  isAdmin: true,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // SECTION 2: SECURITY & AUDITS
                const AppSectionHeader(
                  title: 'Security & Access',
                  tagline: 'SECURITY',
                ),
                const SizedBox(height: 8),
                AppCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      Material(
                        color: Colors.transparent,
                        child: SwitchListTile(
                          secondary: Icon(
                            Icons.dialpad,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          title: const Text(
                            '4-Digit MPIN',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          subtitle: Text(
                            _hasAppPin ? 'MPIN Enabled' : 'Disabled',
                            style: TextStyle(
                              fontSize: 11,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                          ),
                          value: _hasAppPin,
                          activeThumbColor: Theme.of(context)
                              .colorScheme
                              .primary,
                          onChanged: (_) => _handlePinTileTap(),
                        ),
                      ),
                      const Divider(height: 1, indent: 16, endIndent: 16),
                      Material(
                        color: Colors.transparent,
                        child: ListTile(
                          leading: Icon(
                            Icons.key_outlined,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          title: const Text(
                            'Change My Password',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          trailing: Icon(
                            Icons.chevron_right,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                          onTap: _showChangeOwnPasswordDialog,
                        ),
                      ),
                      const Divider(height: 1, indent: 16, endIndent: 16),
                      Material(
                        color: Colors.transparent,
                        child: ListTile(
                          leading: Icon(
                            Icons.security_outlined,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          title: const Text(
                            'System Audit Logs',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          subtitle: Text(
                            'Inspect administrator actions history',
                            style: TextStyle(
                              fontSize: 11,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                          ),
                          trailing: Icon(
                            Icons.chevron_right,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => AdminAuditLogsScreen(
                                  accessToken: widget.accessToken,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const Divider(height: 1, indent: 16, endIndent: 16),
                      Material(
                        color: Colors.transparent,
                        child: ListTile(
                          leading: Icon(
                            Icons.support_agent_outlined,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          title: const Text(
                            'User Support Tickets',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          subtitle: Text(
                            'Moderate & chat in user support tickets',
                            style: TextStyle(
                              fontSize: 11,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                          ),
                          trailing: Icon(
                            Icons.chevron_right,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => AdminReportsScreen(
                                  accessToken: widget.accessToken,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // SECTION 3: APP PREFERENCES
                const AppSectionHeader(
                  title: 'App Preferences',
                  tagline: 'PREFERENCES',
                ),
                const SizedBox(height: 8),
                AppCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      Material(
                        color: Colors.transparent,
                        child: ListTile(
                          leading: Icon(
                            Icons.timer_outlined,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          title: const Text(
                            'Toast Display Duration',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          subtitle: Text(
                            '$_toastDuration seconds on screen',
                            style: TextStyle(
                              fontSize: 11,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                          ),
                          trailing: Icon(
                            Icons.chevron_right,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                          onTap: _showToastDurationDialog,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // SECTION 4: SYSTEM STATUS & BUILD INFO
                const AppSectionHeader(title: 'System Info', tagline: 'CORE'),
                const SizedBox(height: 8),
                AppCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Backend API Base URL',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          AppBadge(
                            label: 'CONNECTED',
                            type: AppBadgeType.success,
                            isSmall: true,
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        AppConfig.baseUrl,
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Divider(),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'BondVault PK Version',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          Text(
                            'v1.0.0+1 (Build 2026.11)',
                            style: TextStyle(
                              fontSize: 11,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // LOGOUT BUTTON
                AppButton(
                  label: 'Logout Administrator Account',
                  variant: AppButtonVariant.danger,
                  icon: const Icon(Icons.logout, size: 18),
                  onPressed: widget.onLogout,
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
