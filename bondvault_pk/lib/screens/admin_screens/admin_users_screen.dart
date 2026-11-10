import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../config/app_config.dart';
import '../../config/app_theme.dart';
import '../../config/responsive.dart';
import '../../widgets/widgets.dart';

class AdminUsersScreen extends StatefulWidget {
  final String accessToken;
  final List<dynamic> usersList;
  final VoidCallback onDataChanged;

  const AdminUsersScreen({
    super.key,
    required this.accessToken,
    required this.usersList,
    required this.onDataChanged,
  });

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  String _selectedFilter = 'All';
  final _searchController = TextEditingController();
  String _searchQuery = '';

  String? _loadingUserId;
  String? _loadingAction;

  Future<void> _approveUser(String userId) async {
    setState(() {
      _loadingUserId = userId;
      _loadingAction = 'approve';
    });

    try {
      final res = await http.post(
        Uri.parse('${AppConfig.baseUrl}/admins/users/$userId/approve'),
        headers: {'Authorization': 'Bearer ${widget.accessToken}'},
      );
      if (!mounted) return;
      if (res.statusCode == 200) {
        showAppNotificationSheet(
          context: context,
          title: 'User Verified',
          message: 'User account has been verified successfully.',
          type: AppNotificationType.success,
        );
        widget.onDataChanged();
      } else {
        final data = jsonDecode(res.body);
        showAppNotificationSheet(
          context: context,
          title: 'Approval Failed',
          message: data['detail'] ?? 'Failed to approve user.',
          type: AppNotificationType.error,
        );
      }
    } catch (_) {
      if (!mounted) return;
      showAppNotificationSheet(
        context: context,
        title: 'Connection Error',
        message: 'Could not connect to server to approve user.',
        type: AppNotificationType.error,
      );
    } finally {
      if (mounted) {
        setState(() {
          _loadingUserId = null;
          _loadingAction = null;
        });
      }
    }
  }

