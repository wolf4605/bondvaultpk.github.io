import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../config/app_config.dart';
import '../../config/app_theme.dart';
import '../../utils/api_service.dart';
import '../../utils/user_notification_monitor.dart';
import '../../widgets/widgets.dart';
import '../login_screen.dart';
import 'admin_audit_logs_screen.dart';
import 'admin_draws_screen.dart';
import 'admin_management_screen.dart';
import 'admin_market_screen.dart';
import 'admin_reports_screen.dart';
import 'admin_settings_screen.dart';
import 'admin_users_screen.dart';

class PieChartPainter extends CustomPainter {
  final int verified;
  final int pending;
  final int suspended;

  PieChartPainter({
    required this.verified,
    required this.pending,
    required this.suspended,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final total = (verified + pending + suspended) > 0
        ? (verified + pending + suspended)
        : 1;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    const strokeWidth = 14.0;
    final rect = Rect.fromCircle(
      center: center,
      radius: radius - strokeWidth / 2,
    );

    final bgPaint = Paint()
      ..color = Colors.grey.shade200
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    canvas.drawCircle(center, radius - strokeWidth / 2, bgPaint);

    double startAngle = -0.5 * 3.1415926535; // Start at top

    // Draw Verified (Green)
    if (verified > 0) {
      final sweepAngle = (verified / total) * 2 * 3.1415926535;
      final paint = Paint()
        ..color = AppColors.success
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = strokeWidth;
      canvas.drawArc(rect, startAngle, sweepAngle, false, paint);
      startAngle += sweepAngle;
    }

    // Draw Pending (Amber)
    if (pending > 0) {
      final sweepAngle = (pending / total) * 2 * 3.1415926535;
      final paint = Paint()
        ..color = AppColors.warning
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = strokeWidth;
      canvas.drawArc(rect, startAngle, sweepAngle, false, paint);
      startAngle += sweepAngle;
    }

    // Draw Suspended (Red)
    if (suspended > 0) {
      final sweepAngle = (suspended / total) * 2 * 3.1415926535;
      final paint = Paint()
        ..color = AppColors.error
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = strokeWidth;
      canvas.drawArc(rect, startAngle, sweepAngle, false, paint);
    }
  }

  @override
  bool shouldRepaint(covariant PieChartPainter oldDelegate) => true;
}

class MarketplaceDonutPainter extends CustomPainter {
  final int buyCount;
  final int sellCount;

  MarketplaceDonutPainter({required this.buyCount, required this.sellCount});

  @override
  void paint(Canvas canvas, Size size) {
    final total = (buyCount + sellCount) > 0 ? (buyCount + sellCount) : 1;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    const strokeWidth = 14.0;
    final rect = Rect.fromCircle(
      center: center,
      radius: radius - strokeWidth / 2,
    );

    final bgPaint = Paint()
      ..color = Colors.grey.shade200
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    canvas.drawCircle(center, radius - strokeWidth / 2, bgPaint);

    double startAngle = -0.5 * 3.1415926535; // Start at top

    // Draw Buy Offers (Green)
    if (buyCount > 0) {
      final sweepAngle = (buyCount / total) * 2 * 3.1415926535;
      final paint = Paint()
        ..color = AppColors.success
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = strokeWidth;
      canvas.drawArc(rect, startAngle, sweepAngle, false, paint);
      startAngle += sweepAngle;
    }

    // Draw Sell Offers (Orange)
    if (sellCount > 0) {
      final sweepAngle = (sellCount / total) * 2 * 3.1415926535;
      final paint = Paint()
        ..color = Colors.orange.shade700
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = strokeWidth;
      canvas.drawArc(rect, startAngle, sweepAngle, false, paint);
    }
  }

  @override
  bool shouldRepaint(covariant MarketplaceDonutPainter oldDelegate) => true;
}

class SupportTicketsDonutPainter extends CustomPainter {
  final int openCount;
  final int inProgressCount;
  final int closedCount;

