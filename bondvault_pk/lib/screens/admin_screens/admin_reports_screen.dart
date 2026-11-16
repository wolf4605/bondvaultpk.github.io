import 'package:flutter/material.dart';

import '../../config/app_theme.dart';
import '../../config/responsive.dart';
import '../../utils/api_service.dart';
import '../../widgets/widgets.dart';
import '../report_chat_screen.dart';

class AdminReportsScreen extends StatefulWidget {
  final String accessToken;

  const AdminReportsScreen({super.key, required this.accessToken});

  @override
  State<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends State<AdminReportsScreen> {
  bool _isLoading = true;
  List<dynamic> _reports = [];

  String _statusFilter = 'all'; // 'all', 'open', 'in_progress', 'closed'
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _fetchReports();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchReports() async {
    setState(() => _isLoading = true);
    try {
      final list = await ApiService.fetchAdminReports(
        accessToken: widget.accessToken,
        statusFilter: _statusFilter,
      );
      if (list != null && mounted) {
        setState(() {
          _reports = list;
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _closeTicket(String reportId, String subject) async {
    showAppNotificationSheet(
      context: context,
      title: 'Close Support Ticket',
      message:
          'Are you sure you want to close ticket "$subject"? User will be notified via email.',
      type: AppNotificationType.warning,
      dismissLabel: 'Cancel',
      customAction: AppButton(
        label: 'Confirm Close Ticket',
        variant: AppButtonVariant.primary,
        onPressed: () async {
          Navigator.pop(context);
          try {
            final res = await ApiService.updateReportStatus(
              accessToken: widget.accessToken,
              reportId: reportId,
              status: 'closed',
            );
            if (!mounted) return;
            if (res.statusCode == 200) {
              _fetchReports();
              showAppNotificationSheet(
                context: context,
                title: 'Ticket Closed',
                message:
                    'Support ticket "$subject" closed successfully. User notified via email.',
                type: AppNotificationType.success,
              );
            }
          } catch (_) {}
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _reports.where((item) {
      final subject = item['subject']?.toString().toLowerCase() ?? '';
      final category = item['category']?.toString().toLowerCase() ?? '';
      final username = (item['reporter_username'] ?? '')
          .toString()
          .toLowerCase();
      final email = (item['reporter_email'] ?? '').toString().toLowerCase();

      final q = _searchQuery.toLowerCase().trim();
      bool matchesSearch =
          q.isEmpty ||
          subject.contains(q) ||
          category.contains(q) ||
          username.contains(q) ||
          email.contains(q);

      return matchesSearch;
    }).toList();

    int openCount = 0;
    int progressCount = 0;
    int closedCount = 0;
    for (final r in _reports) {
      final st = r['status']?.toString().toLowerCase();
      if (st == 'open') openCount++;
      if (st == 'in_progress') progressCount++;
      if (st == 'closed') closedCount++;
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'Support Tickets Moderation',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const AppLoadingIndicator(
              message: 'Loading user support tickets...',
            )
          : RefreshIndicator(
              onRefresh: _fetchReports,
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
                        // Stats Banner Card
                        AppCard(
                          padding: const EdgeInsets.all(18),
                          borderRadius: 20,
                          gradient: const LinearGradient(
                            colors: [Color(0xFF003527), Color(0xFF064E3B)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              Column(
                                children: [
                                  Text(
                                    '${_reports.length}',
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  const Text(
                                    'TOTAL TICKETS',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFFD1FAE5),
                                    ),
                                  ),
                                ],
                              ),
                              Container(
                                height: 30,
                                width: 1,
                                color: Colors.white24,
                              ),
                              Column(
                                children: [
                                  Text(
                                    '$openCount',
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  const Text(
                                    'OPEN',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFFD1FAE5),
                                    ),
                                  ),
                                ],
                              ),
                              Container(
                                height: 30,
                                width: 1,
                                color: Colors.white24,
                              ),
                              Column(
                                children: [
                                  Text(
                                    '$progressCount',
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  const Text(
                                    'IN PROGRESS',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFFD1FAE5),
                                    ),
                                  ),
                                ],
                              ),
                              Container(
                                height: 30,
                                width: 1,
                                color: Colors.white24,
                              ),
                              Column(
                                children: [
                                  Text(
                                    '$closedCount',
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  const Text(
                                    'CLOSED',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFFD1FAE5),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Search & Filter Header
                        const AppSectionHeader(
                          title: 'User Tickets & Inquiries',
                          tagline: 'ADMIN MODERATION',
                        ),
                        const SizedBox(height: 8),

                        AppTextField(
                          controller: _searchController,
                          labelText: 'Search Tickets',
                          hintText: 'e.g. subject or @username',
                          prefixIcon: const Icon(Icons.search),
                          onChanged: (v) => setState(() => _searchQuery = v),
                        ),
                        const SizedBox(height: 12),

                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: ['all', 'open', 'in_progress', 'closed']
                              .map((st) {
                                final isSelected = _statusFilter == st;
                                String label;
                                if (st == 'all') {
                                  label = 'All Tickets';
                                } else if (st == 'open') {
                                  label = 'Open';
                                } else if (st == 'in_progress') {
                                  label = 'In Progress';
                                } else {
                                  label = 'Closed';
                                }

                                return ChoiceChip(
                                  label: Text(label),
                                  selected: isSelected,
                                  selectedColor: AppColors.primary,
                                  labelStyle: TextStyle(
                                    color: isSelected
                                        ? Colors.white
                                        : AppColors.onSurface,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                  ),
                                  onSelected: (s) {
                                    if (s) {
                                      setState(() => _statusFilter = st);
                                      _fetchReports();
                                    }
                                  },
                                );
                              })
                              .toList(),
                        ),
                        const SizedBox(height: 16),

                        filtered.isEmpty
                            ? const AppEmptyState(
                                icon: Icons.support_agent_outlined,
                                title: 'No Support Tickets',
                                message: 'No user tickets match the selected status or search filter.',
                              )
                            : ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: filtered.length,
                                itemBuilder: (context, index) {
                                  final item = filtered[index];
                                  final reportId = item['id']?.toString() ?? '';
                                  final subject =
                                      item['subject']?.toString() ??
                                      'Support Ticket';
                                  final category =
                                      item['category']
                                          ?.toString()
                                          .toUpperCase() ??
                                      'GENERAL';
                                  final statusStr =
                                      item['status']
                                          ?.toString()
                                          .toLowerCase() ??
                                      'open';
                                  final username =
                                      item['reporter_username']?.toString() ??
                                      'User';
                                  final email =
                                      item['reporter_email']?.toString() ?? '';
                                  final createdAt =
                                      item['created_at']?.toString() ?? '';
                                  final msgCount =
                                      item['message_count'] as int? ?? 1;

                                  AppBadgeType badgeType;
                                  if (statusStr == 'closed') {
                                    badgeType = AppBadgeType.error;
                                  } else if (statusStr == 'in_progress') {
                                    badgeType = AppBadgeType.warning;
                                  } else {
                                    badgeType = AppBadgeType.success;
                                  }

                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: AppCard(
                                      padding: const EdgeInsets.all(16),
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                ReportChatScreen(
                                                  accessToken:
                                                      widget.accessToken,
                                                  report: item,
                                                  isAdmin: true,
                                                  onStatusChanged:
                                                      _fetchReports,
                                                ),
                                          ),
                                        );
                                      },
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              AppBadge(
                                                label: statusStr
                                                    .replaceAll('_', ' ')
                                                    .toUpperCase(),
                                                type: badgeType,
                                                isSmall: true,
                                              ),
                                              Text(
                                                'CATEGORY: $category',
                                                style: const TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color: AppColors.primary,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 10),
                                          Text(
                                            subject,
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold,
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onSurface,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              const Icon(
                                                Icons.person_outline,
                                                size: 14,
                                                color: AppColors.primary,
                                              ),
                                              const SizedBox(width: 4),
                                              Expanded(
                                                child: Text(
                                                  '@$username ($email)',
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 10),
                                          const Divider(height: 1),
                                          const SizedBox(height: 8),

                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Row(
                                                children: [
                                                  const Icon(
                                                    Icons.chat_bubble_outline,
                                                    size: 14,
                                                    color: AppColors.primary,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    '$msgCount Messages',
                                                    style: const TextStyle(
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                  if (createdAt.isNotEmpty) ...[
                                                    const SizedBox(width: 8),
                                                    Text(
                                                      '• ${createdAt.length >= 10 ? createdAt.substring(0, 10) : createdAt}',
                                                      style: const TextStyle(
                                                        fontSize: 10,
                                                        color: AppColors
                                                            .onSurfaceVariant,
                                                      ),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                              Row(
                                                children: [
                                                  if (statusStr != 'closed')
                                                    TextButton.icon(
                                                      style: TextButton.styleFrom(
                                                        foregroundColor:
                                                            Colors.red,
                                                        padding:
                                                            const EdgeInsets.symmetric(
                                                              horizontal: 8,
                                                              vertical: 4,
                                                            ),
                                                      ),
                                                      onPressed: () =>
                                                          _closeTicket(
                                                            reportId,
                                                            subject,
                                                          ),
                                                      icon: const Icon(
                                                        Icons
                                                            .check_circle_outline,
                                                        size: 14,
                                                      ),
                                                      label: const Text(
                                                        'Close Ticket',
                                                        style: TextStyle(
                                                          fontSize: 11,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                    ),
                                                  const Icon(
                                                    Icons.chevron_right,
                                                    size: 18,
                                                    color: Colors.grey,
                                                  ),
                                                ],
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
    );
  }
}