  Future<void> _blacklistUser(
    String userId,
    DateTime? durationUntil, [
    String? reason,
  ]) async {
    setState(() {
      _loadingUserId = userId;
      _loadingAction = 'ban';
    });

    try {
      final body = <String, dynamic>{};
      if (durationUntil != null) {
        body['duration_until'] = durationUntil.toUtc().toIso8601String();
      }
      if (reason != null && reason.trim().isNotEmpty) {
        body['reason'] = reason.trim();
      }
      final res = await http.post(
        Uri.parse('${AppConfig.baseUrl}/admins/users/$userId/blacklist'),
        headers: {
          'Authorization': 'Bearer ${widget.accessToken}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );
      if (!mounted) return;
      if (res.statusCode == 200) {
        showAppNotificationSheet(
          context: context,
          title: 'User Blacklisted',
          message: 'User account has been blacklisted and access suspended.',
          type: AppNotificationType.warning,
        );
        widget.onDataChanged();
      } else {
        final data = jsonDecode(res.body);
        showAppNotificationSheet(
          context: context,
          title: 'Blacklist Failed',
          message: data['detail'] ?? 'Failed to blacklist user.',
          type: AppNotificationType.error,
        );
      }
    } catch (_) {
      if (!mounted) return;
      showAppNotificationSheet(
        context: context,
        title: 'Connection Error',
        message: 'Could not connect to server to blacklist user.',
        type: AppNotificationType.error,
      );
    } finally {
      if (mounted) {
        setState(() {
          _loadingUserId = null;
          _loadingAction = null;
        });
      }
    }
  }

  Future<void> _unblacklistUser(String userId) async {
    setState(() {
      _loadingUserId = userId;
      _loadingAction = 'unban';
    });

    try {
      final res = await http.delete(
        Uri.parse('${AppConfig.baseUrl}/admins/users/$userId/blacklist'),
        headers: {'Authorization': 'Bearer ${widget.accessToken}'},
      );
      if (!mounted) return;
      if (res.statusCode == 200) {
        showAppNotificationSheet(
          context: context,
          title: 'User Unbanned',
          message: 'User removed from blacklist and account restored.',
          type: AppNotificationType.success,
        );
        widget.onDataChanged();
      } else {
        final data = jsonDecode(res.body);
        showAppNotificationSheet(
          context: context,
          title: 'Action Failed',
          message: data['detail'] ?? 'Failed to unblacklist user.',
          type: AppNotificationType.error,
        );
      }
    } catch (_) {
      if (!mounted) return;
      showAppNotificationSheet(
        context: context,
        title: 'Connection Error',
        message: 'Could not connect to server to unblacklist user.',
        type: AppNotificationType.error,
      );
    } finally {
      if (mounted) {
        setState(() {
          _loadingUserId = null;
          _loadingAction = null;
        });
      }
    }
  }

  Future<void> _deleteUser(String userId) async {
    showAppNotificationSheet(
      context: context,
      title: 'Delete User Account',
      message: 'Are you sure you want to permanently delete this user account? This action cannot be undone.',
      type: AppNotificationType.error,
      dismissLabel: 'Cancel',
      customAction: AppButton(
        label: 'Permanently Delete',
        variant: AppButtonVariant.danger,
        isLoading: _loadingUserId == userId && _loadingAction == 'delete',
        onPressed: () async {
          Navigator.pop(context);
          setState(() {
            _loadingUserId = userId;
            _loadingAction = 'delete';
          });
          try {
            final res = await http.delete(
              Uri.parse('${AppConfig.baseUrl}/admins/users/$userId'),
              headers: {'Authorization': 'Bearer ${widget.accessToken}'},
            );
            if (!mounted) return;
            if (res.statusCode == 200) {
              showAppNotificationSheet(
                context: context,
                title: 'User Deleted',
                message: 'User account has been permanently deleted.',
                type: AppNotificationType.success,
              );
              widget.onDataChanged();
            } else {
              final data = jsonDecode(res.body);
              showAppNotificationSheet(
                context: context,
                title: 'Delete Failed',
                message: data['detail'] ?? 'Failed to delete user.',
                type: AppNotificationType.error,
              );
            }
          } catch (_) {
            if (!mounted) return;
            showAppNotificationSheet(
              context: context,
              title: 'Connection Error',
              message: 'Could not connect to server to delete user.',
              type: AppNotificationType.error,
            );
          } finally {
            if (mounted) {
              setState(() {
                _loadingUserId = null;
                _loadingAction = null;
              });
            }
          }
        },
      ),
    );
  }

  void _showBlacklistDialog(BuildContext context, String userId) {
    String selectedPeriod = 'permanent ban';
    final reasonController = TextEditingController();
    final periods = [
      '1 day',
      '3 day',
      '7 day',
      '15 day',
      '1 month',
      'permanent ban',
    ];

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setStateDialog) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          clipBehavior: Clip.antiAlias,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: Responsive.maxContentWidth(context),
              maxHeight: MediaQuery.sizeOf(context).height * 0.85,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header Banner
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 18,
                  ),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF991B1B), Color(0xFF7F1D1D)],
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
                          Icons.block,
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
                              'Suspend User Account',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Select suspension duration and specify reason',
                              style: TextStyle(
                                fontSize: 11,
                                color: Color(0xFFFECACA),
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

                // Body wrapped in Flexible to scroll when keyboard opens
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'SUSPENSION DURATION',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: periods.map((period) {
                            final isSelected = selectedPeriod == period;
                            return ChoiceChip(
                              label: Text(
                                period.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected
                                      ? Colors.white
                                      : AppColors.onSurface,
                                ),
                              ),
                              selected: isSelected,
                              selectedColor: AppColors.error,
                              backgroundColor: AppColors.surfaceContainerLow,
                              onSelected: (sel) {
                                if (sel) {
                                  setStateDialog(() => selectedPeriod = period);
                                }
                              },
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 18),
                        const Text(
                          'REASON FOR SUSPENSION',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 6),
                        AppTextField(
                          controller: reasonController,
                          maxLines: 2,
                          labelText: 'Reason for suspension (optional)',
                          hintText: 'e.g. Flagged for policy violation',
                          prefixIcon: const Icon(Icons.description_outlined),
                        ),
                        const SizedBox(height: 24),
                        AppButton(
                          label: 'Confirm Account Suspension',
                          variant: AppButtonVariant.danger,
                          isLoading:
                              _loadingUserId == userId &&
                              _loadingAction == 'ban',
                          icon: const Icon(Icons.lock_outline, size: 18),
                          onPressed: () {
                            Navigator.pop(dialogContext);
                            DateTime? durationUntil;
                            final now = DateTime.now();
                            if (selectedPeriod == '1 day') {
                              durationUntil = now.add(const Duration(days: 1));
                            } else if (selectedPeriod == '3 day') {
                              durationUntil = now.add(const Duration(days: 3));
                            } else if (selectedPeriod == '7 day') {
                              durationUntil = now.add(const Duration(days: 7));
                            } else if (selectedPeriod == '15 day') {
                              durationUntil = now.add(const Duration(days: 15));
                            } else if (selectedPeriod == '1 month') {
                              durationUntil = now.add(const Duration(days: 30));
                            } else {
                              durationUntil = null;
                            }
                            final reason = reasonController.text.trim();
                            _blacklistUser(
                              userId,
                              durationUntil,
                              reason.isNotEmpty ? reason : null,
                            );
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
    );
  }

  void _showUserDetailsDialog(Map<String, dynamic> user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(user['username'] ?? 'User Details'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _detailRow('ID', user['id'] ?? 'N/A'),
              _detailRow('Username', user['username'] ?? 'N/A'),
              _detailRow('Email', user['email'] ?? 'N/A'),
              _detailRow('First Name', user['first_name'] ?? 'N/A'),
              _detailRow('Last Name', user['last_name'] ?? 'N/A'),
              _detailRow('Contact', user['contact'] ?? 'N/A'),
              _detailRow('City', user['city'] ?? 'N/A'),
              _detailRow('Address', user['address'] ?? 'N/A'),
              _detailRow(
                'Verified',
                user['is_verified'] == true ? 'Yes' : 'No',
              ),
              _detailRow(
                'Blacklisted',
                user['is_blacklisted'] == true ? 'Yes' : 'No',
              ),
              _detailRow('Created At', user['created_at'] ?? 'N/A'),
              _detailRow('Last Login', user['last_login'] ?? 'Never'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    } else if (parts.isNotEmpty && parts[0].isNotEmpty) {
      return parts[0].substring(0, parts[0].length >= 2 ? 2 : 1).toUpperCase();
    }
    return 'US';
  }

  @override
  Widget build(BuildContext context) {
    final pendingCount = widget.usersList
        .where((u) => u['is_verified'] != true && u['is_blacklisted'] != true)
        .length;
    final verifiedCount = widget.usersList
        .where((u) => u['is_verified'] == true)
        .length;

    final filteredUsers = widget.usersList.where((user) {
      final isVerified = user['is_verified'] == true;
      final isBlacklisted = user['is_blacklisted'] == true;
      final username = (user['username'] ?? '').toString().toLowerCase();
      final email = (user['email'] ?? '').toString().toLowerCase();
      final contact = (user['contact'] ?? '').toString().toLowerCase();

      bool matchesFilter = true;
      if (_selectedFilter == 'Pending') {
        matchesFilter = !isVerified && !isBlacklisted;
      } else if (_selectedFilter == 'Verified') {
        matchesFilter = isVerified;
      } else if (_selectedFilter == 'Suspended') {
        matchesFilter = isBlacklisted;
      }

      bool matchesSearch =
          _searchQuery.isEmpty ||
          username.contains(_searchQuery.toLowerCase()) ||
          email.contains(_searchQuery.toLowerCase()) ||
          contact.contains(_searchQuery.toLowerCase());

      return matchesFilter && matchesSearch;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFF),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search Bar & Filter Button
            Row(
              children: [
                Expanded(
                  child: AppTextField(
                    controller: _searchController,
                    hintText: 'Search by Name, Email or Contact...',
                    prefixIcon: const Icon(Icons.search, color: Colors.grey),
                    onChanged: (val) => setState(() => _searchQuery = val),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: const Icon(
                    Icons.tune,
                    color: AppColors.onSurface,
                    size: 20,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Filter Chips (Wrap methodology #6)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildFilterChip('All', null),
                _buildFilterChip(
                  'Pending',
                  '$pendingCount',
                  badgeColor: AppColors.secondary,
                  badgeBg: const Color(0xFFFFEDD5),
                ),
                _buildFilterChip(
                  'Verified',
                  formatNumberStatic(verifiedCount),
                  badgeColor: AppColors.primary,
                  badgeBg: const Color(0xFFA7F3D0),
                ),
                _buildFilterChip('Suspended', null),
              ],
            ),
            const SizedBox(height: 16),

            // Users List
            Expanded(
              child: filteredUsers.isEmpty
                  ? const AppEmptyState(
                      icon: Icons.people_outline,
                      title: 'No Users Found',
                      message: 'No registered user accounts match your selected filter or search query.',
                    )
                  : ListView.builder(
                      itemCount: filteredUsers.length,
                      itemBuilder: (context, index) {
                        final user = filteredUsers[index];
                        final isVerified = user['is_verified'] == true;
                        final isBlacklisted = user['is_blacklisted'] == true;
                        final name =
                            '${user['first_name'] ?? ''} ${user['last_name'] ?? ''}'
                                .trim();
                        final displayName = name.isEmpty
                            ? (user['username'] ?? 'User')
                            : name;
                        final initials = _getInitials(displayName);
                        final email = user['email'] ?? 'No email';
                        final contact = user['contact'] ?? '+92 300 1234567';
                        final createdAt =
                            user['created_at']?.toString().split('T')[0] ??
                            '12 Oct 2023';
                        final userId = user['id']?.toString() ?? '';

                        final isApproving =
                            _loadingUserId == userId &&
                            _loadingAction == 'approve';
                        final isBanning =
                            _loadingUserId == userId &&
                            (_loadingAction == 'ban' ||
                                _loadingAction == 'unban');
                        final isDeleting =
                            _loadingUserId == userId &&
                            _loadingAction == 'delete';

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: AppCard(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Card Header
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          width: 44,
                                          height: 44,
                                          decoration: BoxDecoration(
                                            color: isVerified
                                                ? const Color(0xFFA7F3D0)
                                                : const Color(0xFFFFEDD5),
                                            borderRadius: BorderRadius.circular(
                                              14,
                                            ),
                                          ),
                                          alignment: Alignment.center,
                                          child: Text(
                                            initials,
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w900,
                                              color: isVerified
                                                  ? const Color(0xFF065F46)
                                                  : AppColors.secondary,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            InkWell(
                                              onTap: () =>
                                                  _showUserDetailsDialog(
                                                    Map<String, dynamic>.from(
                                                      user,
                                                    ),
                                                  ),
                                              child: Text(
                                                displayName,
                                                style: const TextStyle(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.bold,
                                                  color: AppColors.onSurface,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              '@${user['username'] ?? 'user'}',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    AppBadge(
                                      label: isBlacklisted
                                          ? 'SUSPENDED'
                                          : isVerified
                                          ? 'VERIFIED'
                                          : 'PENDING',
                                      type: isBlacklisted
                                          ? AppBadgeType.error
                                          : isVerified
                                          ? AppBadgeType.success
                                          : AppBadgeType.warning,
                                      icon: isBlacklisted
                                          ? Icons.lock_outline
                                          : isVerified
                                          ? Icons.verified
                                          : Icons.hourglass_top,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),

                                // Card Body
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceContainerLow,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'EMAIL',
                                              style: TextStyle(
                                                fontSize: 9,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.grey,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              email,
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: AppColors.onSurface,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 10),
                                            const Text(
                                              'CREATED AT',
                                              style: TextStyle(
                                                fontSize: 9,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.grey,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              createdAt,
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: AppColors.onSurface,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'CONTACT',
                                              style: TextStyle(
                                                fontSize: 9,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.grey,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              contact,
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: AppColors.onSurface,
                                              ),
                                            ),
                                            const SizedBox(height: 10),
                                            const Text(
                                              'LAST LOGIN',
                                              style: TextStyle(
                                                fontSize: 9,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.grey,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              user['last_login']?.toString() ??
                                                  'Today, 11:20 AM',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: AppColors.secondary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                // Suspension Reason Banner
                                if (isBlacklisted) ...[
                                  const SizedBox(height: 12),
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFEF2F2),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: Colors.red.shade200,
                                      ),
                                    ),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Icon(
                                          Icons.error_outline,
                                          size: 16,
                                          color: AppColors.error,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              const Text(
                                                'SUSPENSION REASON',
                                                style: TextStyle(
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.bold,
                                                  color: AppColors.error,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                (user['blacklist_reason'] ??
                                                        user['reason'] ??
                                                        'Account suspended by administrator.')
                                                    .toString(),
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  color: Color(0xFF991B1B),
                                                  height: 1.3,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 16),

                                // Action Buttons Row with Loading/Waiting States
                                LayoutBuilder(
                                  builder: (context, constraints) {
                                    final isNarrow = constraints.maxWidth < 320;
                                    final verifyBtn =
                                        (!isVerified && !isBlacklisted)
                                        ? AppButton(
                                            label: 'Verify',
                                            isLoading: isApproving,
                                            icon: const Icon(
                                              Icons.verified,
                                              size: 16,
                                            ),
                                            height: 40,
                                            onPressed:
                                                isApproving ||
                                                    isBanning ||
                                                    isDeleting
                                                ? null
                                                : () => _approveUser(userId),
                                          )
                                        : null;

                                    final banBtn = AppButton(
                                      label: isBlacklisted
                                          ? 'Unban'
                                          : 'Ban User',
                                      variant: isBlacklisted
                                          ? AppButtonVariant.primary
                                          : AppButtonVariant.secondary,
                                      isLoading: isBanning,
                                      icon: Icon(
                                        isBlacklisted
                                            ? Icons.lock_open
                                            : Icons.block,
                                        size: 16,
                                      ),
                                      height: 40,
                                      onPressed:
                                          isApproving || isBanning || isDeleting
                                          ? null
                                          : () {
                                              if (isBlacklisted) {
                                                _unblacklistUser(userId);
                                              } else {
                                                _showBlacklistDialog(
                                                  context,
                                                  userId,
                                                );
                                              }
                                            },
                                    );

                                    final deleteBtn = AppButton(
                                      label: 'Delete',
                                      variant: AppButtonVariant.danger,
                                      isLoading: isDeleting,
                                      icon: const Icon(
                                        Icons.delete_outline,
                                        size: 16,
                                      ),
                                      height: 40,
                                      onPressed:
                                          isApproving || isBanning || isDeleting
                                          ? null
                                          : () => _deleteUser(userId),
                                    );

                                    if (isNarrow) {
                                      return Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: [
                                          if (verifyBtn != null)
                                            SizedBox(
                                              width:
                                                  (constraints.maxWidth - 8) /
                                                  2,
                                              child: verifyBtn,
                                            ),
                                          SizedBox(
                                            width:
                                                (constraints.maxWidth - 8) / 2,
                                            child: banBtn,
                                          ),
                                          SizedBox(
                                            width: constraints.maxWidth,
                                            child: deleteBtn,
                                          ),
                                        ],
                                      );
                                    }

                                    return Row(
                                      children: [
                                        if (verifyBtn != null) ...[
                                          Expanded(child: verifyBtn),
                                          const SizedBox(width: 8),
                                        ],
                                        Expanded(child: banBtn),
                                        const SizedBox(width: 8),
                                        Expanded(child: deleteBtn),
                                      ],
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(
    String label,
    String? count, {
    Color? badgeColor,
    Color? badgeBg,
  }) {
    final isSelected = _selectedFilter == label;
    return InkWell(
      onTap: () => setState(() => _selectedFilter = label),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.grey.shade300,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : AppColors.onSurface,
              ),
            ),
            if (count != null) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: badgeBg ?? Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  count,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: badgeColor ?? AppColors.onSurface,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String formatNumberStatic(int number) {
    return number.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }
}
