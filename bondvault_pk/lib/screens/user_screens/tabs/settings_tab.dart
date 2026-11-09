import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../config/app_theme.dart';
import '../../../widgets/widgets.dart';

class SettingsTab extends StatefulWidget {
  final String email;
  final String fullName;
  final VoidCallback onLogout;
  final VoidCallback onAbout;

  const SettingsTab({
    super.key,
    required this.email,
    required this.fullName,
    required this.onLogout,
    required this.onAbout,
  });

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  bool _hasAppPin = false;
  String _selectedLanguage = 'English';
  int _toastDuration = 3;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final pin = prefs.getString('app_pin');
    final lang = prefs.getString('app_language') ?? 'English';
    final duration = prefs.getInt('toast_duration_seconds') ?? 3;
    if (mounted) {
      setState(() {
        _hasAppPin = pin != null && pin.isNotEmpty;
        _selectedLanguage = lang;
        _toastDuration = duration;
      });
    }
  }

  Future<void> _showLanguageDialog() async {
    final lang = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Select Language'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'English'),
            child: const Text('English'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'Urdu (اردو)'),
            child: const Text('Urdu (اردو)'),
          ),
        ],
      ),
    );

    if (lang != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('app_language', lang);
      setState(() {
        _selectedLanguage = lang;
      });
      if (!mounted) return;
      showAppToast(
        context,
        'Language set to $lang',
        type: AppNotificationType.success,
      );
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
      setState(() {
        _toastDuration = selected;
      });
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
          title: Text(isEdit ? 'Edit 4-Digit MPIN' : 'Set 4-Digit MPIN'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isEdit
                      ? 'Enter your new 4-digit application MPIN.'
                      : 'Secure your app with a 4-digit application MPIN.',
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
                  if (!context.mounted) return;
                  showAppToast(
                    context,
                    isEdit
                        ? 'MPIN updated successfully.'
                        : 'MPIN set successfully.',
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
        title: const Text('Remove MPIN Security'),
        content: const Text(
          'Are you sure you want to disable MPIN protection?',
        ),
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
        'MPIN protection disabled.',
        type: AppNotificationType.warning,
      );
    }
  }

  void _showChangePasswordDialog() {
    final oldPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Change Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppTextField(
              controller: oldPasswordController,
              obscureText: true,
              labelText: 'Current Password',
            ),
            const SizedBox(height: 12),
            AppTextField(
              controller: newPasswordController,
              obscureText: true,
              labelText: 'New Password',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          AppButton(
            label: 'Update',
            fullWidth: false,
            onPressed: () {
              Navigator.pop(dialogContext);
              showAppToast(
                context,
                'Password changed successfully.',
                type: AppNotificationType.success,
              );
            },
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog() {
    showAppNotificationSheet(
      context: context,
      title: 'Delete Account',
      message: 'Are you sure you want to permanently close your account? All saved bond series and data will be removed.',
      type: AppNotificationType.error,
      dismissLabel: 'Cancel',
      customAction: AppButton(
        label: 'Permanently Delete',
        variant: AppButtonVariant.danger,
        onPressed: () {
          Navigator.pop(context);
          widget.onLogout();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Settings',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color:
                Theme.of(context).appBarTheme.foregroundColor ??
                Theme.of(context).colorScheme.onSurface,
          ),
        ),
        backgroundColor:
            Theme.of(context).appBarTheme.backgroundColor ??
            Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Section 1: PROFILE
          const AppSectionHeader(title: 'Profile Settings', tagline: 'PROFILE'),
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
                            widget.fullName,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(width: 8),
                          AppBadge.verified(),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '@${widget.fullName.toLowerCase().replaceAll(' ', '_')}',
                        style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                            widget.email,
                            style: TextStyle(
                              fontSize: 13,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            Icons.phone_outlined,
                            size: 16,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '+92 300 1234567',
                            style: TextStyle(
                              fontSize: 13,
                              color: Theme.of(context).colorScheme.onSurface,
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
                    icon: const Icon(Icons.edit, color: Colors.white, size: 18),
                    onPressed: () {
                      showAppToast(
                        context,
                        'Profile edit mode',
                        type: AppNotificationType.info,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Section 2: SECURITY & ENCRYPTION
          const AppSectionHeader(
            title: 'Security & Encryption',
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
                      '4-Digit MPIN Security',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    value: _hasAppPin,
                    activeThumbColor: Theme.of(context).colorScheme.primary,
                    onChanged: (val) async {
                      if (val) {
                        await _showPinDialog(isEdit: false);
                      } else {
                        await _removePin();
                      }
                    },
                  ),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                Material(
                  color: Colors.transparent,
                  child: ListTile(
                    leading: Icon(
                      Icons.history,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    title: const Text(
                      'Change Password',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    trailing: Icon(
                      Icons.chevron_right,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    onTap: _showChangePasswordDialog,
                  ),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                Material(
                  color: Colors.transparent,
                  child: ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.red.shade900.withValues(alpha: 0.2)
                            : Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.delete_outline,
                        color: Colors.red,
                        size: 20,
                      ),
                    ),
                    title: const Text(
                      'Delete Account',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Colors.red,
                      ),
                    ),
                    subtitle: Text(
                      'Permanently close account',
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    trailing: Icon(
                      Icons.chevron_right,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    onTap: _showDeleteAccountDialog,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Section 3: PREFERENCES & NOTIFICATIONS
          const AppSectionHeader(
            title: 'App Preferences',
            tagline: 'PREFERENCES',
          ),
          const SizedBox(height: 8),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                ValueListenableBuilder<ThemeMode>(
                  valueListenable: themeModeNotifier,
                  builder: (context, themeMode, _) => Material(
                    color: Colors.transparent,
                    child: SwitchListTile(
                      secondary: Icon(
                        Icons.palette_outlined,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      title: const Text(
                        'App Theme',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      subtitle: Text(
                        themeMode == ThemeMode.dark
                            ? 'Dark Mode'
                            : 'Light Mode',
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      value: themeMode == ThemeMode.dark,
                      activeThumbColor: Theme.of(context).colorScheme.primary,
                      onChanged: (val) async {
                        final newMode = val ? ThemeMode.dark : ThemeMode.light;
                        themeModeNotifier.value = newMode;
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setString(
                          'app_theme_mode',
                          val ? 'dark' : 'light',
                        );
                      },
                    ),
                  ),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
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
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    trailing: Icon(
                      Icons.chevron_right,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    onTap: _showToastDurationDialog,
                  ),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                Material(
                  color: Colors.transparent,
                  child: ListTile(
                    leading: Icon(
                      Icons.translate,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    title: const Text(
                      'Language',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    subtitle: Text(
                      _selectedLanguage,
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    trailing: Icon(
                      Icons.chevron_right,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    onTap: _showLanguageDialog,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Logout Button
          AppButton(
            label: 'Logout Account',
            variant: AppButtonVariant.danger,
            icon: const Icon(Icons.logout, size: 18),
            onPressed: widget.onLogout,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
