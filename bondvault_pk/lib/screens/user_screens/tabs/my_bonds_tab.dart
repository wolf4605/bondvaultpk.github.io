import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../../config/app_theme.dart';
import '../../../config/responsive.dart';
import '../../../utils/api_service.dart';
import '../../../utils/app_utils.dart';
import '../../../widgets/widgets.dart';
import '../bond_ocr_parser.dart';
import '../bondlist_detail_screen.dart';
import '../camera_scan_screen.dart';

class MyBondsTab extends StatefulWidget {
  final bool isVerified;
  final String accessToken;
  final VoidCallback onPortfolioUpdated;

  const MyBondsTab({
    super.key,
    required this.isVerified,
    required this.accessToken,
    required this.onPortfolioUpdated,
  });

  @override
  State<MyBondsTab> createState() => _MyBondsTabState();
}

class _MyBondsTabState extends State<MyBondsTab> {
  bool _isLoading = true;
  List<dynamic> _bondlists = [];
  List<dynamic> _winnings = [];
  int _totalWonAmount = 0;
  bool _isFabExpanded = false;

  @override
  void initState() {
    super.initState();
    if (widget.isVerified) {
      _fetchBondlists();
    } else {
      _isLoading = false;
    }
  }

  Future<void> _fetchBondlists() async {
    setState(() => _isLoading = true);
    try {
      final data = await ApiService.fetchBondlists(widget.accessToken);
      final winningsData = await ApiService.fetchBondWinnings(
        widget.accessToken,
      );

      if (data != null) {
        final lists = List.from(data['bondlists']?['bondlists'] ?? []);
        lists.sort((a, b) {
          final denomA = a['denomination'] as int? ?? 0;
          final denomB = b['denomination'] as int? ?? 0;
          return denomA.compareTo(denomB);
        });
        setState(() {
          _bondlists = lists;
        });
      }

      if (winningsData != null) {
        final wins =
            winningsData['results'] ??
            winningsData['winnings'] ??
            winningsData['winning_bonds'] ??
            winningsData['bonds'] ??
            [];
        int wonSum = 0;
        for (final w in wins) {
          wonSum += (w['prize_amount'] as int? ?? w['amount'] as int? ?? 0);
        }
        setState(() {
          _winnings = wins is List ? wins : [];
          _totalWonAmount = wonSum;
        });
      }
      widget.onPortfolioUpdated();
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

  Future<void> _downloadBondsTxtFile(
    BuildContext context,
    int denomination,
    List<dynamic> bonds,
  ) async {
    if (bonds.isEmpty) {
      showAppToast(
        context,
        'No bonds available to export for Rs. ${formatNumber(denomination)}.',
        type: AppNotificationType.warning,
      );
      return;
    }

    showAppToast(
      context,
      '📥 Exporting ${bonds.length} bond numbers to TXT...',
      type: AppNotificationType.info,
    );

    try {
      final String content = bonds.map((b) => b.toString().trim()).join('\n');
      final fileName = 'BondVault_Bonds_Rs_$denomination.txt';
      final file = await _getOutputFile(fileName);
      await file.writeAsString(content);

      final double kb = file.lengthSync() / 1024.0;
      final sizeStr = kb >= 1024
          ? '${(kb / 1024.0).toStringAsFixed(2)} MB'
          : '${kb.toStringAsFixed(1)} KB';

      if (!context.mounted) return;
      showAppNotificationSheet(
        context: context,
        title: 'TXT File Exported Successfully',
        message:
            'Exported ${bonds.length} bond numbers ($sizeStr) to file!\n\nFile Location:\n${file.path}',
        type: AppNotificationType.success,
      );
    } catch (e) {
      if (!context.mounted) return;
      showAppNotificationSheet(
        context: context,
        title: 'Export Failed',
        message: 'Could not write TXT file to device storage: $e',
        type: AppNotificationType.error,
      );
    }
  }

  void _showAddBondsDialog(BuildContext context, {bool isRange = false}) {
    setState(() => _isFabExpanded = false);
    showDialog(
      context: context,
      builder: (context) => _AddBondsDialog(
        accessToken: widget.accessToken,
        initialIsRange: isRange,
        onBondsAdded: _fetchBondlists,
      ),
    );
  }

  void _openCameraScanner(BuildContext context) {
    setState(() => _isFabExpanded = false);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CameraScanScreen(
          accessToken: widget.accessToken,
          onBondsAdded: _fetchBondlists,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (!widget.isVerified) {
      return const AppEmptyState(
        icon: Icons.lock_outline,
        title: 'Feature Locked',
        message: 'Your account is currently under verification review. My Bonds feature will unlock automatically once approved.',
      );
    }

    int totalBonds = 0;
    int totalValue = 0;
    for (final list in _bondlists) {
      final denomination = list['denomination'] as int? ?? 0;
      final bonds = list['bonds'] as List? ?? [];
      totalBonds += bonds.length;
      totalValue += denomination * bonds.length;
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: _isLoading
          ? const AppLoadingIndicator(message: 'Fetching bond holdings...')
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const AppSectionHeader(
                    title: 'My Bonds Portfolio',
                    tagline: 'OVERVIEW',
                  ),
                  const SizedBox(height: 12),

                  // Hero Portfolio Card
                  AppCard(
                    padding: const EdgeInsets.all(20),
                    borderRadius: 24,
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF0F5132),
                        Color(0xFF0A3622),
                        Color(0xFF022C22),
                      ],
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
                            Flexible(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(
                                      Icons.account_balance_wallet_outlined,
                                      color: Colors.white,
                                      size: 14,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Flexible(
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        'TOTAL BOND VALUE',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 1.2,
                                          color: Color(0xFFD1FAE5),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerRight,
                                child: AppBadge(
                                  label: '$totalBonds Bonds Held',
                                  type: AppBadgeType.success,
                                  icon: Icons.verified,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            const Text(
                              'Rs. ',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.white70,
                              ),
                            ),
                            Text(
                              formatNumber(totalValue),
                              style: const TextStyle(
                                fontSize: 34,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.only(top: 12),
                          decoration: const BoxDecoration(
                            border: Border(
                              top: BorderSide(color: Colors.white12),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Flexible(
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.savings_outlined,
                                      size: 16,
                                      color: Color(0xFF95D3BA),
                                    ),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        alignment: Alignment.centerLeft,
                                        child: Text(
                                          '${_bondlists.length} Denominations',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerRight,
                                  child: AppBadge(
                                    label:
                                        'Rs. ${formatNumber(_totalWonAmount)} Won',
                                    type: AppBadgeType.warning,
                                    icon: Icons.emoji_events,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Denomination Breakdown Section
                  const AppSectionHeader(
                    title: 'Bond Denominations',
                    tagline: 'HOLDINGS',
                  ),
                  const SizedBox(height: 8),

                  _bondlists.isEmpty
                      ? const AppEmptyState(
                          icon: Icons.subtitles_off_outlined,
                          title: 'No Bonds Added Yet',
                          message: 'Tap the + button below to scan or add your prize bond numbers to start tracking.',
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _bondlists.length,
                          itemBuilder: (context, index) {
                            final list = _bondlists[index];
                            final denomination =
                                list['denomination'] as int? ?? 0;
                            final bonds = list['bonds'] as List? ?? [];
                            final totalVal = denomination * bonds.length;
                            final denomLabel = denomination >= 1000
                                ? '${(denomination / 1000).toStringAsFixed(denomination % 1000 == 0 ? 0 : 1)}k'
                                : '$denomination';

                            final denomWins = _winnings
                                .where(
                                  (w) =>
                                      (w['denomination'] as int? ?? 0) ==
                                      denomination,
                                )
                                .toList();
                            final int winnerCount = denomWins.length;
                            final int denomWonAmount = denomWins.fold(
                              0,
                              (sum, w) =>
                                  sum +
                                  (w['prize_amount'] as int? ??
                                      w['amount'] as int? ??
                                      0),
                            );

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: AppCard(
                                padding: const EdgeInsets.all(18),
                                borderRadius: 20,
                                color: isDark
                                    ? const Color(0xFF064E3B)
                                    : Colors.white,
                                border: Border.all(
                                  color: isDark
                                      ? const Color(0xFF80BEA6)
                                            .withValues(alpha: 0.3)
                                      : const Color(0xFF80BEA6)
                                            .withValues(alpha: 0.5),
                                  width: 1.5,
                                ),
                                elevation: 3,
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          BondlistDetailScreen(
                                            denomination: denomination,
                                            initialBonds: bonds,
                                            accessToken: widget.accessToken,
                                            onBondsUpdated: _fetchBondlists,
                                          ),
                                    ),
                                  );
                                },
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
                                              colors: [
                                                Color(0xFF003527),
                                                Color(0xFF064E3B),
                                              ],
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: const Color(0xFF003527)
                                                    .withValues(alpha: 0.3),
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
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  Text(
                                                    'Rs. ${formatNumber(denomination)}',
                                                    style: TextStyle(
                                                      fontSize: 17,
                                                      fontWeight:
                                                          FontWeight.w900,
                                                      color: isDark
                                                          ? Colors.white
                                                          : AppColors.primary,
                                                    ),
                                                  ),
                                                  if (winnerCount > 0)
                                                    AppBadge(
                                                      label: '$winnerCount Won',
                                                      type:
                                                          AppBadgeType.warning,
                                                      icon: Icons.emoji_events,
                                                      isSmall: true,
                                                    ),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                winnerCount > 0
                                                    ? '${bonds.length} Bonds Held • Rs. ${formatNumber(denomWonAmount)} Won'
                                                    : '${bonds.length} Bonds Registered',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w500,
                                                  color: isDark
                                                      ? Colors.white70
                                                      : AppColors
                                                            .onSurfaceVariant,
                                                ),
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
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Flexible(
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(
                                                Icons
                                                    .account_balance_wallet_outlined,
                                                size: 14,
                                                color: AppColors.primary,
                                              ),
                                              const SizedBox(width: 4),
                                              Flexible(
                                                child: FittedBox(
                                                  fit: BoxFit.scaleDown,
                                                  alignment: Alignment.centerLeft,
                                                  child: Text(
                                                    'Total Value: Rs. ${formatNumber(totalVal)}',
                                                    style: TextStyle(
                                                      fontSize: 13,
                                                      fontWeight: FontWeight.bold,
                                                      color: isDark
                                                          ? Colors.white
                                                          : AppColors.onSurface,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        // TXT Export Button
                                        SizedBox(
                                          height: 34,
                                          child: ElevatedButton.icon(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  AppColors.primary,
                                              foregroundColor: Colors.white,
                                              elevation: 1,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                  ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                            ),
                                            onPressed: () =>
                                                _downloadBondsTxtFile(
                                                  context,
                                                  denomination,
                                                  bonds,
                                                ),
                                            icon: const Icon(
                                              Icons.download,
                                              size: 14,
                                            ),
                                            label: const Text(
                                              'Export TXT',
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
                          },
                        ),
                ],
              ),
            ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (_isFabExpanded) ...[
            FloatingActionButton.extended(
              heroTag: 'scan_bond',
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              onPressed: () => _openCameraScanner(context),
              icon: const Icon(Icons.qr_code_scanner, size: 18),
              label: const Text('Scan Bond'),
            ),
            const SizedBox(height: 12),
            FloatingActionButton.extended(
              heroTag: 'add_bond',
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              onPressed: () => _showAddBondsDialog(context, isRange: false),
              icon: const Icon(Icons.add_box_outlined, size: 18),
              label: const Text('Add Bond'),
            ),
            const SizedBox(height: 12),
            FloatingActionButton.extended(
              heroTag: 'add_range',
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              onPressed: () => _showAddBondsDialog(context, isRange: true),
              icon: const Icon(Icons.format_list_numbered, size: 18),
              label: const Text('Add By Range'),
            ),
            const SizedBox(height: 16),
          ],
          FloatingActionButton(
            shape: const CircleBorder(),
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            onPressed: () => setState(() => _isFabExpanded = !_isFabExpanded),
            child: Icon(_isFabExpanded ? Icons.close : Icons.add),
          ),
        ],
      ),
    );
  }
}

class _AddBondsDialog extends StatefulWidget {
  final String accessToken;
  final bool initialIsRange;
  final VoidCallback onBondsAdded;

  const _AddBondsDialog({
    required this.accessToken,
    this.initialIsRange = false,
    required this.onBondsAdded,
  });

  @override
  State<_AddBondsDialog> createState() => _AddBondsDialogState();
}

class _AddBondsDialogState extends State<_AddBondsDialog> {
  final _startNumController = TextEditingController();
  final _endNumController = TextEditingController();
  final _numbersController = TextEditingController();
  int _selectedDenomination = 750;
  late bool _isRange;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _isRange = widget.initialIsRange;
  }

  @override
  void dispose() {
    _startNumController.dispose();
    _endNumController.dispose();
    _numbersController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isRange) {
      final startText = _startNumController.text.trim();
      final endText = _endNumController.text.trim();
      if (startText.isEmpty || endText.isEmpty) {
        showAppToast(
          context,
          'Please enter both Start Number and End Number.',
          type: AppNotificationType.warning,
        );
        return;
      }
      final start = int.tryParse(startText);
      final end = int.tryParse(endText);
      if (start == null || end == null) {
        showAppToast(
          context,
          'Start and End Numbers must be valid numeric values.',
          type: AppNotificationType.warning,
        );
        return;
      }
      if (start > end) {
        showAppToast(
          context,
          'Start Number cannot be greater than End Number.',
          type: AppNotificationType.warning,
        );
        return;
      }
    } else {
      final text = _numbersController.text.trim();
      if (text.isEmpty) {
        showAppToast(
          context,
          'Please enter at least one bond number.',
          type: AppNotificationType.warning,
        );
        return;
      }
    }

    setState(() => _isLoading = true);
    try {
      final res = _isRange
          ? await ApiService.addBondsRange(
              accessToken: widget.accessToken,
              denomination: _selectedDenomination,
              startNumber: _startNumController.text.trim().padLeft(6, '0'),
              endNumber: _endNumController.text.trim().padLeft(6, '0'),
            )
          : await ApiService.addBonds(
              accessToken: widget.accessToken,
              denomination: _selectedDenomination,
              bonds: _numbersController.text
                  .split(',')
                  .map((s) => s.trim().padLeft(6, '0'))
                  .where((s) => s.isNotEmpty && s.length == 6)
                  .toList(),
            );

      if (res.statusCode == 201 || res.statusCode == 200) {
        widget.onBondsAdded();
        if (!mounted) return;
        Navigator.pop(context);
        showAppNotificationSheet(
          context: context,
          title: 'Bonds Registered',
          message: 'Your prize bonds have been added to your portfolio successfully!',
          type: AppNotificationType.success,
        );
      } else {
        final data = jsonDecode(res.body);
        final msg = data['detail'] ?? 'Failed to add bonds.';
        if (!mounted) return;
        showAppNotificationSheet(
          context: context,
          title: 'Error Adding Bonds',
          message: msg.toString(),
          type: AppNotificationType.error,
        );
      }
    } catch (e) {
      if (!mounted) return;
      showAppNotificationSheet(
        context: context,
        title: 'Connection Error',
        message: 'Could not connect to server to add bonds.',
        type: AppNotificationType.error,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      clipBehavior: Clip.antiAlias,
      backgroundColor: isDark ? const Color(0xFF064E3B) : Colors.white,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: Responsive.maxContentWidth(context),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Vibrant Emerald Header Banner
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFF0F5132),
                    Color(0xFF0A3622),
                    Color(0xFF022C22),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _isRange
                          ? Icons.format_list_numbered
                          : Icons.add_box_outlined,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isRange
                              ? 'Add Bonds By Range'
                              : 'Register Prize Bonds',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _isRange
                              ? 'Enter start and end series to register'
                              : 'Add single or bulk bond serial numbers',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFFD1FAE5),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Form Body
            SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Modern Segmented Selector
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.black26
                          : AppColors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark ? Colors.white10 : Colors.grey.shade300,
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => setState(() => _isRange = true),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: _isRange
                                    ? AppColors.primary
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: _isRange
                                    ? [
                                        BoxShadow(
                                          color: AppColors.primary.withValues(
                                            alpha: 0.3,
                                          ),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ]
                                    : null,
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                'By Range',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: _isRange
                                      ? Colors.white
                                      : (isDark
                                            ? Colors.white70
                                            : AppColors.onSurfaceVariant),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: InkWell(
                            onTap: () => setState(() => _isRange = false),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: !_isRange
                                    ? AppColors.primary
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: !_isRange
                                    ? [
                                        BoxShadow(
                                          color: AppColors.primary.withValues(
                                            alpha: 0.3,
                                          ),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ]
                                    : null,
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                'By Numbers',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: !_isRange
                                      ? Colors.white
                                      : (isDark
                                            ? Colors.white70
                                            : AppColors.onSurfaceVariant),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  const Text(
                    'Denomination',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<int>(
                    initialValue: _selectedDenomination,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.currency_exchange),
                    ),
                    items: BondOcrParser.denominations
                        .map(
                          (d) => DropdownMenuItem(
                            value: d,
                            child: Text('Rs. ${formatNumber(d)}'),
                          ),
                        )
                        .toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _selectedDenomination = val);
                      }
                    },
                  ),
                  const SizedBox(height: 16),

                  if (_isRange) ...[
                    const Text(
                      'Start Series Number',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    AppTextField(
                      controller: _startNumController,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      labelText: 'Start Number (e.g. 000001)',
                      prefixIcon: const Icon(Icons.first_page),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'End Series Number',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    AppTextField(
                      controller: _endNumController,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      labelText: 'End Number (e.g. 000100)',
                      prefixIcon: const Icon(Icons.last_page),
                    ),
                  ] else ...[
                    const Text(
                      'Serial Numbers',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    AppTextField(
                      controller: _numbersController,
                      maxLines: 3,
                      labelText: 'Bond Numbers (comma separated)',
                      hintText: '123456, 654321, 789012',
                      prefixIcon: const Icon(Icons.numbers),
                    ),
                  ],
                  const SizedBox(height: 24),

                  // Action Button
                  AppButton(
                    label: _isRange
                        ? 'Register Range to Portfolio'
                        : 'Register Bonds to Portfolio',
                    isLoading: _isLoading,
                    icon: const Icon(Icons.check_circle_outline, size: 18),
                    onPressed: _submit,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