  SupportTicketsDonutPainter({
    required this.openCount,
    required this.inProgressCount,
    required this.closedCount,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final total = (openCount + inProgressCount + closedCount) > 0
        ? (openCount + inProgressCount + closedCount)
        : 1;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    const strokeWidth = 14.0;
    final rect = Rect.fromCircle(
      center: center,
      radius: radius - strokeWidth / 2,
    );

    final bgPaint = Paint()
      ..color = Colors.grey.shade200
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    canvas.drawCircle(center, radius - strokeWidth / 2, bgPaint);

    double startAngle = -0.5 * 3.1415926535; // Start at top

    // 1. Draw Open (Green)
    if (openCount > 0) {
      final sweepAngle = (openCount / total) * 2 * 3.1415926535;
      final paint = Paint()
        ..color = Colors.green
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = strokeWidth;
      canvas.drawArc(rect, startAngle, sweepAngle, false, paint);
      startAngle += sweepAngle;
    }

    // 2. Draw In Progress (Amber)
    if (inProgressCount > 0) {
      final sweepAngle = (inProgressCount / total) * 2 * 3.1415926535;
      final paint = Paint()
        ..color = Colors.amber
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = strokeWidth;
      canvas.drawArc(rect, startAngle, sweepAngle, false, paint);
      startAngle += sweepAngle;
    }

    // 3. Draw Closed (Teal)
    if (closedCount > 0) {
      final sweepAngle = (closedCount / total) * 2 * 3.1415926535;
      final paint = Paint()
        ..color = Colors.teal
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = strokeWidth;
      canvas.drawArc(rect, startAngle, sweepAngle, false, paint);
    }
  }

  @override
  bool shouldRepaint(covariant SupportTicketsDonutPainter oldDelegate) => true;
}

class DrawsRadialGaugePainter extends CustomPainter {
  final int gazettes;
  final int upcoming;

  DrawsRadialGaugePainter({required this.gazettes, required this.upcoming});

  @override
  void paint(Canvas canvas, Size size) {
    final maxVal = (gazettes > upcoming ? gazettes : upcoming);
    final safeMax = maxVal > 0 ? maxVal : 1;

    final center = Offset(size.width / 2, size.height / 2);

    final bgPaint = Paint()
      ..color = Colors.grey.shade200
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10.0;

    // Outer Gauge - Imported Gazettes
    final outerRadius = size.width / 2 - 6;
    final outerRect = Rect.fromCircle(center: center, radius: outerRadius);
    canvas.drawCircle(center, outerRadius, bgPaint);

    final outerSweep =
        (gazettes / safeMax).clamp(0.15, 1.0) * 1.5 * 3.1415926535;
    final outerPaint = Paint()
      ..color = const Color(0xFF0F5132)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 10.0;
    canvas.drawArc(
      outerRect,
      -0.75 * 3.1415926535,
      outerSweep,
      false,
      outerPaint,
    );

    // Inner Gauge - Upcoming Schedules
    final innerRadius = size.width / 2 - 22;
    final innerRect = Rect.fromCircle(center: center, radius: innerRadius);
    canvas.drawCircle(center, innerRadius, bgPaint);

    final innerSweep =
        (upcoming / safeMax).clamp(0.15, 1.0) * 1.5 * 3.1415926535;
    final innerPaint = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 10.0;
    canvas.drawArc(
      innerRect,
      -0.75 * 3.1415926535,
      innerSweep,
      false,
      innerPaint,
    );
  }

  @override
  bool shouldRepaint(covariant DrawsRadialGaugePainter oldDelegate) => true;
}

class LineChartPainter extends CustomPainter {
  final List<int> counts;
  final Color lineColor;
  final Color fillColor;

