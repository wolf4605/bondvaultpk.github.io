import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../utils/api_service.dart';
import '../../utils/app_utils.dart';
import '../login_screen.dart';
import 'tabs/draw_schedules_tab.dart';
import 'tabs/home_tab.dart';
import 'tabs/marketplace_tab.dart';
import 'tabs/my_bonds_tab.dart';
import 'tabs/search_bonds_tab.dart';
import 'tabs/settings_tab.dart';

class HomeScreen extends StatefulWidget {
  final String accessToken;
  final Map<String, dynamic> userInfo;

  const HomeScreen({
    super.key,
    required this.accessToken,
    required this.userInfo,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  bool _isLoadingPortfolio = true;
  int _totalAssets = 0;
  int _totalBonds = 0;

  @override
  void initState() {
    super.initState();
    if (widget.userInfo['is_verified'] == true) {
      _fetchPortfolioData();
    } else {
      _isLoadingPortfolio = false;
    }
  }

  Future<void> _fetchPortfolioData() async {
    setState(() => _isLoadingPortfolio = true);
    try {
      final data = await ApiService.fetchBondlists(widget.accessToken);
      if (data != null) {
        final lists = data['bondlists']?['bondlists'] ?? [];
        int sum = 0;
        int count = 0;
        for (final list in lists) {
          final denomination = list['denomination'] as int? ?? 0;
          final bonds = list['bonds'] as List? ?? [];
          sum += denomination * bonds.length;
          count += bonds.length;
        }
        setState(() {
          _totalAssets = sum;
          _totalBonds = count;
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoadingPortfolio = false);
    }
  }

  Future<void> _logout(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('saved_username');
    await prefs.remove('saved_password');
    if (!context.mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'BondVault PK',
      applicationVersion: '1.0.0',
      applicationIcon: CircleAvatar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        child: const Icon(Icons.security, color: Colors.white),
      ),
      children: const [
        SizedBox(height: 12),
        Text(
          'BondVault PK is a secure prize bond tracking and management application designed for Pakistan.',
        ),
      ],
    );
  }

  void handleTabChange(int index) {
    final isVerified = widget.userInfo['is_verified'] == true;
    if (!isVerified && index > 1 && index != 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Feature locked: Unverified users can only access Home and Search. Please wait for admin verification.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final username = widget.userInfo['username'] ?? 'User';
    final email = widget.userInfo['email'] ?? 'No email';
    final firstName = widget.userInfo['first_name'] ?? '';
    final lastName = widget.userInfo['last_name'] ?? '';
    final contact = widget.userInfo['contact'] ?? '+92 300 ••••567';
    final isVerified = widget.userInfo['is_verified'] == true;
    final fullName = '$firstName $lastName'.trim().isEmpty
        ? username
        : '$firstName $lastName';

    final List<Widget> tabs = [
      HomeTab(
        fullName: fullName,
        isVerified: isVerified,
        accessToken: widget.accessToken,
        isLoading: _isLoadingPortfolio,
        totalAssets: _totalAssets,
        totalBonds: _totalBonds,
        formatNumber: formatNumber,
        onNavigate: (index) => handleTabChange(index),
      ),
      SearchBondsTab(isVerified: isVerified),
      MyBondsTab(
        isVerified: isVerified,
        accessToken: widget.accessToken,
        onPortfolioUpdated: _fetchPortfolioData,
      ),
      MarketplaceTab(isVerified: isVerified),
      const DrawSchedulesTab(),
      SettingsTab(
        email: email,
        fullName: fullName,
        onLogout: () => _logout(context),
        onAbout: () => _showAboutDialog(context),
      ),
    ];

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor:
            Theme.of(context).appBarTheme.backgroundColor ??
            Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
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
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(8),
                boxShadow: Theme.of(context).brightness == Brightness.dark
                    ? []
                    : [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 4,
                        ),
                      ],
              ),
              child: Image.asset('assets/logo.png', fit: BoxFit.contain),
            ),
            const SizedBox(width: 8),
            Row(
              children: [
                Text(
                  'BondVault ',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                Text(
                  'PK',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('No unread notifications'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),
              Positioned(
                top: 14,
                right: 14,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFF10B981),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 4),
        ],
      ),
      drawer: Drawer(
        backgroundColor: Theme.of(context).cardColor,
        child: Column(
          children: [
            // Drawer Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 48, 20, 20),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF003527), Color(0xFF064E3B)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Image.asset(
                          'assets/logo.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Row(
                        children: [
                          const Text(
                            'BondVault ',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const Text(
                            'PK',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFFE932C),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Text(
                        fullName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 8),
                      buildVerifiedBadge(isVerified),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '@$username',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF80BEA6),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    contact,
                    style: const TextStyle(fontSize: 11, color: Colors.white70),
                  ),
                  const SizedBox(height: 12),
                  // Quick Portfolio Card
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.15),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.amber.shade500.withValues(
                                  alpha: 0.2,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.account_balance_wallet,
                                color: Color(0xFFFE932C),
                                size: 16,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _isLoadingPortfolio
                                  ? '...'
                                  : '$_totalBonds Bonds',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          _isLoadingPortfolio
                              ? '...'
                              : 'Rs. ${formatNumber(_totalAssets)}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF95D3BA),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Navigation Items
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  vertical: 8,
                  horizontal: 12,
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                    child: Text(
                      'MAIN NAVIGATION',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  _buildDrawerItem(
                    icon: Icons.dashboard,
                    title: 'Dashboard',
                    isSelected: _currentIndex == 0,
                    onTap: () {
                      Navigator.pop(context);
                      handleTabChange(0);
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.account_balance_wallet_outlined,
                    title: 'My Bonds',
                    isSelected: _currentIndex == 2,
                    onTap: () {
                      Navigator.pop(context);
                      handleTabChange(2);
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.storefront_outlined,
                    title: 'Marketplace',
                    isSelected: _currentIndex == 3,
                    onTap: () {
                      Navigator.pop(context);
                      handleTabChange(3);
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.military_tech_outlined,
                    title: 'Draw Results',
                    isSelected: false,
                    onTap: () {
                      Navigator.pop(context);
                      handleTabChange(4);
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.calendar_today_outlined,
                    title: 'Draw Schedule',
                    isSelected: _currentIndex == 4,
                    onTap: () {
                      Navigator.pop(context);
                      handleTabChange(4);
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.card_giftcard_outlined,
                    title: 'Prize Winnings & Claims',
                    isSelected: false,
                    hasBadge: true,
                    onTap: () {
                      Navigator.pop(context);
                      handleTabChange(2);
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.description_outlined,
                    title: 'Reports',
                    isSelected: false,
                    onTap: () {
                      Navigator.pop(context);
                      handleTabChange(2);
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.settings_outlined,
                    title: 'Settings',
                    isSelected: _currentIndex == 5,
                    onTap: () {
                      Navigator.pop(context);
                      handleTabChange(5);
                    },
                  ),
                ],
              ),
            ),
            // Drawer Footer Logout Button
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerLow,
                border: Border(
                  top: BorderSide(color: Theme.of(context).dividerColor),
                ),
              ),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFBA1A1A),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () => _logout(context),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.logout, size: 18),
                      SizedBox(width: 8),
                      Text(
                        'Log Out',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      body: tabs[_currentIndex],
      bottomNavigationBar: _currentIndex == 5
          ? null
          : NavigationBar(
              selectedIndex: _currentIndex > 4 ? 0 : _currentIndex,
              onDestinationSelected: (index) => handleTabChange(index),
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home_rounded),
                  label: 'Home',
                ),
                NavigationDestination(
                  icon: Icon(Icons.search_outlined),
                  selectedIcon: Icon(Icons.search_rounded),
                  label: 'Search',
                ),
                NavigationDestination(
                  icon: Icon(Icons.account_balance_wallet_outlined),
                  selectedIcon: Icon(Icons.account_balance_wallet_rounded),
                  label: 'My Bonds',
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
              ],
            ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required bool isSelected,
    bool hasBadge = false,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
      child: ListTile(
        leading: Icon(
          icon,
          color: isSelected
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.onSurfaceVariant,
          size: 20,
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.onSurface,
          ),
        ),
        tileColor: isSelected
            ? Theme.of(context).colorScheme.primaryContainer
                  .withValues(alpha: 0.25)
            : null,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        trailing: hasBadge
            ? Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFFFE932C),
                  shape: BoxShape.circle,
                ),
              )
            : isSelected
            ? Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  shape: BoxShape.circle,
                ),
              )
            : null,
        onTap: onTap,
        dense: true,
      ),
    );
  }
}
