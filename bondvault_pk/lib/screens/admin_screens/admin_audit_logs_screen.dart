import 'package:flutter/material.dart';

import '../../config/app_theme.dart';
import '../../config/responsive.dart';
import '../../utils/api_service.dart';
import '../../widgets/widgets.dart';

class AdminAuditLogsScreen extends StatefulWidget {
  final String accessToken;

  const AdminAuditLogsScreen({super.key, required this.accessToken});

  @override
  State<AdminAuditLogsScreen> createState() => _AdminAuditLogsScreenState();
}

class _AdminAuditLogsScreenState extends State<AdminAuditLogsScreen> {
  bool _isLoading = true;
  List<dynamic> _auditEvents = [];
  int _totalCount = 0;
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _filterCategory = 'All';

  @override
  void initState() {
    super.initState();
    _fetchAuditLogs();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchAuditLogs() async {
    setState(() => _isLoading = true);
    try {
      final res = await ApiService.fetchAdminAuditLogs(
        adminToken: widget.accessToken,
        limit: 150,
      );
      if (res != null && mounted) {
        final list =
            res['events'] ?? res['audit_events'] ?? res['results'] ?? [];
        final total = res['total'] as int? ?? (list is List ? list.length : 0);
        setState(() {
          _auditEvents = list is List ? list : [];
          _totalCount = total;
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatTimestamp(String raw) {
    if (raw.isEmpty) return 'N/A';
    try {
      final date = DateTime.tryParse(raw);
      if (date == null) return raw;
      final local = date.toLocal();
      return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return raw;
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _auditEvents.where((e) {
      final action = (e['action'] ?? '').toString().toLowerCase();
      final route = (e['route'] ?? '').toString().toLowerCase();
      final desc = (e['description'] ?? '').toString().toLowerCase();
      final ip = (e['client_ip'] ?? '').toString().toLowerCase();
      final actorName = (e['actor_username'] ?? '').toString().toLowerCase();

      bool matchesCategory = true;
      if (_filterCategory == 'Auth') {
        matchesCategory = action.contains('login') || route.contains('auth');
      } else if (_filterCategory == 'Users') {
        matchesCategory = action.contains('user') || route.contains('user');
      } else if (_filterCategory == 'Market') {
        matchesCategory = action.contains('market') || route.contains('market');
      } else if (_filterCategory == 'Draws') {
        matchesCategory = action.contains('draw') || route.contains('draw');
      }

      bool matchesSearch =
          _searchQuery.isEmpty ||
          action.contains(_searchQuery.toLowerCase()) ||
          route.contains(_searchQuery.toLowerCase()) ||
          desc.contains(_searchQuery.toLowerCase()) ||
          ip.contains(_searchQuery.toLowerCase()) ||
          actorName.contains(_searchQuery.toLowerCase());

      return matchesCategory && matchesSearch;
    }).toList();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'System Audit Logs',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const AppLoadingIndicator(message: 'Fetching system audit logs...')
          : RefreshIndicator(
              onRefresh: _fetchAuditLogs,
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
                          title: 'Audit Log History',
                          tagline: 'TOTAL EVENTS: $_totalCount',
                        ),
                        const SizedBox(height: 8),

                        // Search Bar
                        AppTextField(
                          controller: _searchController,
                          labelText: 'Search Audit Logs',
                          hintText: 'e.g. admin, login, blacklist, 192.168.1.1',
                          prefixIcon: const Icon(Icons.search),
                          onChanged: (v) => setState(() => _searchQuery = v),
                        ),
                        const SizedBox(height: 12),

                        // Category Filter Chips
                        Wrap(
                          spacing: 8,
                          children: [
                            _buildCategoryChip('All'),
                            _buildCategoryChip('Auth'),
                            _buildCategoryChip('Users'),
                            _buildCategoryChip('Market'),
                            _buildCategoryChip('Draws'),
                          ],
                        ),
                        const SizedBox(height: 16),

                        filtered.isEmpty
                            ? const AppEmptyState(
                                icon: Icons.history_toggle_off_outlined,
                                title: 'No Audit Events Found',
                                message: 'No recorded admin API actions match your search query or filter.',
                              )
                            : ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: filtered.length,
                                itemBuilder: (context, index) {
                                  final item = filtered[index];
                                  final action =
                                      item['action']?.toString() ??
                                      'SYSTEM_EVENT';
                                  final method =
                                      item['http_method']?.toString() ?? 'GET';
                                  final route =
                                      item['route']?.toString() ?? '/';
                                  final status =
                                      item['status_code'] as int? ?? 200;
                                  final ip =
                                      item['client_ip']?.toString() ??
                                      '127.0.0.1';
                                  final occurredAt = _formatTimestamp(
                                    item['occurred_at']?.toString() ?? '',
                                  );
                                  final desc =
                                      item['description']?.toString() ?? '';

                                  final actorUsername =
                                      (item['actor_username'] ?? '')
                                          .toString()
                                          .trim();
                                  final actorEmail = (item['actor_email'] ?? '')
                                      .toString()
                                      .trim();
                                  final adminName = actorUsername.isNotEmpty
                                      ? '@$actorUsername'
                                      : (actorEmail.isNotEmpty
                                            ? actorEmail
                                            : 'Administrator');

                                  AppBadgeType badgeType;
                                  if (status >= 200 && status < 300) {
                                    badgeType = AppBadgeType.success;
                                  } else if (status >= 400 && status < 500) {
                                    badgeType = AppBadgeType.warning;
                                  } else {
                                    badgeType = AppBadgeType.error;
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
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 4,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: AppColors.primary
                                                      .withValues(alpha: 0.1),
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  method,
                                                  style: const TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w900,
                                                    color: AppColors.primary,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  action.toUpperCase(),
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.bold,
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .onSurface,
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                              AppBadge(
                                                label: 'HTTP $status',
                                                type: badgeType,
                                                isSmall: true,
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          Row(
                                            children: [
                                              const Icon(
                                                Icons.admin_panel_settings,
                                                size: 14,
                                                color: AppColors.primary,
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                'Admin: $adminName',
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                  color: AppColors.primary,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Route: $route',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                            ),
                                          ),
                                          if (desc.isNotEmpty) ...[
                                            const SizedBox(height: 4),
                                            Text(
                                              desc,
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .onSurfaceVariant,
                                              ),
                                            ),
                                          ],
                                          const SizedBox(height: 10),
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Row(
                                                children: [
                                                  const Icon(
                                                    Icons.laptop_outlined,
                                                    size: 13,
                                                    color: Colors.grey,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    'IP: $ip',
                                                    style: const TextStyle(
                                                      fontSize: 11,
                                                      color: Colors.grey,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              Row(
                                                children: [
                                                  const Icon(
                                                    Icons.access_time,
                                                    size: 13,
                                                    color: Colors.grey,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    occurredAt,
                                                    style: const TextStyle(
                                                      fontSize: 11,
                                                      color: Colors.grey,
                                                    ),
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

  Widget _buildCategoryChip(String label) {
    final isSelected = _filterCategory == label;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: AppColors.primary,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : AppColors.onSurface,
        fontWeight: FontWeight.bold,
      ),
      onSelected: (s) {
        if (s) setState(() => _filterCategory = label);
      },
    );
  }
}