  LineChartPainter({
    required this.counts,
    required this.lineColor,
    required this.fillColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (counts.isEmpty) return;

    final maxVal = counts.reduce((a, b) => a > b ? a : b);
    final safeMax = maxVal > 0 ? maxVal : 1;

    final double stepX = size.width / (counts.length - 1);
    const double paddingY = 8.0;
    final double availableHeight = size.height - paddingY * 2;

    final List<Offset> points = [];
    for (int i = 0; i < counts.length; i++) {
      final x = i * stepX;
      final y =
          size.height - paddingY - ((counts[i] / safeMax) * availableHeight);
      points.add(Offset(x, y));
    }

    // 1. Draw Gradient Area under Line
    final Path areaPath = Path()..moveTo(0, size.height);
    for (final pt in points) {
      areaPath.lineTo(pt.dx, pt.dy);
    }
    areaPath.lineTo(size.width, size.height);
    areaPath.close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          fillColor.withValues(alpha: 0.35),
          fillColor.withValues(alpha: 0.0),
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawPath(areaPath, fillPaint);

    // 2. Draw Smooth Connected Cubic Line
    final Path linePath = Path()..moveTo(points[0].dx, points[0].dy);
    for (int i = 1; i < points.length; i++) {
      final p0 = points[i - 1];
      final p1 = points[i];
      final controlPt1 = Offset(p0.dx + stepX / 2, p0.dy);
      final controlPt2 = Offset(p1.dx - stepX / 2, p1.dy);
      linePath.cubicTo(
        controlPt1.dx,
        controlPt1.dy,
        controlPt2.dx,
        controlPt2.dy,
        p1.dx,
        p1.dy,
      );
    }

    final strokePaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(linePath, strokePaint);

    // 3. Draw Glowing Node Dots
    for (int i = 0; i < points.length; i++) {
      final pt = points[i];
      final isToday = i == points.length - 1;

      final outerDot = Paint()
        ..color = isToday ? AppColors.success : lineColor
        ..style = PaintingStyle.fill;

      final innerDot = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;

      canvas.drawCircle(pt, isToday ? 5.5 : 4.0, outerDot);
      canvas.drawCircle(pt, isToday ? 2.5 : 1.8, innerDot);
    }
  }

  @override
  bool shouldRepaint(covariant LineChartPainter oldDelegate) => true;
}

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

  // Metrics for Dashboard
  int _totalDraws = 0;
  int _upcomingDrawsCount = 0;

  int _totalTickets = 0;
  int _openTicketsCount = 0;
  int _inProgressTicketsCount = 0;
  int _closedTicketsCount = 0;

  int _totalMarketListings = 0;
  int _buyListingsCount = 0;
  int _sellListingsCount = 0;

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

  List<int> get _last7DaysRegistrations {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final counts = List<int>.filled(7, 0);

    for (final u in _usersList) {
      final createdAtStr = u['created_at'];
      if (createdAtStr != null) {
        try {
          final dt = DateTime.parse(createdAtStr.toString());
          final userDate = DateTime(dt.year, dt.month, dt.day);
          final diffInDays = today.difference(userDate).inDays;
          if (diffInDays >= 0 && diffInDays < 7) {
            counts[6 - diffInDays]++;
          }
        } catch (_) {}
      }
    }
    return counts;
  }

  @override
  void initState() {
    super.initState();
    UserNotificationMonitor.stop();
    _fetchAdminData();
  }

  Future<void> _fetchAdminData() async {
    setState(() {
      _isLoadingStats = true;
      _isLoadingUsers = true;
    });

    try {
      // 1. Fetch Registered Users Count
      final activeRes = await http.get(
        Uri.parse('${AppConfig.baseUrl}${AppConfig.activeUsersEndpoint}'),
        headers: {'Authorization': 'Bearer ${widget.accessToken}'},
      );
      if (activeRes.statusCode == 200) {
        final activeData = jsonDecode(activeRes.body);
        _totalUsers = activeData['total_registered_users'] ?? 0;
      }

      // 2. Fetch Blacklist
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

      // 3. Fetch All Users List
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
          map['blacklist_reason'] =
              blacklistReasonMap[email] ??
              blacklistReasonMap[contact] ??
              blacklistReasonMap[id] ??
              'Account suspended by administrator.';
          return map;
        }).toList();
      }

