import 'dart:convert';

import 'package:flutter/material.dart';

import '../../config/app_theme.dart';
import '../../config/responsive.dart';
import '../../utils/api_service.dart';
import '../../widgets/widgets.dart';
import '../report_chat_screen.dart';

class UserReportsScreen extends StatefulWidget {
  final String accessToken;

  const UserReportsScreen({super.key, required this.accessToken});

  @override
  State<UserReportsScreen> createState() => _UserReportsScreenState();
}

class _UserReportsScreenState extends State<UserReportsScreen> {
  bool _isLoading = true;
  List<dynamic> _reports = [];

  @override
  void initState() {
    super.initState();
    _fetchReports();
  }

  Future<void> _fetchReports() async {
    setState(() => _isLoading = true);
    try {
      final list = await ApiService.fetchUserReports(widget.accessToken);
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

  Future<void> _showNewReportDialog() async {
    final subjectCtrl = TextEditingController();
    final contentCtrl = TextEditingController();
    String category = 'general';
    final formKey = GlobalKey<FormState>();
    bool isSubmitting = false;

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          clipBehavior: Clip.antiAlias,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: Responsive.maxContentWidth(context),
              maxHeight: MediaQuery.sizeOf(context).height * 0.85,
            ),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 18,
                    ),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppColors.primary, AppColors.primaryContainer],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.support_agent_outlined,
                          color: Colors.white,
                          size: 24,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text(
                                'Open Support Ticket',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Submit issue details to BondVault PK support team',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFFD1FAE5),
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
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'ISSUE CATEGORY',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.8,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<String>(
                            initialValue: category,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              prefixIcon: Icon(Icons.category_outlined),
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'general',
                                child: Text(
                                  'General Inquiry',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              DropdownMenuItem(
                                value: 'technical',
                                child: Text(
                                  'Technical & App Bug',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              DropdownMenuItem(
                                value: 'billing',
                                child: Text(
                                  'Prize & Claim Support',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              DropdownMenuItem(
                                value: 'marketplace',
                                child: Text(
                                  'Marketplace Support',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                            onChanged: (v) {
                              if (v != null) setDialogState(() => category = v);
                            },
                          ),
                          const SizedBox(height: 14),

                        const Text(
                          'SUBJECT / TITLE',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        AppTextField(
                          controller: subjectCtrl,
                          labelText: 'Short summary (e.g. Issue scanning bond)',
                          prefixIcon: const Icon(Icons.subtitles_outlined),
                          validator: (v) => (v == null || v.trim().length < 3)
                              ? 'Subject must be at least 3 characters'
                              : null,
                        ),
                        const SizedBox(height: 14),

                        const Text(
                          'ISSUE DESCRIPTION',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        AppTextField(
                          controller: contentCtrl,
                          labelText: 'Detailed description of your problem...',
                          prefixIcon: const Icon(Icons.notes_outlined),
                          maxLines: 4,
                          validator: (v) => (v == null || v.trim().length < 5)
                              ? 'Description must be at least 5 characters'
                              : null,
                        ),
                        const SizedBox(height: 24),

                        AppButton(
                          label: 'Submit Ticket',
                          isLoading: isSubmitting,
                          icon: const Icon(Icons.send_outlined, size: 18),
                          onPressed: () async {
                            if (!formKey.currentState!.validate()) return;
                            setDialogState(() => isSubmitting = true);
                            try {
                              final res = await ApiService.createUserReport(
                                accessToken: widget.accessToken,
                                subject: subjectCtrl.text.trim(),
                                category: category,
                                content: contentCtrl.text.trim(),
                              );

                              if (res.statusCode == 201 ||
                                  res.statusCode == 200) {
                                _fetchReports();
                                if (dialogContext.mounted) {
                                  Navigator.pop(dialogContext);
                                }
                                if (mounted) {
                                  showAppNotificationSheet(
                                    context: this.context,
                                    title: 'Ticket Submitted',
                                    message: 'Your support report ticket was created successfully. A staff member will respond shortly.',
                                    type: AppNotificationType.success,
                                  );
                                }
                              } else {
                                final data = jsonDecode(res.body);
                                if (dialogContext.mounted) {
                                  setDialogState(() => isSubmitting = false);
                                  showAppToast(
                                    dialogContext,
                                    data['detail'] ??
                                        'Failed to submit ticket.',
                                    type: AppNotificationType.error,
                                  );
                                }
                              }
                            } catch (e) {
                              if (dialogContext.mounted) {
                                setDialogState(() => isSubmitting = false);
                                showAppToast(
                                  dialogContext,
                                  'Error: $e',
                                  type: AppNotificationType.error,
                                );
                              }
                            }
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
      ),
    );

    Future.delayed(const Duration(milliseconds: 500), () {
      subjectCtrl.dispose();
      contentCtrl.dispose();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'My Support Reports',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const AppLoadingIndicator(
              message: 'Loading your support tickets...',
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
                        const AppSectionHeader(
                          title: 'Support Tickets & Help',
                          tagline: 'TICKETS HISTORY',
                        ),
                        const SizedBox(height: 12),

                        _reports.isEmpty
                            ? const AppEmptyState(
                                icon: Icons.support_agent_outlined,
                                title: 'No Support Tickets Found',
                                message: 'Need help or found a problem? Tap + Open Ticket below to start a chat with BondVault support staff.',
                              )
                            : ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _reports.length,
                                itemBuilder: (context, index) {
                                  final item = _reports[index];
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
                                                  isAdmin: false,
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
                                                ],
                                              ),
                                              Row(
                                                children: [
                                                  Text(
                                                    createdAt.length >= 10
                                                        ? createdAt.substring(
                                                            0,
                                                            10,
                                                          )
                                                        : createdAt,
                                                    style: const TextStyle(
                                                      fontSize: 11,
                                                      color: AppColors
                                                          .onSurfaceVariant,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 4),
                                                  const Icon(
                                                    Icons.chevron_right,
                                                    size: 16,
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
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        onPressed: _showNewReportDialog,
        icon: const Icon(Icons.add_comment_outlined),
        label: const Text('Open Ticket'),
      ),
    );
  }
}
