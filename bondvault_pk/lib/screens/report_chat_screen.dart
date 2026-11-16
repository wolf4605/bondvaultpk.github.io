import 'dart:async';

import 'package:flutter/material.dart';

import '../config/app_theme.dart';
import '../config/responsive.dart';
import '../utils/api_service.dart';
import '../widgets/widgets.dart';

class ReportChatScreen extends StatefulWidget {
  final String accessToken;
  final Map<String, dynamic> report;
  final bool isAdmin;
  final VoidCallback? onStatusChanged;

  const ReportChatScreen({
    super.key,
    required this.accessToken,
    required this.report,
    this.isAdmin = false,
    this.onStatusChanged,
  });

  @override
  State<ReportChatScreen> createState() => _ReportChatScreenState();
}

class _ReportChatScreenState extends State<ReportChatScreen> {
  late String _status;
  List<dynamic> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    _status = widget.report['status']?.toString().toLowerCase() ?? 'open';
    _fetchMessages();
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted && _status != 'closed') {
        _fetchMessages(silent: true);
      }
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchMessages({bool silent = false}) async {
    if (!silent) setState(() => _isLoading = true);
    final reportId = widget.report['id']?.toString() ?? '';
    try {
      final list = await ApiService.fetchReportMessages(
        accessToken: widget.accessToken,
        reportId: reportId,
        isAdmin: widget.isAdmin,
      );
      if (list != null && mounted) {
        setState(() {
          _messages = list;
        });
        _scrollToBottom();
      }
    } catch (_) {
    } finally {
      if (!silent && mounted) setState(() => _isLoading = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _formatChatTime(String rawDate) {
    if (rawDate.isEmpty) return '';
    try {
      final dt = DateTime.tryParse(rawDate);
      if (dt == null) return rawDate;
      final local = dt.toLocal();
      final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
      final minute = local.minute.toString().padLeft(2, '0');
      final period = local.hour >= 12 ? 'pm' : 'am';
      return '$hour:$minute $period';
    } catch (_) {
      return rawDate;
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isSending = true);
    _messageController.clear();
    final reportId = widget.report['id']?.toString() ?? '';

    try {
      final res = await ApiService.sendReportMessage(
        accessToken: widget.accessToken,
        reportId: reportId,
        message: text,
        isAdmin: widget.isAdmin,
      );

      if (!mounted) return;
      if (res.statusCode == 201 || res.statusCode == 200) {
        if (_status == 'open' && widget.isAdmin) {
          setState(() => _status = 'in_progress');
        }
        await _fetchMessages(silent: true);
      } else {
        showAppToast(
          context,
          'Failed to send message.',
          type: AppNotificationType.error,
        );
      }
    } catch (e) {
      if (!mounted) return;
      showAppToast(
        context,
        'Error sending message: $e',
        type: AppNotificationType.error,
      );
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _updateStatus(String newStatus) async {
    final reportId = widget.report['id']?.toString() ?? '';
    try {
      final res = await ApiService.updateReportStatus(
        accessToken: widget.accessToken,
        reportId: reportId,
        status: newStatus,
      );
      if (!mounted) return;
      if (res.statusCode == 200) {
        setState(() => _status = newStatus);
        widget.onStatusChanged?.call();
        showAppNotificationSheet(
          context: context,
          title: 'Ticket Status Updated',
          message:
              'Ticket status updated to ${newStatus.toUpperCase()}. User notified via email.',
          type: AppNotificationType.success,
        );
      }
    } catch (_) {}
  }

  Widget _buildMessageBubble(Map<String, dynamic> item) {
    final senderType = item['sender_type']?.toString().toLowerCase() ?? 'user';
    final senderName = item['sender_name']?.toString() ?? 'User';
    final messageText = item['message']?.toString() ?? '';
    final createdAt = item['created_at']?.toString() ?? '';
    final formattedTime = _formatChatTime(createdAt);

    final isAdminMsg = senderType == 'admin';

    if (isAdminMsg) {
      // Support / Staff Message - Left Aligned
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Left Avatar Icon
            Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.primary, width: 1.8),
              ),
              child: const CircleAvatar(
                radius: 18,
                backgroundColor: Color(0xFFD1FAE5),
                child: Icon(
                  Icons.smart_toy_outlined,
                  size: 20,
                  color: AppColors.primary,
                ),
              ),
            ),
            const SizedBox(width: 8),

            // Message Bubble
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    constraints: BoxConstraints(
                      maxWidth: Responsive.maxContentWidth(context) * 0.72,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: const BoxDecoration(
                      color: Color(0xFFEFEFEF),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(20),
                        topRight: Radius.circular(20),
                        bottomRight: Radius.circular(20),
                        bottomLeft: Radius.circular(4),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              senderName,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(
                                  alpha: 0.15,
                                ),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'STAFF',
                                style: TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          messageText,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF1F2937),
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (formattedTime.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Text(
                        formattedTime,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      );
    } else {
      // User Message - Right Aligned
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Message Bubble
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    constraints: BoxConstraints(
                      maxWidth: Responsive.maxContentWidth(context) * 0.72,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(20),
                        topRight: Radius.circular(20),
                        bottomLeft: Radius.circular(20),
                        bottomRight: Radius.circular(4),
                      ),
                    ),
                    child: Text(
                      messageText,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.white,
                        height: 1.35,
                      ),
                    ),
                  ),
                  if (formattedTime.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Text(
                        formattedTime,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),

            // Right Avatar Icon
            Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.primary, width: 1.8),
              ),
              child: const CircleAvatar(
                radius: 18,
                backgroundColor: Color(0xFFD1FAE5),
                child: Icon(Icons.person, size: 20, color: AppColors.primary),
              ),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final subject = widget.report['subject']?.toString() ?? 'Support Ticket';
    final category =
        widget.report['category']?.toString().toUpperCase() ?? 'GENERAL';
    final isClosed = _status == 'closed';

    AppBadgeType statusBadgeType;
    if (_status == 'closed') {
      statusBadgeType = AppBadgeType.error;
    } else if (_status == 'in_progress') {
      statusBadgeType = AppBadgeType.warning;
    } else {
      statusBadgeType = AppBadgeType.success;
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Column(
          children: [
            Text(
              subject,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              'Category: $category',
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          if (widget.isAdmin)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (val) {
                if (val == 'close') _updateStatus('closed');
                if (val == 'open') _updateStatus('open');
                if (val == 'in_progress') _updateStatus('in_progress');
              },
              itemBuilder: (context) => [
                if (!isClosed)
                  const PopupMenuItem(
                    value: 'close',
                    child: Row(
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          color: Colors.green,
                          size: 18,
                        ),
                        SizedBox(width: 8),
                        Text('Close Ticket'),
                      ],
                    ),
                  ),
                if (isClosed)
                  const PopupMenuItem(
                    value: 'open',
                    child: Row(
                      children: [
                        Icon(Icons.refresh, color: AppColors.primary, size: 18),
                        SizedBox(width: 8),
                        Text('Re-open Ticket'),
                      ],
                    ),
                  ),
              ],
            ),
        ],
      ),
      body: Column(
        children: [
          // Banner Status Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: AppColors.surfaceContainerLow,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.confirmation_number_outlined,
                      size: 16,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'TICKET ID: ${widget.report['id']?.toString().substring(0, 8)}...',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
                AppBadge(
                  label: _status.replaceAll('_', ' ').toUpperCase(),
                  type: statusBadgeType,
                  isSmall: true,
                ),
              ],
            ),
          ),

          // Messages ListView
          Expanded(
            child: _isLoading
                ? const AppLoadingIndicator(message: 'Loading chat messages...')
                : _messages.isEmpty
                ? const AppEmptyState(
                    icon: Icons.chat_bubble_outline,
                    title: 'No Messages Yet',
                    message:
                        'Send a message below to start the support discussion.',
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      return _buildMessageBubble(_messages[index]);
                    },
                  ),
          ),

          // Message Input Bar
          if (isClosed)
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.grey.shade200,
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.lock_outline, size: 16, color: Colors.grey),
                  SizedBox(width: 8),
                  Text(
                    'This support ticket is closed.',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            )
          else
            Container(
              padding: EdgeInsets.fromLTRB(
                12,
                8,
                12,
                MediaQuery.paddingOf(context).bottom + 8,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 8,
                    offset: Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.attach_file_rounded,
                      color: Colors.grey.shade500,
                    ),
                    onPressed: () {
                      showAppToast(
                        context,
                        'Attachments feature coming soon.',
                        type: AppNotificationType.info,
                      );
                    },
                  ),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _messageController,
                              decoration: const InputDecoration(
                                hintText: 'Message',
                                hintStyle: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 14,
                                ),
                                border: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(
                                  vertical: 10,
                                ),
                              ),
                              maxLines: null,
                              textInputAction: TextInputAction.send,
                              onSubmitted: (_) => _sendMessage(),
                            ),
                          ),
                          Icon(
                            Icons.sentiment_satisfied_alt_outlined,
                            color: Colors.grey.shade400,
                            size: 22,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _sendMessage,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: _isSending
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(
                                Icons.send_rounded,
                                size: 20,
                                color: Colors.white,
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
