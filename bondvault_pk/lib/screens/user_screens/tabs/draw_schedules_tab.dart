import 'package:flutter/material.dart';

import '../../../config/app_theme.dart';
import '../../../config/responsive.dart';
import '../../../utils/api_service.dart';
import '../../../widgets/widgets.dart';

class DrawSchedulesTab extends StatefulWidget {
  final String? accessToken;

  const DrawSchedulesTab({super.key, this.accessToken});

  @override
  State<DrawSchedulesTab> createState() => _DrawSchedulesTabState();
}

class _DrawSchedulesTabState extends State<DrawSchedulesTab> {
  bool _isLoading = true;
  List<dynamic> _schedules = [];

  @override
  void initState() {
    super.initState();
    _fetchSchedules();
  }

  Future<void> _fetchSchedules() async {
    setState(() => _isLoading = true);
    try {
      final list = await ApiService.fetchDrawSchedule(widget.accessToken);
      if (list != null && mounted) {
        setState(() {
          _schedules = list;
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: _isLoading
          ? const AppLoadingIndicator(
              message: 'Fetching upcoming draw schedules...',
            )
          : RefreshIndicator(
              onRefresh: _fetchSchedules,
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
                        const AppSectionHeader(
                          title: 'Upcoming Draw Schedules',
                          tagline: 'STATE BANK GAZETTE',
                        ),
                        const SizedBox(height: 12),
                        _schedules.isEmpty
                            ? const AppEmptyState(
                                icon: Icons.event_busy,
                                title: 'No Upcoming Draws Found',
                                message: 'No upcoming draw schedules match current records.',
                              )
                            : ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _schedules.length,
                                itemBuilder: (context, index) {
                                  final item = _schedules[index];
                                  final denomination =
                                      item['denomination'] ??
                                      item['bond_type'] ??
                                      '1500';
                                  final drawDate =
                                      item['draw_date'] ??
                                      item['date'] ??
                                      'Upcoming';
                                  final rawLocation =
                                      (item['location'] ??
                                              item['city'] ??
                                              item['draw_location'] ??
                                              item['venue'] ??
                                              '')
                                          .toString()
                                          .trim();
                                  final location = rawLocation.isNotEmpty
                                      ? rawLocation
                                      : 'SBP';
                                  final drawNo =
                                      item['draw_number'] ??
                                      item['draw_no'] ??
                                      '';

                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: AppCard(
                                      padding: const EdgeInsets.all(16),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 44,
                                            height: 44,
                                            decoration: BoxDecoration(
                                              color: AppColors.primaryContainer,
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: const Icon(
                                              Icons.event,
                                              color: Colors.white,
                                            ),
                                          ),
                                          const SizedBox(width: 14),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'Rs. $denomination Prize Bond Draw ${drawNo.toString().isNotEmpty ? '#$drawNo' : ''}',
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.bold,
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .onSurface,
                                                  ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  'Date: $drawDate | Location: $location',
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
                                          const SizedBox(width: 8),
                                          Flexible(
                                            child: FittedBox(
                                              fit: BoxFit.scaleDown,
                                              alignment: Alignment.centerRight,
                                              child: AppBadge(
                                                label: 'Upcoming',
                                                type: AppBadgeType.info,
                                                isSmall: true,
                                              ),
                                            ),
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
    );
  }
}
