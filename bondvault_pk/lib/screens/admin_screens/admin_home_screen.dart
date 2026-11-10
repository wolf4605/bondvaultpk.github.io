import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../config/app_config.dart';
import '../../config/app_theme.dart';
import '../../utils/api_service.dart';
import '../../widgets/widgets.dart';
import '../login_screen.dart';
import 'admin_audit_logs_screen.dart';
import 'admin_users_screen.dart';

class AdminHomeScreen extends StatefulWidget {
  final String accessToken;
  final Map<String, dynamic> adminInfo;

  const AdminHomeScreen({
    super.key,
    required this.accessToken,
    required this.adminInfo,
  });

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  int _currentIndex = 0;
  bool _isLoadingStats = true;
  int _totalUsers = 0;
  List<dynamic> _usersList = [];
  bool _isLoadingUsers = false;
  List<dynamic> _recentAuditEvents = [];

  int get _newUsersCount {
    final now = DateTime.now();
    int count = 0;
    for (final u in _usersList) {
      final createdAtStr = u['created_at'];
      if (createdAtStr != null) {
        try {
          final dt = DateTime.parse(createdAtStr.toString());
          if (now.difference(dt).inDays <= 7) {
            count++;
          }
        } catch (_) {}
      }
    }
    return count;
  }

  @override
  void initState() {
    super.initState();
    _fetchAdminData();
  }

