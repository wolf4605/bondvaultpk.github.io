import 'dart:io';

import 'package:flutter/material.dart';

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

  const DrawDetailScreen({
    super.key,
    required this.drawId,
    required this.denomination,
    required this.drawDate,
    required this.winnerCount,
    required this.accessToken,
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

        if (!mounted) return;
        showAppNotificationSheet(
          context: context,
          title: 'Official Gazette PDF Saved',
          message:
              'Official Rs. ${formatNumber(widget.denomination)} (${widget.drawDate}) Gazette PDF ($formattedSize) saved to device storage!\n\nFile Path:\n${file.path}',
          type: AppNotificationType.success,
        );
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
                              AppButton(
                                label: 'Download PDF Gazette',
                                variant: AppButtonVariant.secondary,
                                isLoading: _isDownloadingPdf,
                                icon: const Icon(
                                  Icons.picture_as_pdf,
                                  size: 18,
                                ),
                                onPressed: _downloadPdf,
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
                          onChanged: (v) => setState(() => _searchQuery = v),
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

                        // Beautiful Table Card
                        filteredWinners.isEmpty
                            ? const AppEmptyState(
                                icon: Icons.find_in_page_outlined,
                                title: 'No Winning Bonds Match',
                                message: 'No bond numbers match your search query or position filter.',
                              )
                            : AppCard(
                                padding: EdgeInsets.zero,
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: ConstrainedBox(
                                    constraints: BoxConstraints(
                                      minWidth: Responsive.width(context) - 32,
                                    ),
                                    child: DataTable(
                                      headingRowColor: WidgetStateProperty.all(
                                        AppColors.surfaceContainerLow,
                                      ),
                                      horizontalMargin: 16,
                                      columnSpacing: 24,
                                      columns: const [
                                        DataColumn(
                                          label: Text(
                                            'PRIZE RANK',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.primary,
                                            ),
                                          ),
                                        ),
                                        DataColumn(
                                          label: Text(
                                            'BOND NUMBER',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.primary,
                                            ),
                                          ),
                                        ),
                                        DataColumn(
                                          label: Text(
                                            'PRIZE AMOUNT',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.primary,
                                            ),
                                          ),
                                        ),
                                      ],
                                      rows: filteredWinners.map((w) {
                                        final bondNo = (w['bond_number'] ?? '')
                                            .toString();
                                        final pos =
                                            w['prize_position'] as int? ?? 0;
                                        final prizeName =
                                            w['prize_name']?.toString() ??
                                            '$pos Prize';
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

                                        return DataRow(
                                          cells: [
                                            DataCell(
                                              AppBadge(
                                                label: prizeName,
                                                type: badgeType,
                                                isSmall: true,
                                              ),
                                            ),
                                            DataCell(
                                              Text(
                                                bondNo,
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.bold,
                                                  color: AppColors.onSurface,
                                                ),
                                              ),
                                            ),
                                            DataCell(
                                              Text(
                                                'Rs. ${formatNumber(prizeAmount)}',
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.bold,
                                                  color: AppColors.primary,
                                                ),
                                              ),
                                            ),
                                          ],
                                        );
                                      }).toList(),
                                    ),
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
  }

  Widget _buildPosFilterChip(String label, int? position) {
    final isSelected = _selectedPositionFilter == position;
    return InkWell(
      onTap: () => setState(() => _selectedPositionFilter = position),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: Responsive.w(context, 12),
          vertical: Responsive.h(context, 6),
        ),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.grey.shade300,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: Responsive.sp(context, 12),
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : AppColors.onSurface,
          ),
        ),
      ),
    );
  }
}
