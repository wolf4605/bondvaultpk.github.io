import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../config/app_theme.dart';
import '../../config/responsive.dart';
import '../../utils/api_service.dart';
import '../../utils/app_utils.dart';
import '../../utils/notification_utils.dart';
import '../../widgets/widgets.dart';

class DrawDetailScreen extends StatefulWidget {
  final String drawId;
  final int denomination;
  final String drawDate;
  final int winnerCount;
  final String accessToken;
  final bool isAdmin;

  const DrawDetailScreen({
    super.key,
    required this.drawId,
    required this.denomination,
    required this.drawDate,
    required this.winnerCount,
    required this.accessToken,
    this.isAdmin = false,
  });

  @override
  State<DrawDetailScreen> createState() => _DrawDetailScreenState();
}

class _DrawDetailScreenState extends State<DrawDetailScreen> {
  bool _isLoading = true;
  bool _isDownloadingPdf = false;
  List<dynamic> _winners = [];
  final _searchController = TextEditingController();
  String _searchQuery = '';
  int? _selectedPositionFilter;

  @override
  void initState() {
    super.initState();
    _fetchBonds();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchBonds() async {
    setState(() => _isLoading = true);
    try {
      final details = await ApiService.fetchUserDrawlistBonds(
        accessToken: widget.accessToken,
        drawId: widget.drawId,
        isAdmin: widget.isAdmin,
      );
      if (details != null && mounted) {
        setState(() {
          _winners = details['winners'] ?? [];
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<File> _getOutputFile(String fileName) async {
    try {
      final downloadsDir = Directory('/storage/emulated/0/Download');
      if (await downloadsDir.exists()) {
        return File('${downloadsDir.path}/$fileName');
      }
    } catch (_) {}
    final tempDir = Directory.systemTemp;
    return File('${tempDir.path}/$fileName');
  }

  Future<void> _downloadPdf() async {
    setState(() => _isDownloadingPdf = true);
    showAppToast(
      context,
      '📥 Downloading Rs. ${formatNumber(widget.denomination)} Gazette PDF...',
      type: AppNotificationType.info,
    );
    LocalNotificationUtils.showDownloadStartedNotification(
      denomination: widget.denomination,
      drawDate: widget.drawDate,
    );

    try {
      final res = await ApiService.downloadUserDrawlistPdf(
        accessToken: widget.accessToken,
        drawId: widget.drawId,
        isAdmin: widget.isAdmin,
      );
      if (!mounted) return;
      if (res != null && res.statusCode == 200) {
        final bytes = res.bodyBytes;
        final fileName =
            'BondVault_Gazette_${widget.denomination}_${widget.drawDate}.pdf';
        final file = await _getOutputFile(fileName);
        await file.writeAsBytes(bytes);

        final double mb = bytes.length / (1024 * 1024);
        final String formattedSize = mb >= 0.1
            ? '${mb.toStringAsFixed(2)} MB'
            : '${(bytes.length / 1024).toStringAsFixed(1)} KB';

        if (mounted) {
          showAppNotificationSheet(
            context: context,
            title: 'Gazette Downloaded',
            message:
                'Official Rs. ${formatNumber(widget.denomination)} (${widget.drawDate}) Gazette PDF ($formattedSize) saved to device storage!\n\nFile Path:\n${file.path}',
            type: AppNotificationType.success,
          );
        }
      } else {
        showAppNotificationSheet(
          context: context,
          title: 'PDF Download Failed',
          message:
              'Unable to download PDF gazette. Server status: ${res?.statusCode}',
          type: AppNotificationType.error,
        );
      }
    } catch (e) {
      if (!mounted) return;
      showAppNotificationSheet(
        context: context,
        title: 'Download Error',
        message: 'Could not save PDF gazette to device storage: $e',
        type: AppNotificationType.error,
      );
    } finally {
      if (mounted) setState(() => _isDownloadingPdf = false);
    }
  }

  Future<void> _showWinnerDialog([Map<String, dynamic>? winnerItem]) async {
    final isEdit = winnerItem != null;
    final bondCtrl = TextEditingController(
      text: winnerItem?['bond_number']?.toString() ?? '',
    );
    final amountCtrl = TextEditingController(
      text: winnerItem?['prize_amount']?.toString() ?? '',
    );
    int selectedRank = winnerItem?['prize_position'] as int? ?? 1;
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
                        Icon(
                          isEdit ? Icons.edit : Icons.add_circle_outline,
                          color: Colors.white,
                          size: 22,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            isEdit
                                ? 'Edit Gazette Winning Bond'
                                : 'Add Gazette Winning Bond',
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white70),
                          onPressed: () => Navigator.pop(dialogContext),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'BOND NUMBER',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        AppTextField(
                          controller: bondCtrl,
                          keyboardType: TextInputType.number,
                          maxLength: 6,
                          labelText: '6-digit Bond Number (e.g. 123456)',
                          prefixIcon: const Icon(
                            Icons.confirmation_number_outlined,
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Bond number required'
                              : null,
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'PRIZE POSITION / RANK',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<int>(
                          initialValue: selectedRank,
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.emoji_events_outlined),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 1,
                              child: Text('1st Prize Winner'),
                            ),
                            DropdownMenuItem(
                              value: 2,
                              child: Text('2nd Prize Winner'),
                            ),
                            DropdownMenuItem(
                              value: 3,
                              child: Text('3rd Prize Winner'),
                            ),
                          ],
                          onChanged: (v) {
                            if (v != null) {
                              setDialogState(() => selectedRank = v);
                            }
                          },
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'PRIZE AMOUNT (PKR)',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        AppTextField(
                          controller: amountCtrl,
                          keyboardType: TextInputType.number,
                          labelText: 'Winning Prize Amount (Rs.)',
                          prefixIcon: const Icon(Icons.money),
                          validator: (v) =>
                              (v == null || int.tryParse(v.trim()) == null)
                              ? 'Valid amount required'
                              : null,
                        ),
                        const SizedBox(height: 24),
                        AppButton(
                          label: isEdit
                              ? 'Update Winning Bond'
                              : 'Add Winning Bond',
                          isLoading: isSubmitting,
                          icon: Icon(
                            isEdit ? Icons.save_outlined : Icons.add_circle,
                            size: 18,
                          ),
                          onPressed: () async {
                            if (!formKey.currentState!.validate()) return;
                            setDialogState(() => isSubmitting = true);
                            try {
                              final amount = int.parse(amountCtrl.text.trim());
                              final bondNo = bondCtrl.text.trim();
                              http.Response res;

                              if (isEdit) {
                                res = await ApiService.updateDrawWinner(
                                  accessToken: widget.accessToken,
                                  drawId: widget.drawId,
                                  bondNumber: winnerItem['bond_number']
                                      .toString(),
                                  newBondNumber: bondNo,
                                  prizePosition: selectedRank,
                                  prizeAmount: amount,
                                );
                              } else {
                                res = await ApiService.addDrawWinner(
                                  accessToken: widget.accessToken,
                                  drawId: widget.drawId,
                                  bondNumber: bondNo,
                                  prizePosition: selectedRank,
                                  prizeAmount: amount,
                                );
                              }

                              if (res.statusCode == 200 ||
                                  res.statusCode == 201) {
                                _fetchBonds();
                                if (dialogContext.mounted) {
                                  Navigator.pop(dialogContext);
                                }
                                if (mounted) {
                                  showAppNotificationSheet(
                                    context: this.context,
                                    title: isEdit
                                        ? 'Winner Updated'
                                        : 'Winner Added',
                                    message: isEdit
                                        ? 'Winning bond details for $bondNo updated successfully.'
                                        : 'Winning bond $bondNo added to gazette successfully.',
                                    type: AppNotificationType.success,
                                  );
                                }
                              } else {
                                final data = jsonDecode(res.body);
                                if (dialogContext.mounted) {
                                  setDialogState(() => isSubmitting = false);
                                  showAppToast(
                                    dialogContext,
                                    data['detail'] ?? 'Operation failed.',
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
                ],
              ),
            ),
          ),
        ),
      ),
    );

    Future.delayed(const Duration(milliseconds: 500), () {
      bondCtrl.dispose();
      amountCtrl.dispose();
    });
  }

  void _deleteWinner(String bondNumber) {
    showAppNotificationSheet(
      context: context,
      title: 'Remove Winning Bond',
      message:
          'Are you sure you want to remove winning bond number $bondNumber from this gazette?',
      type: AppNotificationType.warning,
      dismissLabel: 'Cancel',
      customAction: AppButton(
        label: 'Remove Winner',
        variant: AppButtonVariant.danger,
        onPressed: () async {
          Navigator.pop(context);
          try {
            final res = await ApiService.deleteDrawWinner(
              accessToken: widget.accessToken,
              drawId: widget.drawId,
              bondNumber: bondNumber,
            );
            if (res.statusCode == 200) {
              _fetchBonds();
              if (mounted) {
                showAppNotificationSheet(
                  context: context,
                  title: 'Winner Removed',
                  message:
                      'Winning bond number $bondNumber removed from gazette.',
                  type: AppNotificationType.success,
                );
              }
            } else {
              if (mounted) {
                showAppToast(
                  context,
                  'Failed to remove winning bond.',
                  type: AppNotificationType.error,
                );
              }
            }
          } catch (e) {
            if (mounted) {
              showAppToast(
                context,
                'Error: $e',
                type: AppNotificationType.error,
              );
            }
          }
        },
      ),
    );
  }

  Widget _buildPosFilterChip(String label, int? position) {
    final isSelected = _selectedPositionFilter == position;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: AppColors.primary,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : AppColors.onSurface,
        fontWeight: FontWeight.bold,
        fontSize: 11,
      ),
      onSelected: (selected) {
        if (selected) {
          setState(() => _selectedPositionFilter = position);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredWinners = _winners.where((w) {
      final bondNo = (w['bond_number'] ?? '').toString();
      final pos = w['prize_position'] as int? ?? 0;

      bool matchesPosition =
          _selectedPositionFilter == null || pos == _selectedPositionFilter;

      bool matchesSearch =
          _searchQuery.isEmpty || bondNo.contains(_searchQuery.trim());

      return matchesPosition && matchesSearch;
    }).toList();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Rs. ${formatNumber(widget.denomination)} Winning Bonds',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const AppLoadingIndicator(
              message: 'Fetching winning bond numbers and prize details...',
            )
          : RefreshIndicator(
              onRefresh: _fetchBonds,
              child: CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: EdgeInsets.symmetric(
                      horizontal: Responsive.w(context, 16),
                      vertical: Responsive.h(context, 12),
                    ),
                    sliver: SliverToBoxAdapter(
                      child: Center(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: Responsive.maxContentWidth(context),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Draw Header Card
                              AppCard(
                                padding: const EdgeInsets.all(20),
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF0F5132),
                                    Color(0xFF0A3622),
                                    Color(0xFF022C22),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Flexible(
                                          child: FittedBox(
                                            fit: BoxFit.scaleDown,
                                            alignment: Alignment.centerLeft,
                                            child: Text(
                                              'Rs. ${formatNumber(widget.denomination)} OFFICIAL GAZETTE',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                letterSpacing: 1.2,
                                                color: Color(0xFFD1FAE5),
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Flexible(
                                          child: FittedBox(
                                            fit: BoxFit.scaleDown,
                                            alignment: Alignment.centerRight,
                                            child: AppBadge(
                                              label:
                                                  '${formatNumber(_winners.length)} Winners',
                                              type: AppBadgeType.warning,
                                              icon: Icons.emoji_events,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Draw Date: ${widget.drawDate}',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: AppButton(
                                            label: 'Download PDF',
                                            variant: AppButtonVariant.secondary,
                                            isLoading: _isDownloadingPdf,
                                            icon: const Icon(
                                              Icons.picture_as_pdf,
                                              size: 18,
                                            ),
                                            onPressed: _downloadPdf,
                                          ),
                                        ),
                                        if (widget.isAdmin) ...[
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: AppButton(
                                              label: 'Add Winner',
                                              icon: const Icon(
                                                Icons.add_circle,
                                                size: 18,
                                              ),
                                              onPressed: () =>
                                                  _showWinnerDialog(),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 20),

                              // Search and Filter Section
                              const AppSectionHeader(
                                title: 'Winning Bond Numbers',
                                tagline: 'OFFICIAL RESULTS',
                              ),
                              const SizedBox(height: 8),
                              AppTextField(
                                controller: _searchController,
                                keyboardType: TextInputType.number,
                                labelText: 'Search Bond Number',
                                hintText: 'e.g. 123456',
                                prefixIcon: const Icon(Icons.search),
                                onChanged: (v) =>
                                    setState(() => _searchQuery = v),
                              ),
                              const SizedBox(height: 12),

                              // Position Filter Chips
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _buildPosFilterChip('All Prizes', null),
                                  _buildPosFilterChip('1st Prize', 1),
                                  _buildPosFilterChip('2nd Prize', 2),
                                  _buildPosFilterChip('3rd Prize', 3),
                                ],
                              ),
                              const SizedBox(height: 16),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // High-Performance Lazy-Loaded List View for 5,000+ Winners
                  filteredWinners.isEmpty
                      ? const SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            child: AppEmptyState(
                              icon: Icons.find_in_page_outlined,
                              title: 'No Winning Bonds Match',
                              message: 'No bond numbers match your search query or position filter.',
                            ),
                          ),
                        )
                      : SliverPadding(
                          padding: EdgeInsets.fromLTRB(
                            Responsive.w(context, 16),
                            0,
                            Responsive.w(context, 16),
                            24,
                          ),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate((
                              context,
                              index,
                            ) {
                              final w = filteredWinners[index];
                              final bondNo = (w['bond_number'] ?? '')
                                  .toString();
                              final pos = w['prize_position'] as int? ?? 0;
                              final prizeName =
                                  w['prize_name']?.toString() ?? '$pos Prize';
                              final prizeAmount =
                                  w['prize_amount'] as int? ?? 0;

                              AppBadgeType badgeType;
                              if (pos == 1) {
                                badgeType = AppBadgeType.warning;
                              } else if (pos == 2) {
                                badgeType = AppBadgeType.success;
                              } else {
                                badgeType = AppBadgeType.info;
                              }

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: AppCard(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          AppBadge(
                                            label: prizeName,
                                            type: badgeType,
                                            isSmall: true,
                                          ),
                                          const SizedBox(width: 14),
                                          Text(
                                            bondNo,
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold,
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onSurface,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Row(
                                        children: [
                                          Text(
                                            'Rs. ${formatNumber(prizeAmount)}',
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.primary,
                                            ),
                                          ),
                                          if (widget.isAdmin) ...[
                                            const SizedBox(width: 8),
                                            IconButton(
                                              icon: const Icon(
                                                Icons.edit_outlined,
                                                size: 18,
                                                color: AppColors.primary,
                                              ),
                                              onPressed: () =>
                                                  _showWinnerDialog(w),
                                            ),
                                            IconButton(
                                              icon: const Icon(
                                                Icons.delete_outline,
                                                size: 18,
                                                color: Colors.red,
                                              ),
                                              onPressed: () =>
                                                  _deleteWinner(bondNo),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }, childCount: filteredWinners.length),
                          ),
                        ),
                ],
              ),
            ),
      floatingActionButton: widget.isAdmin
          ? FloatingActionButton.extended(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              onPressed: () => _showWinnerDialog(),
              icon: const Icon(Icons.add_circle_outline),
              label: const Text('Add Winner'),
            )
          : null,
    );
  }
}
