import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../config/app_config.dart';
import '../../config/app_theme.dart';
import '../../config/responsive.dart';
import '../../widgets/widgets.dart';

class AdminManagementScreen extends StatefulWidget {
  final String accessToken;
  final Map<String, dynamic> adminInfo;

  const AdminManagementScreen({
    super.key,
    required this.accessToken,
    required this.adminInfo,
  });

  @override
  State<AdminManagementScreen> createState() => _AdminManagementScreenState();
}

class _AdminManagementScreenState extends State<AdminManagementScreen> {
  bool _isLoading = true;
  List<dynamic> _adminAccounts = [];
  String _selectedRoleFilter = 'All';
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String? _loadingAdminId;

  String get _currentRole {
    final username = (widget.adminInfo['username'] ?? '')
        .toString()
        .toLowerCase();
    final role = (widget.adminInfo['role'] ?? '').toString().toLowerCase();
    final isSuper = widget.adminInfo['is_superuser'] == true;

    if (role == 'owner' || username == 'owner') return 'owner';
    if (isSuper || role == 'superuser') return 'superuser';
    return 'admin';
  }

  String _parseErrorMessage(
    dynamic data, [
    String fallback = 'Operation failed.',
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
          return field.isNotEmpty ? '$field: $msg' : msg;
        }
        return detail[0].toString();
      }
      if (data.containsKey('message')) return data['message'].toString();
    }
    return data.toString();
  }

  @override
  void initState() {
    super.initState();
    _fetchAdminAccounts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchAdminAccounts() async {
    setState(() => _isLoading = true);
    try {
      final res = await http.get(
        Uri.parse('${AppConfig.baseUrl}/admins/accounts/all'),
        headers: {'Authorization': 'Bearer ${widget.accessToken}'},
      );

      if (res.statusCode == 200 && mounted) {
        final data = jsonDecode(res.body);
        if (data is List) {
          setState(() => _adminAccounts = data);
        }
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showInviteDialog() async {
    final usernameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final firstNameCtrl = TextEditingController();
    final lastNameCtrl = TextEditingController();
    String selectedRole = 'admin';
    final formKey = GlobalKey<FormState>();
    bool isSubmitting = false;

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
                        colors: [Color(0xFF0F5132), Color(0xFF022C22)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.person_add_alt_1_outlined,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text(
                                'Create Administrator',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Create account & email generated credentials',
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
                          const Text(
                            'ADMIN ROLE & PRIVILEGES',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: ChoiceChip(
                                  label: const Center(
                                    child: Text('NORMAL ADMIN'),
                                  ),
                                  selected: selectedRole == 'admin',
                                  selectedColor: AppColors.primary,
                                  labelStyle: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: selectedRole == 'admin'
                                        ? Colors.white
                                        : AppColors.onSurface,
                                  ),
                                  onSelected: (s) {
                                    if (s) {
                                      setDialogState(
                                        () => selectedRole = 'admin',
                                      );
                                    }
                                  },
                                ),
                              ),
                              if (_currentRole == 'owner') ...[
                                const SizedBox(width: 6),
                                Expanded(
                                  child: ChoiceChip(
                                    label: const Center(
                                      child: Text('SUPERUSER'),
                                    ),
                                    selected: selectedRole == 'superuser',
                                    selectedColor: AppColors.secondary,
                                    labelStyle: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: selectedRole == 'superuser'
                                          ? Colors.white
                                          : AppColors.onSurface,
                                    ),
                                    onSelected: (s) {
                                      if (s) {
                                        setDialogState(
                                          () => selectedRole = 'superuser',
                                        );
                                      }
                                    },
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 16),
                          AppTextField(
                            controller: usernameCtrl,
                            labelText: 'Username',
                            prefixIcon: const Icon(Icons.person_outline),
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Username is required'
                                : null,
                          ),
                          const SizedBox(height: 12),
                          AppTextField(
                            controller: emailCtrl,
                            keyboardType: TextInputType.emailAddress,
                            labelText: 'Email Address',
                            prefixIcon: const Icon(Icons.email_outlined),
                            validator: (v) => (v == null || !v.contains('@'))
                                ? 'Valid email required'
                                : null,
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: AppTextField(
                                  controller: firstNameCtrl,
                                  labelText: 'First Name',
                                  prefixIcon: const Icon(Icons.badge_outlined),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: AppTextField(
                                  controller: lastNameCtrl,
                                  labelText: 'Last Name',
                                  prefixIcon: const Icon(Icons.badge_outlined),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          AppButton(
                            label: 'Send Email Credentials',
                            isLoading: isSubmitting,
                            icon: const Icon(Icons.send, size: 18),
                            onPressed: () async {
                              if (formKey.currentState!.validate()) {
                                setDialogState(() => isSubmitting = true);
                                try {
                                  final res = await http.post(
                                    Uri.parse(
                                      '${AppConfig.baseUrl}/admins/accounts/invite',
                                    ),
                                    headers: {
                                      'Authorization':
                                          'Bearer ${widget.accessToken}',
                                      'Content-Type': 'application/json',
                                    },
                                    body: jsonEncode({
                                      'username': usernameCtrl.text.trim(),
                                      'email': emailCtrl.text.trim(),
                                      'first_name': firstNameCtrl.text.trim(),
                                      'last_name': lastNameCtrl.text.trim(),
                                      'role': selectedRole,
                                    }),
                                  );

                                  if (res.statusCode == 201 ||
                                      res.statusCode == 200) {
                                    _fetchAdminAccounts();
                                    if (dialogContext.mounted) {
                                      Navigator.pop(dialogContext);
                                    }
                                    if (mounted) {
                                      showAppNotificationSheet(
                                        context: this.context,
                                        title: 'Administrator Invited',
                                        message:
                                            'Account created! Credentials emailed to ${emailCtrl.text.trim()}.',
                                        type: AppNotificationType.success,
                                      );
                                    }
                                  } else {
                                    final data = jsonDecode(res.body);
                                    if (dialogContext.mounted) {
                                      setDialogState(
                                        () => isSubmitting = false,
                                      );
                                      showAppToast(
                                        dialogContext,
                                        _parseErrorMessage(
                                          data,
                                          'Invitation failed.',
                                        ),
                                        type: AppNotificationType.error,
                                      );
                                    }
                                  }
                                } catch (e) {
                                  if (dialogContext.mounted) {
                                    setDialogState(() => isSubmitting = false);
                                    showAppToast(
                                      dialogContext,
                                      'Error: $e',
                                      type: AppNotificationType.error,
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

    Future.delayed(const Duration(milliseconds: 500), () {
      usernameCtrl.dispose();
      emailCtrl.dispose();
      firstNameCtrl.dispose();
      lastNameCtrl.dispose();
    });
  }

  Future<void> _showChangePasswordDialog(Map<String, dynamic> adminItem) async {
    final username = adminItem['username'] ?? 'admin';
    final email = adminItem['email'] ?? 'admin@bondvault.pk';

    showAppNotificationSheet(
      context: context,
      title: 'Reset Admin Password',
      message:
          'Generate a new random secure password and email it directly to @$username ($email)?\n\nActive sessions for this account will be revoked.',
      type: AppNotificationType.warning,
      dismissLabel: 'Cancel',
      customAction: AppButton(
        label: 'Generate & Email Password',
        variant: AppButtonVariant.secondary,
        icon: const Icon(Icons.key, size: 18),
        onPressed: () async {
          Navigator.pop(context);
          final adminId = adminItem['id']?.toString() ?? '';
          setState(() => _loadingAdminId = adminId);
          try {
            final res = await http.patch(
              Uri.parse(
                '${AppConfig.baseUrl}/admins/accounts/$adminId/password',
              ),
              headers: {
                'Authorization': 'Bearer ${widget.accessToken}',
                'Content-Type': 'application/json',
              },
            );

            if (res.statusCode == 200) {
              final data = jsonDecode(res.body);
              if (!mounted) return;
              showAppNotificationSheet(
                context: context,
                title: 'New Password Emailed',
                message:
                    data['message'] ??
                    'A new random password was generated and emailed to @$username.',
                type: AppNotificationType.success,
              );
            } else {
              final data = jsonDecode(res.body);
              if (!mounted) return;
              showAppToast(
                context,
                data['detail'] ?? 'Failed to reset password.',
                type: AppNotificationType.error,
              );
            }
          } catch (e) {
            if (!mounted) return;
            showAppToast(context, 'Error: $e', type: AppNotificationType.error);
          } finally {
            if (mounted) setState(() => _loadingAdminId = null);
          }
        },
      ),
    );
  }

  Future<void> _deleteAdminAccount(String adminId, String username) async {
    showAppNotificationSheet(
      context: context,
      title: 'Remove Administrator Account',
      message:
          'Are you sure you want to remove administrator account @$username?',
      type: AppNotificationType.error,
      dismissLabel: 'Cancel',
      customAction: AppButton(
        label: 'Confirm Remove',
        variant: AppButtonVariant.danger,
        onPressed: () async {
          Navigator.pop(context);
          setState(() => _loadingAdminId = adminId);
          try {
            final res = await http.delete(
              Uri.parse('${AppConfig.baseUrl}/admins/$adminId'),
              headers: {'Authorization': 'Bearer ${widget.accessToken}'},
            );

            if (res.statusCode == 200) {
              _fetchAdminAccounts();
              if (!mounted) return;
              showAppNotificationSheet(
                context: context,
                title: 'Administrator Removed',
                message:
                    'Account @$username has been deleted and notified via email.',
                type: AppNotificationType.success,
              );
            } else {
              final data = jsonDecode(res.body);
              if (!mounted) return;
              showAppToast(
                context,
                data['detail'] ?? 'Failed to delete administrator.',
                type: AppNotificationType.error,
              );
            }
          } catch (_) {
          } finally {
            if (mounted) setState(() => _loadingAdminId = null);
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _adminAccounts.where((item) {
      final username = (item['username'] ?? '').toString().toLowerCase();
      final email = (item['email'] ?? '').toString().toLowerCase();
      final role = (item['role'] ?? '').toString().toLowerCase();

      bool matchesRole =
          _selectedRoleFilter == 'All' ||
          (_selectedRoleFilter == 'Owners' && role == 'owner') ||
          (_selectedRoleFilter == 'Superusers' &&
              (role == 'superuser' || item['is_superuser'] == true)) ||
          (_selectedRoleFilter == 'Admins' &&
              role == 'admin' &&
              item['is_superuser'] != true);

      bool matchesSearch =
          _searchQuery.isEmpty ||
          username.contains(_searchQuery.toLowerCase()) ||
          email.contains(_searchQuery.toLowerCase());

      return matchesRole && matchesSearch;
    }).toList();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'Administrator Management',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const AppLoadingIndicator(
              message: 'Loading administrator accounts...',
            )
          : RefreshIndicator(
              onRefresh: _fetchAdminAccounts,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.symmetric(
                  horizontal: Responsive.w(context, 16),
                  vertical: Responsive.h(context, 12),
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: Responsive.maxContentWidth(context),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppSectionHeader(
                          title: 'Admin Accounts',
                          tagline: 'TOTAL: ${_adminAccounts.length}',
                        ),
                        const SizedBox(height: 8),

                        AppTextField(
                          controller: _searchController,
                          labelText: 'Search Admins',
                          hintText: 'e.g. username or email',
                          prefixIcon: const Icon(Icons.search),
                          onChanged: (v) => setState(() => _searchQuery = v),
                        ),
                        const SizedBox(height: 12),

                        Wrap(
                          spacing: 8,
                          children: [
                            _buildRoleFilterChip('All'),
                            _buildRoleFilterChip('Owners'),
                            _buildRoleFilterChip('Superusers'),
                            _buildRoleFilterChip('Admins'),
                          ],
                        ),
                        const SizedBox(height: 16),

                        filtered.isEmpty
                            ? const AppEmptyState(
                                icon: Icons.admin_panel_settings_outlined,
                                title: 'No Admin Accounts Found',
                                message: 'No administrator accounts match your selected filter.',
                              )
                            : ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: filtered.length,
                                itemBuilder: (context, index) {
                                  final item = filtered[index];
                                  final username =
                                      item['username']?.toString() ?? 'Admin';
                                  final email =
                                      item['email']?.toString() ?? 'N/A';
                                  final role =
                                      (item['role']?.toString() ?? 'admin')
                                          .toLowerCase();
                                  final isSuper = item['is_superuser'] == true;
                                  final adminId = item['id']?.toString() ?? '';

                                  String displayRole = 'ADMIN';
                                  AppBadgeType badgeType = AppBadgeType.success;
                                  if (role == 'owner' || username == 'owner') {
                                    displayRole = 'SYSTEM OWNER';
                                    badgeType = AppBadgeType.warning;
                                  } else if (isSuper || role == 'superuser') {
                                    displayRole = 'SUPERUSER';
                                    badgeType = AppBadgeType.info;
                                  }

                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: AppCard(
                                      padding: const EdgeInsets.all(16),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              CircleAvatar(
                                                backgroundColor:
                                                    AppColors.primary,
                                                child: Text(
                                                  username.isNotEmpty
                                                      ? username[0]
                                                            .toUpperCase()
                                                      : 'A',
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Row(
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .spaceBetween,
                                                      children: [
                                                        Text(
                                                          '@$username',
                                                          style: TextStyle(
                                                            fontSize: 15,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            color:
                                                                Theme.of(
                                                                      context,
                                                                    )
                                                                    .colorScheme
                                                                    .onSurface,
                                                          ),
                                                        ),
                                                        AppBadge(
                                                          label: displayRole,
                                                          type: badgeType,
                                                          isSmall: true,
                                                        ),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 2),
                                                    Text(
                                                      email,
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        color: Theme.of(context)
                                                            .colorScheme
                                                            .onSurfaceVariant,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 14),
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.end,
                                            children: [
                                              SizedBox(
                                                height: 34,
                                                child: OutlinedButton.icon(
                                                  onPressed: () =>
                                                      _showChangePasswordDialog(
                                                        item,
                                                      ),
                                                  icon: const Icon(
                                                    Icons.key,
                                                    size: 14,
                                                  ),
                                                  label: const Text(
                                                    'Change Password',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              SizedBox(
                                                height: 34,
                                                child: IconButton(
                                                  icon:
                                                      _loadingAdminId == adminId
                                                      ? const SizedBox(
                                                          width: 16,
                                                          height: 16,
                                                          child:
                                                              CircularProgressIndicator(
                                                                strokeWidth: 2,
                                                              ),
                                                        )
                                                      : const Icon(
                                                          Icons.delete_outline,
                                                          color: Colors.red,
                                                          size: 20,
                                                        ),
                                                  onPressed: () =>
                                                      _deleteAdminAccount(
                                                        adminId,
                                                        username,
                                                      ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        onPressed: _showInviteDialog,
        icon: const Icon(Icons.person_add),
        label: const Text('Invite Admin'),
      ),
    );
  }

  Widget _buildRoleFilterChip(String label) {
    final isSelected = _selectedRoleFilter == label;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: AppColors.primary,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : AppColors.onSurface,
        fontWeight: FontWeight.bold,
      ),
      onSelected: (s) {
        if (s) setState(() => _selectedRoleFilter = label);
      },
    );
  }
}
