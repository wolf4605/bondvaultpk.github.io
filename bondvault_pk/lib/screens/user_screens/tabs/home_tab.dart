import 'package:flutter/material.dart';

import '../../../config/app_theme.dart';
import '../../../config/responsive.dart';
import '../../../utils/api_service.dart';
import '../../../widgets/widgets.dart';
import '../draw_detail_screen.dart';
import '../draw_lists_screen.dart';

class HomeTab extends StatefulWidget {
  final String fullName;
  final bool isVerified;
  final String accessToken;
  final bool isLoading;
  final int totalAssets;
  final int totalBonds;
  final String Function(int) formatNumber;
  final ValueChanged<int> onNavigate;

  const HomeTab({
    super.key,
    required this.fullName,
    required this.isVerified,
    required this.accessToken,
    required this.isLoading,
    required this.totalAssets,
    required this.totalBonds,
    required this.formatNumber,
    required this.onNavigate,
  });

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  Map<String, dynamic>? _nextDraw;
  bool _isLoadingDraw = true;
  List<dynamic> _gazetteDraws = [];
  bool _isLoadingGazette = true;

  @override
  void initState() {
    super.initState();
    _fetchHomeDrawData();
  }

  Future<void> _fetchHomeDrawData() async {
    try {
      final scheduleList = await ApiService.fetchDrawSchedule(
        widget.accessToken,
      );
      if (scheduleList != null && scheduleList.isNotEmpty && mounted) {
        setState(() {
          _nextDraw = Map<String, dynamic>.from(scheduleList.first);
        });
      }

      final gazettes = await ApiService.fetchUserDrawlists(widget.accessToken);
      if (gazettes != null && mounted) {
        setState(() {
          _gazetteDraws = gazettes;
        });
      }
    } catch (_) {
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingDraw = false;
          _isLoadingGazette = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Greeting Section
          Text(
            'ASSALAM-O-ALAIKUM',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
              color: isDark
                  ? const Color(0xFF80BEA6)
                  : AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Welcome back, ${widget.fullName}',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : AppColors.primary,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 16),

          // Verification Notice Banner
          if (!widget.isVerified) ...[
            AppCard(
              color: isDark
                  ? Colors.amber.shade900.withValues(alpha: 0.2)
                  : Colors.amber.shade50,
              padding: const EdgeInsets.all(14),
              border: Border.all(
                color: isDark
                    ? Colors.amber.shade800.withValues(alpha: 0.4)
                    : Colors.amber.shade200,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade500.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text('⏳', style: TextStyle(fontSize: 16)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Verification Under Review',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isDark
                                    ? Colors.amber.shade200
                                    : const Color(0xFF78350F),
                              ),
                            ),
                            AppBadge(
                              label: 'ETA 24-48 hrs',
                              type: AppBadgeType.warning,
                              isSmall: true,
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Your account is currently pending approval. Some features may not be available',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark
                                ? Colors.amber.shade100
                                : const Color(0xFF92400E),
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Hero Portfolio Card
          AppCard(
            padding: const EdgeInsets.all(20),
            borderRadius: 24,
            gradient: const LinearGradient(
              colors: [Color(0xFF0F5132), Color(0xFF0A3622), Color(0xFF022C22)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            elevation: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'TOTAL BOND VALUE',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                        color: Color(0xFFD1FAE5),
                      ),
                    ),
                    AppBadge.verified(isVerified: widget.isVerified),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    const Text(
                      'Rs ',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white70,
                      ),
                    ),
                    Text(
                      widget.isLoading
                          ? '...'
                          : widget.formatNumber(widget.totalAssets),
                      style: const TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Explore Services Section
          AppSectionHeader(
            title: 'What would you like to do?',
            tagline: 'EXPLORE SERVICES',
            action: const Icon(
              Icons.auto_awesome,
              color: AppColors.secondaryContainer,
              size: 20,
            ),
          ),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: Responsive.isMobile(context)
                ? (MediaQuery.orientationOf(context) == Orientation.landscape
                      ? 3
                      : 2)
                : Responsive.gridColumns(
                    context,
                    mobile: 2,
                    tablet: 3,
                    desktop: 4,
                  ),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio:
                MediaQuery.orientationOf(context) == Orientation.landscape
                ? 3.0
                : 2.2,
            children: [
              _buildExploreCard(
                context,
                'Search Bonds',
                'Check bond status',
                Icons.search,
                AppColors.success,
                true,
                () => widget.onNavigate(1),
              ),
              _buildExploreCard(
                context,
                'My Bonds',
                'Manage your portfolio',
                Icons.account_balance_wallet_outlined,
                const Color(0xFF3B82F6),
                widget.isVerified,
                () => widget.onNavigate(2),
              ),
              _buildExploreCard(
                context,
                'Draw Results',
                'Official gazette results',
                Icons.military_tech_outlined,
                AppColors.warning,
                widget.isVerified,
                () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          DrawListsScreen(accessToken: widget.accessToken),
                    ),
                  );
                },
              ),
              _buildExploreCard(
                context,
                'Market',
                'Current bond prices',
                Icons.storefront_outlined,
                const Color(0xFF8B5CF6),
                widget.isVerified,
                () => widget.onNavigate(3),
              ),
              _buildExploreCard(
                context,
                'Draw Schedule',
                'Upcoming draws',
                Icons.calendar_today_outlined,
                const Color(0xFFEC4899),
                widget.isVerified,
                () => widget.onNavigate(4),
              ),
              _buildExploreCard(
                context,
                'Reports',
                'Portfolio insights',
                Icons.description_outlined,
                const Color(0xFF14B8A6),
                widget.isVerified,
                () => widget.onNavigate(2),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Dynamic Upcoming Draw Banner
          if (_isLoadingDraw)
            const SizedBox.shrink()
          else if (_nextDraw != null) ...[
            Builder(
              builder: (context) {
                final rawLocation =
                    (_nextDraw!['location'] ??
                            _nextDraw!['city'] ??
                            _nextDraw!['draw_location'] ??
                            '')
                        .toString()
                        .trim();
                final drawLocation = rawLocation.isNotEmpty
                    ? rawLocation
                    : 'SBP';

                return AppCard(
                  padding: const EdgeInsets.all(14),
                  color: isDark
                      ? Colors.amber.shade900.withValues(alpha: 0.15)
                      : Colors.amber.shade50,
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade500.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.access_time,
                          color: Colors.amber.shade800,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.shade200.withValues(
                                      alpha: 0.6,
                                    ),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'NEXT DRAW',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF78350F),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _nextDraw!['draw_date']?.toString() ??
                                      _nextDraw!['date']?.toString() ??
                                      'Upcoming',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Rs. ${_nextDraw!['denomination'] ?? _nextDraw!['bond_type'] ?? '1500'} Draw • $drawLocation',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                      ),
                      AppBadge(
                        label: 'Upcoming',
                        type: AppBadgeType.warning,
                        isSmall: true,
                      ),
                    ],
                  ),
                );
              },
            ),
          ] else
            AppCard(
              padding: const EdgeInsets.all(14),
              color: isDark
                  ? Colors.amber.shade900.withValues(alpha: 0.15)
                  : Colors.amber.shade50,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade500.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.event_busy,
                      color: Colors.amber.shade800,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'No Upcoming Draws Found',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Check back later for official SBP gazette schedules.',
                          style: TextStyle(
                            fontSize: 10,
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
            ),

          // Official Gazette Draw Lists Section on Home Screen
          const SizedBox(height: 24),
          AppSectionHeader(
            title: 'Official Gazette Draw Lists',
            tagline: 'LATEST RESULTS',
            action: TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        DrawListsScreen(accessToken: widget.accessToken),
                  ),
                );
              },
              child: const Text(
                'View All →',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (_isLoadingGazette)
            const AppLoadingIndicator(message: 'Fetching gazette results...')
          else if (_gazetteDraws.isEmpty)
            const AppEmptyState(
              icon: Icons.description_outlined,
              title: 'No Draw Lists Available',
              message:
                  'No official gazette draw lists have been published yet.',
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _gazetteDraws.length > 3 ? 3 : _gazetteDraws.length,
              itemBuilder: (context, index) {
                final draw = _gazetteDraws[index];
                final drawId = draw['draw_id']?.toString() ?? '';
                final denomination = draw['denomination'] as int? ?? 0;
                final drawDate = draw['draw_date']?.toString() ?? 'N/A';
                final winnerCount = draw['winner_count'] as int? ?? 0;

                return VibrantDrawCard(
                  drawId: drawId,
                  denomination: denomination,
                  drawDate: drawDate,
                  winnerCount: winnerCount,
                  accessToken: widget.accessToken,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => DrawDetailScreen(
                          drawId: drawId,
                          denomination: denomination,
                          drawDate: drawDate,
                          winnerCount: winnerCount,
                          accessToken: widget.accessToken,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildExploreCard(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    Color color,
    bool isAllowed,
    VoidCallback onTap,
  ) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      onTap: () {
        if (!isAllowed) {
          showAppToast(
            context,
            'Feature locked: $title requires account verification.',
            type: AppNotificationType.warning,
          );
          return;
        }
        onTap();
      },
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 9.5,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          Icon(
            Icons.chevron_right,
            size: 14,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ],
      ),
    );
  }
}