      // 4. Fetch Support Tickets
      final reports = await ApiService.fetchAdminReports(
        accessToken: widget.accessToken,
        statusFilter: 'all',
      );
      if (reports != null) {
        _totalTickets = reports.length;
        int open = 0;
        int inProg = 0;
        int closed = 0;
        for (final r in reports) {
          final st = r['status']?.toString().toLowerCase();
          if (st == 'open') {
            open++;
          } else if (st == 'in_progress') {
            inProg++;
          } else if (st == 'closed') {
            closed++;
          }
        }
        _openTicketsCount = open;
        _inProgressTicketsCount = inProg;
        _closedTicketsCount = closed;
      }

      // 5. Fetch Drawlists & Schedules
      final drawlists = await ApiService.fetchUserDrawlists(
        widget.accessToken,
        isAdmin: true,
      );
      if (drawlists != null) {
        _totalDraws = drawlists.length;
      }

      final upcomingDraws = await ApiService.fetchDrawSchedule(
        accessToken: widget.accessToken,
        isAdmin: true,
      );
      if (upcomingDraws != null) {
        _upcomingDrawsCount = upcomingDraws.length;
      }

      // 6. Fetch Marketplace Listings
      final marketListings = await ApiService.fetchAdminMarketListings(
        widget.accessToken,
      );
      if (marketListings != null) {
        _totalMarketListings = marketListings.length;
        int buy = 0;
        int sell = 0;
        for (final m in marketListings) {
          final cat = m['category']?.toString().toLowerCase();
          if (cat == 'buy') {
            buy++;
          } else if (cat == 'sell') {
            sell++;
          }
        }
        _buyListingsCount = buy;
        _sellListingsCount = sell;
      }

