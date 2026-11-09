import 'dart:io';

import 'package:flutter/material.dart';

import '../../config/app_theme.dart';
import '../../config/responsive.dart';
import '../../utils/api_service.dart';
import '../../utils/app_utils.dart';
import '../../utils/notification_utils.dart';
import '../../widgets/widgets.dart';
import 'draw_detail_screen.dart';

class DrawListsScreen extends StatefulWidget {
  final String accessToken;

  const DrawListsScreen({super.key, required this.accessToken});

  @override
  State<DrawListsScreen> createState() => _DrawListsScreenState();
}

class _DrawListsScreenState extends State<DrawListsScreen> {
  bool _isLoading = true;
  List<dynamic> _drawlists = [];
  int? _selectedDenomination;

  @override
  void initState() {
    super.initState();
    _fetchDrawlists();
  }

  Future<void> _fetchDrawlists() async {
    setState(() => _isLoading = true);
    try {
      final list = await ApiService.fetchUserDrawlists(widget.accessToken);
      if (list != null && mounted) {
        setState(() {
          _drawlists = list;
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredDraws = _drawlists.where((d) {
      if (_selectedDenomination == null) return true;
      final denom = d['denomination'] as int? ?? 0;
      return denom == _selectedDenomination;
    }).toList();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'Official Gazette Draw Lists',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const AppLoadingIndicator(
              message: 'Fetching official gazette draw lists...',
            )
          : RefreshIndicator(
              onRefresh: _fetchDrawlists,
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
                          title: 'Gazette Draw Results',
                          tagline: 'STATE BANK GAZETTES',
                        ),
                        const SizedBox(height: 8),

                        // Denomination Filter Chips
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _buildFilterChip('All', null),
                            _buildFilterChip('Rs. 100', 100),
                            _buildFilterChip('Rs. 200', 200),
                            _buildFilterChip('Rs. 750', 750),
                            _buildFilterChip('Rs. 1,500', 1500),
                            _buildFilterChip('Rs. 25,000', 25000),
                            _buildFilterChip('Rs. 40,000', 40000),
                          ],
                        ),
                        const SizedBox(height: 16),

                        filteredDraws.isEmpty
                            ? const AppEmptyState(
                                icon: Icons.description_outlined,
                                title: 'No Draw Lists Found',
                                message: 'No official gazette draw lists match the selected denomination.',
                              )
                            : ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: filteredDraws.length,
                                itemBuilder: (context, index) {
                                  final draw = filteredDraws[index];
                                  final drawId =
                                      draw['draw_id']?.toString() ?? '';
                                  final denomination =
                                      draw['denomination'] as int? ?? 0;
                                  final drawDate =
                                      draw['draw_date']?.toString() ?? 'N/A';
                                  final winnerCount =
                                      draw['winner_count'] as int? ?? 0;

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
                                          builder: (context) =>
                                              DrawDetailScreen(
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
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildFilterChip(String label, int? denomination) {
    final isSelected = _selectedDenomination == denomination;
    return InkWell(
      onTap: () => setState(() => _selectedDenomination = denomination),
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

class VibrantDrawCard extends StatefulWidget {
  final String drawId;
  final int denomination;
  final String drawDate;
  final int winnerCount;
  final String accessToken;
  final VoidCallback onTap;

  const VibrantDrawCard({
    super.key,
    required this.drawId,
    required this.denomination,
    required this.drawDate,
    required this.winnerCount,
    required this.accessToken,
    required this.onTap,
  });

  @override
  State<VibrantDrawCard> createState() => _VibrantDrawCardState();
}

class _VibrantDrawCardState extends State<VibrantDrawCard> {
  bool _isDownloadingPdf = false;

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
          title: 'PDF Gazette Saved',
          message:
              'Official Rs. ${formatNumber(widget.denomination)} (${widget.drawDate}) Gazette PDF ($formattedSize) saved to device storage!\n\nFile Path:\n${file.path}',
          type: AppNotificationType.success,
        );
      } else {
        showAppNotificationSheet(
          context: context,
          title: 'Download Failed',
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
        message: 'Could not save PDF to device storage: $e',
        type: AppNotificationType.error,
      );
    } finally {
      if (mounted) setState(() => _isDownloadingPdf = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final denomination = widget.denomination;
    final denomLabel = denomination >= 1000
        ? '${(denomination / 1000).toStringAsFixed(denomination % 1000 == 0 ? 0 : 1)}k'
        : '$denomination';

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: AppCard(
        padding: const EdgeInsets.all(18),
        borderRadius: 20,
        color: isDark ? const Color(0xFF064E3B) : Colors.white,
        border: Border.all(
          color: isDark
              ? const Color(0xFF80BEA6).withValues(alpha: 0.3)
              : const Color(0xFF80BEA6).withValues(alpha: 0.5),
          width: 1.5,
        ),
        elevation: 3,
        onTap: widget.onTap,
        child: Column(
          children: [
            Row(
              children: [
                // Vibrant Icon Pod
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF003527), Color(0xFF064E3B)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF003527).withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    denomLabel,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              'Rs. ${formatNumber(denomination)} Gazette',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: isDark
                                    ? Colors.white
                                    : AppColors.primary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          AppBadge(
                            label:
                                '${formatNumber(widget.winnerCount)} Winners',
                            type: AppBadgeType.warning,
                            icon: Icons.emoji_events,
                            isSmall: true,
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            Icons.calendar_today_outlined,
                            size: 13,
                            color: isDark
                                ? Colors.white70
                                : AppColors.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Draw Date: ${widget.drawDate}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: isDark
                                  ? Colors.white70
                                  : AppColors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                InkWell(
                  onTap: widget.onTap,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(
                        Icons.remove_red_eye_outlined,
                        size: 16,
                        color: AppColors.primary,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'View Winning Bonds',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                // Small Download Button
                SizedBox(
                  height: 36,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFE932C),
                      foregroundColor: Colors.white,
                      elevation: 1,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: _isDownloadingPdf ? null : _downloadPdf,
                    icon: _isDownloadingPdf
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : const Icon(Icons.picture_as_pdf, size: 14),
                    label: const Text(
                      'PDF Gazette',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
