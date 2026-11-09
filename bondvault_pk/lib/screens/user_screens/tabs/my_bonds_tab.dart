import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../config/app_theme.dart';
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

  void _showAddBondsDialog(BuildContext context) {
    setState(() => _isFabExpanded = false);
    showDialog(
      context: context,
      builder: (context) => _AddBondsDialog(
        accessToken: widget.accessToken,
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
                            Row(
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
                                const Text(
                                  'TOTAL BOND VALUE',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.2,
                                    color: Color(0xFFD1FAE5),
                                  ),
                                ),
                              ],
                            ),
                            AppBadge(
                              label: '$totalBonds Bonds Held',
                              type: AppBadgeType.success,
                              icon: Icons.verified,
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
                              Row(
                                children: [
                                  const Icon(
                                    Icons.savings_outlined,
                                    size: 16,
                                    color: Color(0xFF95D3BA),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '${_bondlists.length} Denominations',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                              AppBadge(
                                label:
                                    'Rs. ${formatNumber(_totalWonAmount)} Won Total',
                                type: AppBadgeType.warning,
                                icon: Icons.emoji_events,
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
                              padding: const EdgeInsets.only(bottom: 12),
                              child: AppCard(
                                padding: const EdgeInsets.all(16),
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
                                child: Row(
                                  children: [
                                    Container(
                                      width: 48,
                                      height: 48,
                                      decoration: BoxDecoration(
                                        color: AppColors.primary,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        denomLabel,
                                        style: const TextStyle(
                                          fontSize: 14,
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
                                            children: [
                                              Text(
                                                'Rs. ${formatNumber(denomination)}',
                                                style: TextStyle(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.bold,
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .onSurface,
                                                ),
                                              ),
                                              if (winnerCount > 0) ...[
                                                const SizedBox(width: 8),
                                                AppBadge(
                                                  label:
                                                      '$winnerCount Winner${winnerCount > 1 ? 's' : ''}',
                                                  type: AppBadgeType.warning,
                                                  icon: Icons.emoji_events,
                                                  isSmall: true,
                                                ),
                                              ],
                                            ],
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            winnerCount > 0
                                                ? '${bonds.length} Bonds • Rs. ${formatNumber(denomWonAmount)} Won'
                                                : '${bonds.length} Bonds',
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
                                    Text(
                                      'Rs. ${formatNumber(totalVal)}',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w900,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface,
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
              onPressed: () => _showAddBondsDialog(context),
              icon: const Icon(Icons.add_box_outlined, size: 18),
              label: const Text('Add Bond'),
            ),
            const SizedBox(height: 12),
            FloatingActionButton.extended(
              heroTag: 'add_range',
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              onPressed: () => _showAddBondsDialog(context),
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
  final VoidCallback onBondsAdded;

  const _AddBondsDialog({
    required this.accessToken,
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
  bool _isRange = true;
  bool _isLoading = false;

  Future<void> _submit() async {
    setState(() => _isLoading = true);
    try {
      final res = _isRange
          ? await ApiService.addBondsRange(
              accessToken: widget.accessToken,
              denomination: _selectedDenomination,
              startNumber: _startNumController.text.trim(),
              endNumber: _endNumController.text.trim(),
            )
          : await ApiService.addBonds(
              accessToken: widget.accessToken,
              denomination: _selectedDenomination,
              bonds: _numbersController.text
                  .split(',')
                  .map((s) => s.trim())
                  .where((s) => s.isNotEmpty)
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
          message: msg,
          type: AppNotificationType.error,
        );
      }
    } catch (_) {
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
    return AlertDialog(
      title: const Text('Add Prize Bonds'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ToggleButtons(
              isSelected: [_isRange, !_isRange],
              onPressed: (index) => setState(() => _isRange = index == 0),
              color: Theme.of(context).colorScheme.onSurface,
              selectedColor: Theme.of(context).colorScheme.onPrimary,
              fillColor: AppColors.primary,
              borderRadius: BorderRadius.circular(8),
              children: const [
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.0),
                  child: Text('By Range'),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.0),
                  child: Text('By Numbers'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              initialValue: _selectedDenomination,
              decoration: const InputDecoration(
                labelText: 'Denomination',
                border: OutlineInputBorder(),
              ),
              items: BondOcrParser.denominations
                  .map((d) => DropdownMenuItem(value: d, child: Text('Rs. $d')))
                  .toList(),
              onChanged: (val) {
                if (val != null) setState(() => _selectedDenomination = val);
              },
            ),
            const SizedBox(height: 16),
            if (_isRange) ...[
              AppTextField(
                controller: _startNumController,
                keyboardType: TextInputType.number,
                labelText: 'Start Number (e.g. 000001)',
              ),
              const SizedBox(height: 16),
              AppTextField(
                controller: _endNumController,
                keyboardType: TextInputType.number,
                labelText: 'End Number (e.g. 000100)',
              ),
            ] else ...[
              AppTextField(
                controller: _numbersController,
                maxLines: 3,
                labelText: 'Bond Numbers (comma separated)',
                hintText: '123456, 654321, 789012',
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        AppButton(
          label: 'Add Bonds',
          isLoading: _isLoading,
          fullWidth: false,
          onPressed: _submit,
        ),
      ],
    );
  }
}