      // 7. Fetch Recent Audit Logs
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
    await prefs.remove('cached_access_token');
    await prefs.remove('cached_user_info');

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  Widget _buildSubStatusCard(String name, String status, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              name,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            status,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
            ),
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
                  color: AppColors.secondaryContainer,
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
      ),
    );
  }

  Widget _buildUserStatusPieChart() {
    int verifiedCount = 0;
    int unverifiedCount = 0;
    int suspendedCount = 0;

    for (final u in _usersList) {
      final isBlacklisted = u['is_blacklisted'] == true;
      final isVerified = u['is_verified'] == true;
      if (isBlacklisted) {
        suspendedCount++;
      } else if (isVerified) {
        verifiedCount++;
      } else {
        unverifiedCount++;
      }
    }

    final total = _totalUsers > 0
        ? _totalUsers
        : (verifiedCount + unverifiedCount + suspendedCount);
    final safeTotal = total > 0 ? total : 1;

    final verifiedPct = ((verifiedCount / safeTotal) * 100).toStringAsFixed(1);
    final unverifiedPct = ((unverifiedCount / safeTotal) * 100).toStringAsFixed(
      1,
    );
    final suspendedPct = ((suspendedCount / safeTotal) * 100).toStringAsFixed(
      1,
    );

    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: const [
                  Icon(
                    Icons.donut_large_outlined,
                    size: 18,
                    color: AppColors.primary,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'USER VERIFICATION & STATUS DISTRIBUTION',
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
                label: '$verifiedPct% Verified',
                type: AppBadgeType.success,
                isSmall: true,
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Donut Ring Chart with Center Metric
          Row(
            children: [
              SizedBox(
                width: 100,
                height: 100,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CustomPaint(
                      size: const Size(100, 100),
                      painter: PieChartPainter(
                        verified: verifiedCount,
                        pending: unverifiedCount,
                        suspended: suspendedCount,
                      ),
                    ),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '$total',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: AppColors.primary,
                          ),
                        ),
                        const Text(
                          'USERS',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 24),

              // Legend
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStatusLegendRow(
                      'Verified Users',
                      '$verifiedCount ($verifiedPct%)',
                      AppColors.success,
                    ),
                    const SizedBox(height: 8),
                    _buildStatusLegendRow(
                      'Pending Review',
                      '$unverifiedCount ($unverifiedPct%)',
                      AppColors.warning,
                    ),
                    const SizedBox(height: 8),
                    _buildStatusLegendRow(
                      'Suspended / Banned',
                      '$suspendedCount ($suspendedPct%)',
                      AppColors.error,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusLegendRow(String label, String value, Color color) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: AppColors.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildUserTrendLineChart() {
    final dailyCounts = _last7DaysRegistrations;

    final now = DateTime.now();
    final dayLabels = List.generate(7, (i) {
      final dt = now.subtract(Duration(days: 6 - i));
      if (i == 6) return 'Today';
      if (i == 5) return 'Yest.';
      return '${dt.day}/${dt.month}';
    });

    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: const [
                  Icon(Icons.show_chart, size: 18, color: AppColors.primary),
                  SizedBox(width: 8),
                  Text(
                    'NEW USER REGISTRATION TREND (7 DAYS)',
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
                label: '+$_newUsersCount Total',
                type: AppBadgeType.success,
                isSmall: true,
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Line Chart Canvas Container
          SizedBox(
            height: 120,
            child: Column(
              children: [
                // Top Values Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: List.generate(7, (i) {
                    final count = dailyCounts[i];
                    return SizedBox(
                      width: 32,
                      child: Text(
                        '+$count',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: count > 0 ? AppColors.primary : Colors.grey,
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 6),

                // Custom Painted Line Chart Graph
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: CustomPaint(
                      size: const Size(double.infinity, double.infinity),
                      painter: LineChartPainter(
                        counts: dailyCounts,
                        lineColor: AppColors.primary,
                        fillColor: AppColors.primaryContainer,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // Bottom Day Labels Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: List.generate(7, (i) {
                    final isToday = i == 6;
                    return SizedBox(
                      width: 38,
                      child: Text(
                        dayLabels[i],
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: isToday
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: isToday
                              ? AppColors.primary
                              : AppColors.onSurfaceVariant,
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTicketsResolutionChart() {
    final total = _totalTickets > 0
        ? _totalTickets
        : (_openTicketsCount + _inProgressTicketsCount + _closedTicketsCount);
    final safeTotal = total > 0 ? total : 1;

    final resolutionRate = _totalTickets > 0
        ? ((_closedTicketsCount / _totalTickets) * 100).toStringAsFixed(1)
        : '0.0';

    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: const [
                  Icon(
                    Icons.pie_chart_outline,
                    size: 18,
                    color: AppColors.primary,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'SUPPORT TICKETS RESOLUTION DONUT CHART',
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
                label: '$resolutionRate% Closed',
                type: AppBadgeType.success,
                isSmall: true,
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Donut Ring Chart with Center Metric
          Row(
            children: [
              SizedBox(
                width: 100,
                height: 100,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CustomPaint(
                      size: const Size(100, 100),
                      painter: SupportTicketsDonutPainter(
                        openCount: _openTicketsCount,
                        inProgressCount: _inProgressTicketsCount,
                        closedCount: _closedTicketsCount,
                      ),
                    ),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '$total',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: AppColors.primary,
                          ),
                        ),
                        const Text(
                          'TICKETS',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 24),

              // Legend
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStatusLegendRow(
                      'Open Tickets',
                      '$_openTicketsCount (${((_openTicketsCount / safeTotal) * 100).toStringAsFixed(1)}%)',
                      Colors.green,
                    ),
                    const SizedBox(height: 8),
                    _buildStatusLegendRow(
                      'In Progress',
                      '$_inProgressTicketsCount (${((_inProgressTicketsCount / safeTotal) * 100).toStringAsFixed(1)}%)',
                      Colors.amber,
                    ),
                    const SizedBox(height: 8),
                    _buildStatusLegendRow(
                      'Closed',
                      '$_closedTicketsCount (${((_closedTicketsCount / safeTotal) * 100).toStringAsFixed(1)}%)',
                      Colors.teal,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDrawsOverviewChart() {
    final totalDrawsAll = _totalDraws + _upcomingDrawsCount;

    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: const [
                  Icon(
                    Icons.speed_outlined,
                    size: 18,
                    color: AppColors.primary,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'GAZETTE & SCHEDULE RADIAL GAUGE',
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
                label: '$totalDrawsAll Draws Total',
                type: AppBadgeType.info,
                isSmall: true,
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Dual Concentric Radial Gauge Chart
          Row(
            children: [
              SizedBox(
                width: 100,
                height: 100,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CustomPaint(
                      size: const Size(100, 100),
                      painter: DrawsRadialGaugePainter(
                        gazettes: _totalDraws,
                        upcoming: _upcomingDrawsCount,
                      ),
                    ),
                    const Icon(
                      Icons.military_tech_outlined,
                      color: AppColors.primary,
                      size: 26,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 24),

              // Legend
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStatusLegendRow(
                      'Imported Gazettes',
                      '$_totalDraws',
                      const Color(0xFF0F5132),
                    ),
                    const SizedBox(height: 12),
                    _buildStatusLegendRow(
                      'Upcoming Schedules',
                      '$_upcomingDrawsCount',
                      AppColors.primary,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMarketplaceRatioBar() {
    final total = _totalMarketListings > 0
        ? _totalMarketListings
        : (_buyListingsCount + _sellListingsCount);
    final safeTotal = total > 0 ? total : 1;

    final buyPct = ((_buyListingsCount / safeTotal) * 100).toStringAsFixed(1);
    final sellPct = ((_sellListingsCount / safeTotal) * 100).toStringAsFixed(1);

    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: const [
                  Icon(
                    Icons.donut_small_outlined,
                    size: 18,
                    color: AppColors.primary,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'MARKETPLACE BUY vs SELL DONUT CHART',
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
                label: '$_totalMarketListings Posts',
                type: AppBadgeType.info,
                isSmall: true,
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Donut Ring Chart with Center Metric
          Row(
            children: [
              SizedBox(
                width: 100,
                height: 100,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CustomPaint(
                      size: const Size(100, 100),
                      painter: MarketplaceDonutPainter(
                        buyCount: _buyListingsCount,
                        sellCount: _sellListingsCount,
                      ),
                    ),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '$total',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: AppColors.primary,
                          ),
                        ),
                        const Text(
                          'OFFERS',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 24),

              // Legend
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStatusLegendRow(
                      'Buy Offers',
                      '$_buyListingsCount ($buyPct%)',
                      AppColors.success,
                    ),
                    const SizedBox(height: 12),
                    _buildStatusLegendRow(
                      'Sell Offers',
                      '$_sellListingsCount ($sellPct%)',
                      Colors.orange.shade700,
                    ),
                  ],
                ),
              ),
            ],
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
    return AdminMarketScreen(accessToken: widget.accessToken);
  }

  Widget _buildDrawsView() {
    return AdminDrawsScreen(accessToken: widget.accessToken);
  }

  Widget _buildSettingsView() {
    return AdminSettingsScreen(
      accessToken: widget.accessToken,
      adminInfo: widget.adminInfo,
      onLogout: _logout,
    );
  }

  Widget _buildOverviewView(String greetingName, String fullName) {
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
            title: 'Assalam-o-Alaikum, $greetingName',
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
                    Flexible(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(
                            Icons.dns_outlined,
                            size: 18,
                            color: AppColors.primary,
                          ),
                          SizedBox(width: 8),
                          Flexible(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'CORE INFRASTRUCTURE STATUS',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.0,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    AppBadge(
                      label: 'NORMAL',
                      type: AppBadgeType.success,
                      isSmall: true,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isNarrow = constraints.maxWidth < 340;
                    final card1 = _buildSubStatusCard(
                      'Backend API',
                      'Live',
                      AppColors.success,
                    );
                    final card2 = _buildSubStatusCard(
                      'Database (PG)',
                      'OK',
                      AppColors.success,
                    );
                    final card3 = _buildSubStatusCard(
                      'Redis (Cache)',
                      'Active',
                      AppColors.success,
                    );

                    if (isNarrow) {
                      final itemWidth = (constraints.maxWidth - 8) / 2;
                      return Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          SizedBox(width: itemWidth, child: card1),
                          SizedBox(width: itemWidth, child: card2),
                          SizedBox(width: constraints.maxWidth, child: card3),
                        ],
                      );
                    }

                    return Row(
                      children: [
                        Expanded(child: card1),
                        const SizedBox(width: 6),
                        Expanded(child: card2),
                        const SizedBox(width: 6),
                        Expanded(child: card3),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // User Overview Header
          const AppSectionHeader(
            title: 'Executive Platform Analytics',
            tagline: 'METRICS & KPIS',
          ),
          const SizedBox(height: 12),

          // Stat Cards Grid
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 340;
              final stat1 = AppStatCard(
                title: 'Total Users',
                value: _isLoadingStats ? '...' : '$_totalUsers',
                icon: Icons.person_outline,
                subtitle: 'Registered',
                iconColor: Colors.blue,
              );
              final stat2 = AppStatCard(
                title: 'New (7d)',
                value: _isLoadingUsers ? '...' : '+$_newUsersCount',
                icon: Icons.person_add_outlined,
                subtitle: 'Onboarded',
                iconColor: Colors.teal,
              );
              final stat3 = AppStatCard(
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
              );

              if (isNarrow) {
                final itemWidth = (constraints.maxWidth - 8) / 2;
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    SizedBox(width: itemWidth, child: stat1),
                    SizedBox(width: itemWidth, child: stat2),
                    SizedBox(width: constraints.maxWidth, child: stat3),
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: stat1),
                  const SizedBox(width: 6),
                  Expanded(child: stat2),
                  const SizedBox(width: 6),
                  Expanded(child: stat3),
                ],
              );
            },
          ),
          const SizedBox(height: 16),

          // Support & Draws KPI Stat Cards
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 340;
              final statDraws = AppStatCard(
                title: 'Gazette Draws',
                value: _isLoadingStats ? '...' : '$_totalDraws',
                icon: Icons.library_books_outlined,
                subtitle: '$_upcomingDrawsCount Upcoming',
                iconColor: AppColors.primary,
                onTap: () => setState(() => _currentIndex = 3),
              );
              final statTickets = AppStatCard(
                title: 'Support Tickets',
                value: _isLoadingStats ? '...' : '$_totalTickets',
                icon: Icons.support_agent_outlined,
                subtitle: '$_openTicketsCount Open',
                iconColor: Colors.purple,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          AdminReportsScreen(accessToken: widget.accessToken),
                    ),
                  );
                },
              );
              final statMarket = AppStatCard(
                title: 'Marketplace',
                value: _isLoadingStats ? '...' : '$_totalMarketListings',
                icon: Icons.storefront_outlined,
                subtitle: '$_buyListingsCount B / $_sellListingsCount S',
                iconColor: Colors.orange,
                onTap: () => setState(() => _currentIndex = 2),
              );

              if (isNarrow) {
                final itemWidth = (constraints.maxWidth - 8) / 2;
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    SizedBox(width: itemWidth, child: statDraws),
                    SizedBox(width: itemWidth, child: statTickets),
                    SizedBox(width: constraints.maxWidth, child: statMarket),
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: statDraws),
                  const SizedBox(width: 6),
                  Expanded(child: statTickets),
                  const SizedBox(width: 6),
                  Expanded(child: statMarket),
                ],
              );
            },
          ),
          const SizedBox(height: 24),

          // Interactive Visual Charts Section
          const AppSectionHeader(
            title: 'Visual Operations Analytics',
            tagline: 'CHARTS & BREAKDOWNS',
          ),
          const SizedBox(height: 12),

          _buildUserStatusPieChart(),
          const SizedBox(height: 14),

          _buildUserTrendLineChart(),
          const SizedBox(height: 14),

          _buildTicketsResolutionChart(),
          const SizedBox(height: 14),

          _buildDrawsOverviewChart(),
          const SizedBox(height: 14),

          _buildMarketplaceRatioBar(),
          const SizedBox(height: 24),

          // Recent Audit Logs Section
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

  @override
  Widget build(BuildContext context) {
    final firstName = widget.adminInfo['first_name']?.toString().trim() ?? '';
    final lastName = widget.adminInfo['last_name']?.toString().trim() ?? '';
    final username = widget.adminInfo['username']?.toString().trim() ?? 'Admin';
    final email =
        widget.adminInfo['email']?.toString().trim() ?? 'admin@bondvault.pk';

    final fullName = '$firstName $lastName'.trim().isEmpty
        ? username
        : '$firstName $lastName'.trim();
    final greetingName = firstName.isNotEmpty ? firstName : fullName;

    final List<Widget> adminViews = [
      _buildOverviewView(greetingName, fullName),
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
                Text(
                  'Dashboard',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
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
                  colors: [AppColors.primary, AppColors.primaryContainer],
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
                        children: const [
                          Text(
                            'BondVault ',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            'PK',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.secondaryContainer,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          fullName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      AppBadge.admin(),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '@$username • $email',
                    style: const TextStyle(fontSize: 11, color: Colors.white70),
                  ),
                  const SizedBox(height: 12),
                  // Quick System Status Card
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
                                color: AppColors.secondaryContainer.withValues(
                                  alpha: 0.2,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.person_outline,
                                color: AppColors.secondaryContainer,
                                size: 16,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _isLoadingStats ? '...' : '$_totalUsers Users',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        const Text(
                          'System: Live',
                          style: TextStyle(
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
                      'ADMIN CONTROL PANEL',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  _buildDrawerItem(
                    icon: Icons.grid_view_outlined,
                    title: 'Dashboard Overview',
                    isSelected: _currentIndex == 0,
                    onTap: () {
                      Navigator.pop(context);
                      setState(() => _currentIndex = 0);
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.shield_outlined,
                    title: 'Users Management',
                    isSelected: _currentIndex == 1,
                    onTap: () {
                      Navigator.pop(context);
                      setState(() => _currentIndex = 1);
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.security_outlined,
                    title: 'System Audit Logs',
                    isSelected: false,
                    onTap: () {
                      Navigator.pop(context);
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
                  _buildDrawerItem(
                    icon: Icons.admin_panel_settings_outlined,
                    title: 'Admin Accounts',
                    isSelected: false,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AdminManagementScreen(
                            accessToken: widget.accessToken,
                            adminInfo: widget.adminInfo,
                          ),
                        ),
                      );
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.storefront_outlined,
                    title: 'Market Management',
                    isSelected: _currentIndex == 2,
                    onTap: () {
                      Navigator.pop(context);
                      setState(() => _currentIndex = 2);
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.calendar_today_outlined,
                    title: 'Draw Result & Schedules',
                    isSelected: _currentIndex == 3,
                    onTap: () {
                      Navigator.pop(context);
                      setState(() => _currentIndex = 3);
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.support_agent_outlined,
                    title: 'User Support Tickets',
                    isSelected: false,
                    onTap: () {
                      Navigator.pop(context);
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
                  _buildDrawerItem(
                    icon: Icons.settings_outlined,
                    title: 'Admin Settings',
                    isSelected: _currentIndex == 4,
                    onTap: () {
                      Navigator.pop(context);
                      setState(() => _currentIndex = 4);
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
                child: AppButton(
                  label: 'Log Out',
                  variant: AppButtonVariant.danger,
                  icon: const Icon(Icons.logout, size: 18),
                  onPressed: _logout,
                ),
              ),
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
}
