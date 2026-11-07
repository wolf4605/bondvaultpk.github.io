import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../config/app_config.dart';

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

  Future<void> _approveUser(String userId) async {
    try {
      final res = await http.post(
        Uri.parse('${AppConfig.baseUrl}/admins/users/$userId/approve'),
        headers: {'Authorization': 'Bearer ${widget.accessToken}'},
      );
      if (!mounted) return;
      if (res.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User approved successfully!')),
        );
        widget.onDataChanged();
      } else {
        final data = jsonDecode(res.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['detail'] ?? 'Failed to approve user.')),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Connection error approving user.')),
      );
    }
  }

  Future<void> _blacklistUser(String userId, DateTime? durationUntil) async {
    try {
      final body = durationUntil != null
          ? {'duration_until': durationUntil.toUtc().toIso8601String()}
          : {};
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User blacklisted successfully.')),
        );
        widget.onDataChanged();
      } else {
        final data = jsonDecode(res.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['detail'] ?? 'Failed to blacklist user.'),
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Connection error blacklisting user.')),
      );
    }
  }

  Future<void> _unblacklistUser(String userId) async {
    try {
      final res = await http.delete(
        Uri.parse('${AppConfig.baseUrl}/admins/users/$userId/blacklist'),
        headers: {'Authorization': 'Bearer ${widget.accessToken}'},
      );
      if (!mounted) return;
      if (res.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User removed from blacklist.')),
        );
        widget.onDataChanged();
      } else {
        final data = jsonDecode(res.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['detail'] ?? 'Failed to unblacklist user.'),
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Connection error unblacklisting user.')),
      );
    }
  }

  Future<void> _deleteUser(String userId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete User', style: TextStyle(color: Colors.red)),
        content: const Text(
          'Are you sure you want to permanently delete this user account?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final res = await http.delete(
        Uri.parse('${AppConfig.baseUrl}/admins/users/$userId'),
        headers: {'Authorization': 'Bearer ${widget.accessToken}'},
      );
      if (!mounted) return;
      if (res.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User deleted successfully.')),
        );
        widget.onDataChanged();
      } else {
        final data = jsonDecode(res.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['detail'] ?? 'Failed to delete user.')),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Connection error deleting user.')),
      );
    }
  }

  void _showBlacklistDialog(BuildContext context, String userId) {
    String selectedPeriod = 'permanent ban';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: const Text('Ban User'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Select time period for ban:'),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: selectedPeriod,
                decoration: const InputDecoration(border: OutlineInputBorder()),
                items:
                    [
                          '1 day',
                          '3 day',
                          '7 day',
                          '15 day',
                          '1 month',
                          'permanent ban',
                        ]
                        .map(
                          (period) => DropdownMenuItem(
                            value: period,
                            child: Text(period),
                          ),
                        )
                        .toList(),
                onChanged: (val) {
                  if (val != null) {
                    setStateDialog(() => selectedPeriod = val);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange.shade800,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.pop(context);
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
                _blacklistUser(userId, durationUntil);
              },
              child: const Text('Confirm Ban'),
            ),
          ],
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
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search by Name, CNIC, Mobile, or ID...',
                      hintStyle: const TextStyle(
                        fontSize: 13,
                        color: Colors.grey,
                      ),
                      prefixIcon: const Icon(Icons.search, color: Colors.grey),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: Colors.grey.shade200),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: Colors.grey.shade200),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
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
                    color: Color(0xFF131B2E),
                    size: 20,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Filter Chips Row
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('All', null),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    'Pending',
                    '$pendingCount',
                    badgeColor: const Color(0xFF904D00),
                    badgeBg: const Color(0xFFFFEDD5),
                  ),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    'Verified',
                    formatNumberStatic(verifiedCount),
                    badgeColor: const Color(0xFF003527),
                    badgeBg: const Color(0xFFA7F3D0),
                  ),
                  const SizedBox(width: 8),
                  _buildFilterChip('Suspended', null),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Users List
            Expanded(
              child: filteredUsers.isEmpty
                  ? const Center(
                      child: Text('No users match the selected filter.'),
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

                        // Status Badge properties
                        String statusText = 'PENDING';
                        Color statusBg = const Color(0xFFFFEDD5);
                        Color statusColor = const Color(0xFF904D00);

                        if (isBlacklisted) {
                          statusText = 'SUSPENDED';
                          statusBg = Colors.red.shade50;
                          statusColor = const Color(0xFFBA1A1A);
                        } else if (isVerified) {
                          statusText = 'VERIFIED';
                          statusBg = const Color(0xFFA7F3D0);
                          statusColor = const Color(0xFF065F46);
                        }

                        return Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFFE2E7FF)),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF064E3B)
                                    .withValues(alpha: 0.04),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
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
                                                : const Color(0xFF904D00),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          InkWell(
                                            onTap: () => _showUserDetailsDialog(
                                              Map<String, dynamic>.from(user),
                                            ),
                                            child: Text(
                                              displayName,
                                              style: const TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFF131B2E),
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
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: statusBg,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          isVerified
                                              ? Icons.verified
                                              : isBlacklisted
                                              ? Icons.lock_outline
                                              : Icons.hourglass_top,
                                          size: 12,
                                          color: statusColor,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          statusText,
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: statusColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),

                              // Card Body (2 Columns)
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF9FAFB),
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
                                              color: Color(0xFF131B2E),
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
                                              color: Color(0xFF131B2E),
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
                                              color: Color(0xFF131B2E),
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
                                              color: Color(0xFF904D00),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Suspension Reason Banner (if suspended)
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
                                        color: Color(0xFFBA1A1A),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: const [
                                            Text(
                                              'SUSPENSION REASON',
                                              style: TextStyle(
                                                fontSize: 9,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFFBA1A1A),
                                              ),
                                            ),
                                            SizedBox(height: 2),
                                            Text(
                                              'Multiple failed CNIC verification attempts & flagged IP anomalies',
                                              style: TextStyle(
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

                              // Card Footer Action Buttons
                              Row(
                                children: [
                                  if (!isVerified && !isBlacklisted) ...[
                                    Expanded(
                                      child:
                                          ElevatedButton.styleFrom(
                                            backgroundColor: const Color(
                                              0xFF003527,
                                            ),
                                            foregroundColor: Colors.white,
                                            elevation: 0,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 12,
                                            ),
                                          ).let(
                                            (style) => ElevatedButton(
                                              style: style,
                                              onPressed: () =>
                                                  _approveUser(userId),
                                              child: Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: const [
                                                  Icon(
                                                    Icons.verified,
                                                    size: 16,
                                                    color: Colors.white,
                                                  ),
                                                  SizedBox(width: 6),
                                                  Text(
                                                    'Verify',
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 13,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                    ),
                                    const SizedBox(width: 8),
                                  ],
                                  Expanded(
                                    child:
                                        ElevatedButton.styleFrom(
                                          backgroundColor: isBlacklisted
                                              ? const Color(0xFF003527)
                                              : const Color(0xFFFFEDD5),
                                          foregroundColor: isBlacklisted
                                              ? Colors.white
                                              : const Color(0xFF904D00),
                                          elevation: 0,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 12,
                                          ),
                                        ).let(
                                          (style) => ElevatedButton(
                                            style: style,
                                            onPressed: () {
                                              if (isBlacklisted) {
                                                _unblacklistUser(userId);
                                              } else {
                                                _showBlacklistDialog(
                                                  context,
                                                  userId,
                                                );
                                              }
                                            },
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Icon(
                                                  isBlacklisted
                                                      ? Icons.lock_open
                                                      : Icons.block,
                                                  size: 16,
                                                  color: isBlacklisted
                                                      ? Colors.white
                                                      : const Color(0xFF904D00),
                                                ),
                                                const SizedBox(width: 6),
                                                Text(
                                                  isBlacklisted
                                                      ? 'Unban'
                                                      : 'Ban User',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 13,
                                                    color: isBlacklisted
                                                        ? Colors.white
                                                        : const Color(
                                                            0xFF904D00,
                                                          ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child:
                                        ElevatedButton.styleFrom(
                                          backgroundColor: const Color(
                                            0xFFFEE2E2,
                                          ),
                                          foregroundColor: const Color(
                                            0xFF991B1B,
                                          ),
                                          elevation: 0,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 12,
                                          ),
                                        ).let(
                                          (style) => ElevatedButton(
                                            style: style,
                                            onPressed: () =>
                                                _deleteUser(userId),
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: const [
                                                Icon(
                                                  Icons.delete_outline,
                                                  size: 16,
                                                  color: Color(0xFF991B1B),
                                                ),
                                                SizedBox(width: 6),
                                                Text(
                                                  'Delete',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 13,
                                                    color: Color(0xFF991B1B),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                  ),
                                ],
                              ),
                            ],
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
          color: isSelected ? const Color(0xFF003527) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF003527) : Colors.grey.shade300,
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
                color: isSelected ? Colors.white : const Color(0xFF131B2E),
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
                    color: badgeColor ?? const Color(0xFF131B2E),
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

extension on ButtonStyle {
  Widget let(Widget Function(ButtonStyle style) builder) => builder(this);
}
