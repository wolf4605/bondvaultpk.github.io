import 'dart:convert';

import 'package:flutter/material.dart';

import '../../config/app_theme.dart';
import '../../utils/api_service.dart';
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

  @override
  void initState() {
    super.initState();
    _bonds = widget.initialBonds.map((b) => b.toString()).toList();
    _fetchWinnings();
  }

  Future<void> _fetchWinnings() async {
    setState(() => _isLoadingWinnings = true);
    try {
      final data = await ApiService.fetchBondWinnings(widget.accessToken);
      if (data != null) {
        final results = data['results'] ?? [];
        final map = <String, List<Map<String, dynamic>>>{};
        for (final item in results) {
          if (item['denomination'] == widget.denomination) {
            final num = item['bond_number'].toString();
            map.putIfAbsent(num, () => []).add(item);
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

  void _deleteBond(String bondNumber) {
    showAppNotificationSheet(
      context: context,
      title: 'Remove Prize Bond',
      message:
          'Are you sure you want to remove bond number $bondNumber from your portfolio?',
      type: AppNotificationType.warning,
      dismissLabel: 'Cancel',
      customAction: AppButton(
        label: 'Confirm Delete',
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
                    'Bond number $bondNumber has been removed from portfolio successfully.',
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
      message: 'Congratulations! This bond has won official prize draws.',
      type: AppNotificationType.success,
      dismissLabel: 'Close',
      customAction: Column(
        children: winnings
            .map(
              (w) => AppCard(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                color: const Color(0xFFD1FAE5),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Prize: ${w['prize_name']} (Position ${w['prize_position']})',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Amount: Rs. ${w['prize_amount']}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Draw Date: ${w['draw_date']}',
                      style: const TextStyle(
                        fontSize: 12,
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
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Rs. ${widget.denomination} Bond List',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: _isLoadingWinnings
          ? const AppLoadingIndicator(message: 'Checking prize draw results...')
          : _bonds.isEmpty
          ? const AppEmptyState(
              icon: Icons.subtitles_off_outlined,
              title: 'No Bonds in List',
              message: 'All bonds in this denomination list have been removed.',
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _bonds.length,
              itemBuilder: (context, index) {
                final bond = _bonds[index];
                final isWinner = _winningsMap.containsKey(bond);
                final winnings = _winningsMap[bond] ?? [];
                final isDeleting = _deletingBondNumber == bond;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: AppCard(
                    padding: const EdgeInsets.all(12),
                    onTap: isWinner
                        ? () => _showWinningDetails(bond, winnings)
                        : null,
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: isWinner
                                ? AppColors.success
                                : AppColors.primary,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            isWinner
                                ? Icons.emoji_events
                                : Icons.confirmation_number,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                bond,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: isWinner
                                      ? AppColors.success
                                      : Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                isWinner
                                    ? '🎉 Winner! Tap for details'
                                    : 'Not drawn yet',
                                style: TextStyle(
                                  fontSize: 12,
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
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                AppColors.error,
                              ),
                            ),
                          )
                        else
                          IconButton(
                            icon: const Icon(
                              Icons.delete_outline,
                              color: AppColors.error,
                            ),
                            onPressed: () => _deleteBond(bond),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
