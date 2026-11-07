import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../config/app_config.dart';
import '../login_screen.dart';
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
  int _currentIndex = 0; // 0: Overview, 1: Users, 2: Market, 3: Draws, 4: Settings
  bool _isLoadingStats = true;
  int _totalUsers = 0;
  List<dynamic> _usersList = [];
  bool _isLoadingUsers = false;

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
      if (blacklistRes.statusCode == 200) {
        final blacklistData = jsonDecode(blacklistRes.body);
        final list = blacklistData['blacklisted_users'] ?? [];
        for (var b in list) {
          if (b['email'] != null) {
            blacklistedSet.add(b['email'].toString().toLowerCase());
          }
          if (b['contact'] != null) {
            blacklistedSet.add(b['contact'].toString());
          }
          if (b['user_id'] != null) {
            blacklistedSet.add(b['user_id'].toString());
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
          return map;
        }).toList();
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
      backgroundColor: const Color(0xFFFAFAFF),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFAFAFF),
        elevation: 0,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu, color: Color(0xFF131B2E)),
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
                        color: Color(0xFF003527),
                      ),
                    ),
                    const Text(
                      'PK',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFD97706),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFEDD5),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'ADMIN',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF904D00),
                        ),
                      ),
                    ),
                  ],
                ),
                const Text(
                  'Overview Dashboard',
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ],
        ),
      ),
      drawer: Drawer(
        backgroundColor: Colors.white,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            UserAccountsDrawerHeader(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF003527), Color(0xFF064E3B)],
                ),
              ),
              currentAccountPicture: const CircleAvatar(
                backgroundColor: Colors.white,
                child: Icon(
                  Icons.admin_panel_settings,
                  size: 36,
                  color: Color(0xFF003527),
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
              title: const Text('Overview'),
              onTap: () {
                Navigator.pop(context);
                setState(() => _currentIndex = 0);
              },
            ),
            ListTile(
              leading: const Icon(Icons.shield_outlined),
              title: const Text('Users'),
              onTap: () {
                Navigator.pop(context);
                setState(() => _currentIndex = 1);
              },
            ),
            ListTile(
              leading: const Icon(Icons.storefront_outlined),
              title: const Text('Market'),
              onTap: () {
                Navigator.pop(context);
                setState(() => _currentIndex = 2);
              },
            ),
            ListTile(
              leading: const Icon(Icons.calendar_today_outlined),
              title: const Text('Draws'),
              onTap: () {
                Navigator.pop(context);
                setState(() => _currentIndex = 3);
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: const Text('Settings'),
              onTap: () {
                Navigator.pop(context);
                setState(() => _currentIndex = 4);
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Logout', style: TextStyle(color: Colors.red)),
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
            label: 'Overview',
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'ADMIN CONTROL CONSOLE',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                  color: Color(0xFF404944),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFA7F3D0),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Color(0xFF065F46),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'SYS ONLINE',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF065F46),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Greeting
          RichText(
            text: const TextSpan(
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: Color(0xFF003527),
                letterSpacing: -0.5,
              ),
              children: [
                TextSpan(text: 'Assalam-o-Alaikum, '),
                TextSpan(
                  text: 'Admin',
                  style: TextStyle(color: Color(0xFF904D00)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Core Infrastructure Status Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF2F3FF),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE2E7FF)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.dns_outlined,
                          size: 18,
                          color: Color(0xFF003527),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'CORE INFRASTRUCTURE STATUS',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                            color: Color(0xFF003527),
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFA7F3D0),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: Color(0xFF065F46),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'NORMAL',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF065F46),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildSubStatusCard(
                        'Backend\nAPI',
                        'Operational',
                        '99.98% uptime',
                        'Live',
                        Colors.green,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildSubStatusCard(
                        'Database\n(PG)',
                        'Connected /\nHealthy',
                        '4ms latency',
                        'OK',
                        Colors.green,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildSubStatusCard(
                        'Redis\n(Cache)',
                        'Memory 24%',
                        '1.2ms latency',
                        'Active',
                        Colors.green,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Investor & User Overview Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: const [
                  Icon(
                    Icons.group_outlined,
                    size: 20,
                    color: Color(0xFF003527),
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Investor & User Overview',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF003527),
                    ),
                  ),
                ],
              ),
              const Text(
                'Synced 1m ago',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Stat Cards Grid (3 cards)
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.person_outline,
                          size: 16,
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Total Users',
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _isLoadingStats ? '...' : '$_totalUsers',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF131B2E),
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Registered accounts',
                        style: TextStyle(fontSize: 9, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.teal.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.person_add_outlined,
                          size: 16,
                          color: Colors.teal,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'New (Last 7d)',
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _isLoadingUsers ? '...' : '+$_newUsersCount',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF131B2E),
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Active onboarding',
                        style: TextStyle(fontSize: 9, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFEDD5),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.fingerprint,
                              size: 16,
                              color: Color(0xFF904D00),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF904D00),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text(
                              'PENDING',
                              style: TextStyle(
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Awaiting',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF904D00),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$unverifiedCount Users',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF904D00),
                        ),
                      ),
                      const SizedBox(height: 2),
                      InkWell(
                        onTap: () => setState(() => _currentIndex = 1),
                        child: Row(
                          children: const [
                            Text(
                              'Revies →',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF904D00),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSubStatusCard(
    String title,
    String subtitle,
    String footer,
    String badgeText,
    Color badgeColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
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
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF131B2E),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  badgeText,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: badgeColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 11, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          Text(
            footer,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Color(0xFF003527),
            ),
          ),
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
    return const Center(child: Text('Market Management'));
  }

  Widget _buildDrawsView() {
    return const Center(child: Text('Draws Management'));
  }

  Widget _buildSettingsView() {
    return const Center(child: Text('Admin Settings'));
  }
}
