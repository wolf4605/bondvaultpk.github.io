import 'dart:convert';

import 'package:flutter/material.dart';

import '../../config/app_theme.dart';
import '../../config/responsive.dart';
import '../../utils/api_service.dart';
import '../../utils/app_utils.dart';
import '../../widgets/widgets.dart';

class BondlistDetailScreen extends StatefulWidget {
  final int denomination;
  final List<dynamic> initialBonds;
  final String accessToken;
  final VoidCallback onBondsUpdated;

  const BondlistDetailScreen({
    super.key,
    required this.denomination,
    required this.initialBonds,
    required this.accessToken,
    required this.onBondsUpdated,
  });

  @override
  State<BondlistDetailScreen> createState() => _BondlistDetailScreenState();
}

class _BondlistDetailScreenState extends State<BondlistDetailScreen> {
  late List<String> _bonds;
  bool _isLoadingWinnings = true;
  Map<String, List<Map<String, dynamic>>> _winningsMap = {};
  String? _deletingBondNumber;

  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _filterMode = 'All'; // 'All', 'Winners', 'Standard'

  @override
  void initState() {
    super.initState();
    _bonds = widget.initialBonds.map((b) => b.toString()).toList();
    _fetchWinnings();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchWinnings() async {
    setState(() => _isLoadingWinnings = true);
    try {
      final data = await ApiService.fetchBondWinnings(widget.accessToken);
      if (data != null && mounted) {
        final results = data['results'] ?? [];
        final map = <String, List<Map<String, dynamic>>>{};
        for (final item in results) {
          if (item['denomination'] == widget.denomination) {
            final num = item['bond_number'].toString();
            map.putIfAbsent(num, () => []).add(Map<String, dynamic>.from(item));
          }
        }
        setState(() {
          _winningsMap = map;
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoadingWinnings = false);
    }
  }

  int get _totalWinningsAmount {
    int sum = 0;
    for (final list in _winningsMap.values) {
      for (final item in list) {
        sum += (item['prize_amount'] as int? ?? 0);
      }
    }
    return sum;
  }

  void _deleteBond(String bondNumber) {
    showAppNotificationSheet(
      context: context,
      title: 'Remove Prize Bond',
      message:
          'Are you sure you want to remove bond number $bondNumber from your portfolio?',
      type: AppNotificationType.warning,
      dismissLabel: 'Cancel',
      customAction: AppButton(
        label: 'Confirm Remove',
        variant: AppButtonVariant.danger,
        isLoading: _deletingBondNumber == bondNumber,
        onPressed: () async {
          Navigator.pop(context);
          setState(() {
            _deletingBondNumber = bondNumber;
          });
          try {
            final res = await ApiService.deleteBonds(
              accessToken: widget.accessToken,
              denomination: widget.denomination,
              bonds: [bondNumber],
            );

            if (!mounted) return;
            if (res.statusCode == 200) {
              setState(() {
                _bonds.remove(bondNumber);
              });
              widget.onBondsUpdated();
              showAppNotificationSheet(
                context: context,
                title: 'Bond Removed',
                message:
                    'Bond #$bondNumber removed from your Rs. ${widget.denomination} portfolio list.',
                type: AppNotificationType.success,
              );
            } else {
              final data = jsonDecode(res.body);
              showAppNotificationSheet(
                context: context,
                title: 'Delete Failed',
                message: data['detail'] ?? 'Failed to delete bond.',
                type: AppNotificationType.error,
              );
            }
          } catch (e) {
            if (!mounted) return;
            showAppNotificationSheet(
              context: context,
              title: 'Connection Error',
              message: 'Could not connect to server to delete bond.',
              type: AppNotificationType.error,
            );
          } finally {
            if (mounted) {
              setState(() {
                _deletingBondNumber = null;
              });
            }
          }
        },
      ),
    );
  }

  void _showWinningDetails(
    String bondNumber,
    List<Map<String, dynamic>> winnings,
  ) {
    showAppNotificationSheet(
      context: context,
      title: 'Winning Bond: $bondNumber',
      message:
          'Congratulations! Prize bond #$bondNumber has won official State Bank prize draws.',
      type: AppNotificationType.success,
      dismissLabel: 'Close',
      customAction: Column(
        children: winnings
            .map(
              (w) => AppCard(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(14),
                color: const Color(0xFFD1FAE5),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Prize Rank: ${w['prize_name'] ?? '${w['prize_position']} Prize'}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          'Rs. ${formatNumber(w['prize_amount'] as int? ?? 0)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Official Draw Date: ${w['draw_date'] ?? 'Official Draw'}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalPortfolioValue = _bonds.length * widget.denomination;
    final totalWinners = _winningsMap.keys.length;

    final filteredBonds = _bonds.where((bond) {
      final query = _searchQuery.trim().toLowerCase();
      bool matchesSearch = query.isEmpty || bond.contains(query);
      bool isWinner = _winningsMap.containsKey(bond);

      if (_filterMode == 'Winners') {
        return matchesSearch && isWinner;
      } else if (_filterMode == 'Standard') {
        return matchesSearch && !isWinner;
      }
      return matchesSearch;
    }).toList();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Rs. ${formatNumber(widget.denomination)} Bond List',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: _isLoadingWinnings
          ? const AppLoadingIndicator(
              message: 'Checking official prize draw results...',
            )
          : RefreshIndicator(
              onRefresh: _fetchWinnings,
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
                        // Portfolio Summary Card Banner
                        AppCard(
                          padding: const EdgeInsets.all(20),
                          borderRadius: 20,
                          gradient: const LinearGradient(
                            colors: [Color(0xFF003527), Color(0xFF064E3B)],
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
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(
                                            alpha: 0.15,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.account_balance_wallet_outlined,
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Text(
                                        'Rs. ${formatNumber(widget.denomination)} Portfolio',
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w900,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                  AppBadge(
                                    label: '${_bonds.length} Bonds',
                                    type: AppBadgeType.info,
                                    isSmall: true,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),

                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceAround,
                                children: [
                                  Column(
                                    children: [
                                      Text(
                                        'Rs. ${formatNumber(totalPortfolioValue)}',
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w900,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      const Text(
                                        'TOTAL INVESTMENT',
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
                                        '$totalWinners',
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w900,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      const Text(
                                        'WINNING BONDS',
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
                                        'Rs. ${formatNumber(_totalWinningsAmount)}',
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w900,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      const Text(
                                        'TOTAL PRIZES',
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
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Search and Filter Row
                        AppTextField(
                          controller: _searchController,
                          labelText: 'Search Bond Numbers',
                          hintText: 'e.g. 123456',
                          prefixIcon: const Icon(Icons.search),
                          onChanged: (v) => setState(() => _searchQuery = v),
                        ),
                        const SizedBox(height: 12),

                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            ChoiceChip(
                              label: Text('All (${_bonds.length})'),
                              selected: _filterMode == 'All',
                              selectedColor: AppColors.primary,
                              labelStyle: TextStyle(
                                color: _filterMode == 'All'
                                    ? Colors.white
                                    : AppColors.onSurface,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                              onSelected: (s) {
                                if (s) setState(() => _filterMode = 'All');
                              },
                            ),
                            ChoiceChip(
                              label: Text('Winners ($totalWinners)'),
                              selected: _filterMode == 'Winners',
                              selectedColor: AppColors.primary,
                              labelStyle: TextStyle(
                                color: _filterMode == 'Winners'
                                    ? Colors.white
                                    : AppColors.onSurface,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                              onSelected: (s) {
                                if (s) setState(() => _filterMode = 'Winners');
                              },
                            ),
                            ChoiceChip(
                              label: Text(
                                'Non-Winners (${_bonds.length - totalWinners})',
                              ),
                              selected: _filterMode == 'Standard',
                              selectedColor: AppColors.primary,
                              labelStyle: TextStyle(
                                color: _filterMode == 'Standard'
                                    ? Colors.white
                                    : AppColors.onSurface,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                              onSelected: (s) {
                                if (s) setState(() => _filterMode = 'Standard');
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Bonds List View
                        filteredBonds.isEmpty
                            ? const AppEmptyState(
                                icon: Icons.subtitles_off_outlined,
                                title: 'No Bonds Found',
                                message: 'No prize bond numbers match your search or filter options.',
                              )
                            : ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: filteredBonds.length,
                                itemBuilder: (context, index) {
                                  final bond = filteredBonds[index];
                                  final isWinner = _winningsMap.containsKey(
                                    bond,
                                  );
                                  final winnings = _winningsMap[bond] ?? [];
                                  final isDeleting =
                                      _deletingBondNumber == bond;

                                  int bondWinAmount = 0;
                                  for (final w in winnings) {
                                    bondWinAmount +=
                                        (w['prize_amount'] as int? ?? 0);
                                  }

                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: AppCard(
                                      padding: const EdgeInsets.all(14),
                                      onTap: isWinner
                                          ? () => _showWinningDetails(
                                              bond,
                                              winnings,
                                            )
                                          : null,
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 42,
                                            height: 42,
                                            decoration: BoxDecoration(
                                              color: isWinner
                                                  ? AppColors.success
                                                  : AppColors.primaryContainer,
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: Icon(
                                              isWinner
                                                  ? Icons.emoji_events
                                                  : Icons
                                                        .confirmation_number_outlined,
                                              color: Colors.white,
                                              size: 22,
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
                                                      bond,
                                                      style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.w900,
                                                        fontSize: 17,
                                                        letterSpacing: 0.5,
                                                        color: isWinner
                                                            ? AppColors.primary
                                                            : Theme.of(context)
                                                                  .colorScheme
                                                                  .onSurface,
                                                      ),
                                                    ),
                                                    if (isWinner) ...[
                                                      const SizedBox(width: 8),
                                                      AppBadge(
                                                        label:
                                                            'Rs. ${formatNumber(bondWinAmount)}',
                                                        type: AppBadgeType
                                                            .success,
                                                        isSmall: true,
                                                      ),
                                                    ],
                                                  ],
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  isWinner
                                                      ? '🎉 Winner in ${winnings.length} Draw(s)! Tap for details'
                                                      : 'Not drawn in gazette yet',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: isWinner
                                                        ? AppColors.success
                                                        : Theme.of(context)
                                                              .colorScheme
                                                              .onSurfaceVariant,
                                                    fontWeight: isWinner
                                                        ? FontWeight.bold
                                                        : FontWeight.normal,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          if (isDeleting)
                                            const SizedBox(
                                              width: 18,
                                              height: 18,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                            )
                                          else
                                            IconButton(
                                              icon: const Icon(
                                                Icons.delete_outline,
                                                color: Colors.red,
                                                size: 20,
                                              ),
                                              onPressed: () =>
                                                  _deleteBond(bond),
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