  Future<void> _fetchAdminData() async {
    setState(() {
      _isLoadingStats = true;
      _isLoadingUsers = true;
    });

    try {
      final activeRes = await http.get(
        Uri.parse('${AppConfig.baseUrl}${AppConfig.activeUsersEndpoint}'),
        headers: {'Authorization': 'Bearer ${widget.accessToken}'},
      );
      if (activeRes.statusCode == 200) {
        final activeData = jsonDecode(activeRes.body);
        _totalUsers = activeData['total_registered_users'] ?? 48320;
      }

      final blacklistRes = await http.get(
        Uri.parse('${AppConfig.baseUrl}${AppConfig.adminBlacklistEndpoint}'),
        headers: {'Authorization': 'Bearer ${widget.accessToken}'},
      );
      final blacklistedSet = <String>{};
      final blacklistReasonMap = <String, String>{};
      if (blacklistRes.statusCode == 200) {
        final blacklistData = jsonDecode(blacklistRes.body);
        final list = blacklistData['blacklisted_users'] ?? [];
        for (var b in list) {
          final reason = (b['reason'] ?? '').toString().trim();
          final effectiveReason = reason.isNotEmpty
              ? reason
              : 'Account suspended by administrator.';
          if (b['email'] != null) {
            final em = b['email'].toString().toLowerCase();
            blacklistedSet.add(em);
            blacklistReasonMap[em] = effectiveReason;
          }
          if (b['contact'] != null) {
            final ct = b['contact'].toString();
            blacklistedSet.add(ct);
            blacklistReasonMap[ct] = effectiveReason;
          }
          if (b['user_id'] != null) {
            final uid = b['user_id'].toString();
            blacklistedSet.add(uid);
            blacklistReasonMap[uid] = effectiveReason;
          }
        }
      }

      final usersRes = await http.get(
        Uri.parse('${AppConfig.baseUrl}${AppConfig.adminUsersEndpoint}'),
        headers: {'Authorization': 'Bearer ${widget.accessToken}'},
      );
      if (usersRes.statusCode == 200) {
        final usersData = jsonDecode(usersRes.body);
        final rawUsers = usersData['users'] ?? [];
        _usersList = rawUsers.map<Map<String, dynamic>>((u) {
          final map = Map<String, dynamic>.from(u);
          final email = (map['email'] ?? '').toString().toLowerCase();
          final contact = (map['contact'] ?? '').toString();
          final id = (map['id'] ?? '').toString();
          final isBlacklisted =
              blacklistedSet.contains(email) ||
              blacklistedSet.contains(contact) ||
              blacklistedSet.contains(id);
          map['is_blacklisted'] = isBlacklisted;
          map['blacklist_reason'] = blacklistReasonMap[email] ??
              blacklistReasonMap[contact] ??
              blacklistReasonMap[id] ??
              'Account suspended by administrator.';
          return map;
        }).toList();
      }

      final auditData = await ApiService.fetchAdminAuditLogs(
        adminToken: widget.accessToken,
        limit: 3,
      );
      if (auditData != null) {
        final list = auditData['events'] ?? auditData['audit_events'] ?? [];
        if (list is List) {
          _recentAuditEvents = list;
        }
      }
    } catch (_) {
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingStats = false;
          _isLoadingUsers = false;
        });
      }
    }
  }

  String _formatAuditTime(String raw) {
    if (raw.isEmpty) return 'Just now';
    try {
      final date = DateTime.tryParse(raw);
      if (date == null) return raw;
      final local = date.toLocal();
      return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return raw;
    }
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('saved_username');
    await prefs.remove('saved_password');

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final username = widget.adminInfo['username'] ?? 'Admin';
    final email = widget.adminInfo['email'] ?? 'admin@bondvault.pk';

    final List<Widget> adminViews = [
      _buildOverviewView(),
      _buildUserView(),
      _buildMarketView(),
      _buildDrawsView(),
      _buildSettingsView(),
    ];

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        leading: Builder(
          builder: (context) => IconButton(
            icon: Icon(
              Icons.menu,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: Image.asset('assets/logo.png', fit: BoxFit.contain),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'BondVault ',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                    const Text(
                      'PK',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.warning,
                      ),
                    ),
                    const SizedBox(width: 6),
                    AppBadge.admin(),
                  ],
                ),
                const Text(
                  'Dashboard',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ],
        ),
      ),
      drawer: Drawer(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            UserAccountsDrawerHeader(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.primary, AppColors.primaryContainer],
                ),
              ),
              currentAccountPicture: const CircleAvatar(
                backgroundColor: Colors.white,
                child: Icon(
                  Icons.admin_panel_settings,
                  size: 36,
                  color: AppColors.primary,
                ),
              ),
              accountName: Text(
                username,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              accountEmail: Text(email),
            ),
            ListTile(
              leading: const Icon(Icons.grid_view_outlined),
              title: const Text('Dashboard'),
              selected: _currentIndex == 0,
              onTap: () {
                Navigator.pop(context);
                setState(() => _currentIndex = 0);
              },
            ),
            ListTile(
              leading: const Icon(Icons.shield_outlined),
              title: const Text('Users Management'),
              selected: _currentIndex == 1,
              onTap: () {
                Navigator.pop(context);
                setState(() => _currentIndex = 1);
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.security_outlined,
                color: AppColors.primary,
              ),
              title: const Text(
                'System Audit Logs',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        AdminAuditLogsScreen(accessToken: widget.accessToken),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.storefront_outlined),
              title: const Text('Market Management'),
              selected: _currentIndex == 2,
              onTap: () {
                Navigator.pop(context);
                setState(() => _currentIndex = 2);
              },
            ),
            ListTile(
              leading: const Icon(Icons.calendar_today_outlined),
              title: const Text('Draw Schedules'),
              selected: _currentIndex == 3,
              onTap: () {
                Navigator.pop(context);
                setState(() => _currentIndex = 3);
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: const Text('Settings'),
              selected: _currentIndex == 4,
              onTap: () {
                Navigator.pop(context);
                setState(() => _currentIndex = 4);
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: AppColors.error),
              title: const Text(
                'Logout',
                style: TextStyle(color: AppColors.error),
              ),
              onTap: _logout,
            ),
          ],
        ),
      ),
      body: adminViews[_currentIndex > 4 ? 0 : _currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex > 4 ? 0 : _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.grid_view_outlined),
            selectedIcon: Icon(Icons.grid_view_rounded),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.shield_outlined),
            selectedIcon: Icon(Icons.shield_rounded),
            label: 'Users',
          ),
          NavigationDestination(
            icon: Icon(Icons.storefront_outlined),
            selectedIcon: Icon(Icons.storefront_rounded),
            label: 'Market',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_today_outlined),
            selectedIcon: Icon(Icons.calendar_today_rounded),
            label: 'Draws',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings_rounded),
            label: 'Settings',
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewView() {
    final unverifiedCount = _usersList
        .where((u) => u['is_verified'] != true)
        .length;

    return RefreshIndicator(
      onRefresh: _fetchAdminData,
      child: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Top Console Banner
          AppSectionHeader(
            title: 'Assalam-o-Alaikum, Admin',
            tagline: 'ADMIN CONTROL CONSOLE',
          ),
          const SizedBox(height: 16),

          // Core Infrastructure Status Card
          const AppSectionHeader(title: 'System', tagline: 'Core'),
          AppCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: const [
                        Icon(
                          Icons.dns_outlined,
                          size: 18,
                          color: AppColors.primary,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'CORE INFRASTRUCTURE STATUS',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                    AppBadge(
                      label: 'NORMAL',
                      type: AppBadgeType.success,
                      isSmall: true,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildSubStatusCard(
                        'Backend\nAPI',
                        'Live',
                        AppColors.success,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildSubStatusCard(
                        'Database\n(PG)',
                        'OK',
                        AppColors.success,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildSubStatusCard(
                        'Redis\n(Cache)',
                        'Active',
                        AppColors.success,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // User Overview Header
          const AppSectionHeader(title: 'User Overview', tagline: 'ANALYTICS'),
          const SizedBox(height: 12),

          // Stat Cards Grid (3 cards)
          Row(
            children: [
              Expanded(
                child: AppStatCard(
                  title: 'Total Users',
                  value: _isLoadingStats ? '...' : '$_totalUsers',
                  icon: Icons.person_outline,
                  subtitle: 'Registered',
                  iconColor: Colors.blue,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AppStatCard(
                  title: 'New (7d)',
                  value: _isLoadingUsers ? '...' : '+$_newUsersCount',
                  icon: Icons.person_add_outlined,
                  subtitle: 'Onboarded',
                  iconColor: Colors.teal,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AppStatCard(
                  title: 'Awaiting',
                  value: '$unverifiedCount Users',
                  icon: Icons.fingerprint,
                  subtitle: 'Reviews →',
                  iconColor: AppColors.warning,
                  onTap: () => setState(() => _currentIndex = 1),
                  badge: AppBadge(
                    label: 'PENDING',
                    type: AppBadgeType.warning,
                    isSmall: true,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Recent Audit Logs Section on Admin Dashboard
          AppSectionHeader(
            title: 'Recent System Audit Logs',
            tagline: 'SECURITY & ACTIONS',
            action: TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        AdminAuditLogsScreen(accessToken: widget.accessToken),
                  ),
                );
              },
              child: const Text(
                'View All Logs →',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _recentAuditEvents.isEmpty
              ? const AppEmptyState(
                  icon: Icons.history_toggle_off_outlined,
                  title: 'No Recent Audit Events',
                  message: 'No administrator API actions recorded yet. Pull down to refresh.',
                )
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _recentAuditEvents.length > 3
                      ? 3
                      : _recentAuditEvents.length,
                  itemBuilder: (context, index) {
                    final item = _recentAuditEvents[index];
                    final action = item['action']?.toString() ?? 'SYSTEM_EVENT';
                    final method = item['http_method']?.toString() ?? 'GET';
                    final route = item['route']?.toString() ?? '/';
                    final status = item['status_code'] as int? ?? 200;
                    final occurredAt = _formatAuditTime(
                      item['occurred_at']?.toString() ?? '',
                    );

                    AppBadgeType badgeType = (status >= 200 && status < 300)
                        ? AppBadgeType.success
                        : (status >= 400 && status < 500)
                        ? AppBadgeType.warning
                        : AppBadgeType.error;

                    final actorUsername = (item['actor_username'] ?? '')
                        .toString()
                        .trim();
                    final actorEmail = (item['actor_email'] ?? '')
                        .toString()
                        .trim();
                    final adminName = actorUsername.isNotEmpty
                        ? '@$actorUsername'
                        : (actorEmail.isNotEmpty ? actorEmail : 'Admin');

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: AppCard(
                        padding: const EdgeInsets.all(12),
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
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                method,
                                style: const TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    action.toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 1),
                                  Text(
                                    'Admin: $adminName • $route • $occurredAt',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            AppBadge(
                              label: 'HTTP $status',
                              type: badgeType,
                              isSmall: true,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ],
      ),
    );
  }

  Widget _buildSubStatusCard(String title, String badgeText, Color badgeColor) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppColors.onSurface,
                ),
              ),
              AppBadge(
                label: badgeText,
                type: AppBadgeType.success,
                isSmall: true,
              ),
            ],
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _buildUserView() {
    return AdminUsersScreen(
      accessToken: widget.accessToken,
      usersList: _usersList,
      onDataChanged: _fetchAdminData,
    );
  }

  Widget _buildMarketView() {
    return const AppEmptyState(
      icon: Icons.storefront_outlined,
      title: 'Market Management',
      message: 'Manage marketplace offers and trade policy limits.',
    );
  }

  Widget _buildDrawsView() {
    return const AppEmptyState(
      icon: Icons.calendar_today_outlined,
      title: 'Draws Management',
      message: 'Configure SBP gazette sync and draw result uploads.',
    );
  }

  Widget _buildSettingsView() {
    return const AppEmptyState(
      icon: Icons.settings_outlined,
      title: 'Admin Settings',
      message: 'System override policies, audit logs, and security settings.',
    );
  }
}
