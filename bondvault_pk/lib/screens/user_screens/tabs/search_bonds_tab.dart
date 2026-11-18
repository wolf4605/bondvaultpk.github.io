import 'package:flutter/material.dart';

import '../../../config/app_config.dart';
import '../../../config/app_theme.dart';
import '../../../config/responsive.dart';
import '../../../utils/api_service.dart';
import '../../../utils/app_utils.dart';
import '../../../widgets/widgets.dart';
import '../bond_ocr_parser.dart';

class SearchBondsTab extends StatefulWidget {
  final bool isVerified;
  final String accessToken;

  const SearchBondsTab({
    super.key,
    required this.isVerified,
    required this.accessToken,
  });

  @override
  State<SearchBondsTab> createState() => _SearchBondsTabState();
}

class _SearchBondsTabState extends State<SearchBondsTab> {
  int _selectedDenomination = 750;
  final _bondNumberController = TextEditingController();

  bool _isSearching = false;
  bool _hasSearched = false;
  List<dynamic> _searchResults = [];
  bool _isInPortfolio = false;
  bool _isAddingToPortfolio = false;
  String _searchedBondNo = '';

  @override
  void dispose() {
    _bondNumberController.dispose();
    super.dispose();
  }

  Future<void> _handleSearch() async {
    final raw = _bondNumberController.text.trim();
    if (raw.isEmpty || !RegExp(r'^[0-9]{1,6}$').hasMatch(raw)) {
      showAppToast(
        context,
        'Please enter a valid 1-to-6 digit bond number.',
        type: AppNotificationType.warning,
      );
      return;
    }

    final bondNo = raw.padLeft(6, '0');
    setState(() {
      _isSearching = true;
      _hasSearched = true;
      _searchResults = [];
      _isInPortfolio = false;
      _searchedBondNo = bondNo;
    });

    try {
      // 1. Search official gazette draw results
      final searchData = await ApiService.searchDrawResultsByNumber(
        denomination: _selectedDenomination,
        bondNumber: bondNo,
      );
      if (searchData != null && mounted) {
        _searchResults = searchData['results'] as List? ?? [];
      }

      // 2. Check if bond exists in user's saved portfolio
      if (widget.accessToken.isNotEmpty) {
        final bondlistData = await ApiService.fetchBondlists(
          widget.accessToken,
        );
        if (bondlistData != null && mounted) {
          final lists = bondlistData['bondlists']?['bondlists'] as List? ?? [];
          for (final list in lists) {
            if ((list['denomination'] as int? ?? 0) == _selectedDenomination) {
              final bonds = (list['bonds'] as List? ?? [])
                  .map((b) => b.toString())
                  .toList();
              if (bonds.contains(bondNo)) {
                _isInPortfolio = true;
                break;
              }
            }
          }
        }
      }
    } catch (e) {
      if (mounted) {
        showAppToast(
          context,
          'Search error: $e',
          type: AppNotificationType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  Future<void> _addToPortfolio() async {
    if (_searchedBondNo.isEmpty || widget.accessToken.isEmpty) return;

    setState(() => _isAddingToPortfolio = true);
    try {
      final res = await ApiService.addBonds(
        accessToken: widget.accessToken,
        denomination: _selectedDenomination,
        bonds: [_searchedBondNo],
      );

      if (!mounted) return;
      if (res.statusCode == 200) {
        setState(() => _isInPortfolio = true);
        showAppNotificationSheet(
          context: context,
          title: 'Bond Saved',
          message:
              'Prize bond #$_searchedBondNo added to your saved Rs. $_selectedDenomination portfolio list.',
          type: AppNotificationType.success,
        );
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isAddingToPortfolio = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
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
                title: 'Search Draw Results',
                tagline: 'SEARCH GAZETTE',
              ),
              const SizedBox(height: 12),

              // Search Input Card
              AppCard(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Select Denomination',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<int>(
                      initialValue: _selectedDenomination,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.money),
                      ),
                      items: AppDenominations.dropdownItems(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _selectedDenomination = val);
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Bond Number',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 6),
                    AppTextField(
                      controller: _bondNumberController,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      labelText: 'Enter Bond Number (e.g. 123456)',
                      prefixIcon: const Icon(Icons.search),
                      onFieldSubmitted: (_) => _handleSearch(),
                    ),
                    const SizedBox(height: 20),
                    AppButton(
                      label: 'Search Gazette Records',
                      isLoading: _isSearching,
                      icon: const Icon(Icons.search, size: 18),
                      onPressed: _handleSearch,
                    ),
                  ],
                ),
              ),

              if (_hasSearched) ...[
                const SizedBox(height: 24),

                // Portfolio Status Card
                AppCard(
                  padding: const EdgeInsets.all(16),
                  color: _isInPortfolio
                      ? const Color(0xFFD1FAE5)
                      : Colors.amber.shade50,
                  border: Border.all(
                    color: _isInPortfolio
                        ? AppColors.success
                        : Colors.amber.shade300,
                    width: 1.2,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _isInPortfolio
                            ? Icons.check_circle_outline
                            : Icons.bookmark_add_outlined,
                        color: _isInPortfolio
                            ? AppColors.primary
                            : Colors.amber.shade900,
                        size: 28,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _isInPortfolio
                                  ? 'Saved in Portfolio'
                                  : 'Not Saved in Portfolio',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: _isInPortfolio
                                    ? AppColors.primary
                                    : Colors.amber.shade900,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _isInPortfolio
                                  ? 'Bond #$_searchedBondNo is in your saved Rs. $_selectedDenomination list.'
                                  : 'Bond #$_searchedBondNo is not saved in your portfolio lists.',
                              style: TextStyle(
                                fontSize: 12,
                                color: _isInPortfolio
                                    ? AppColors.primary
                                    : Colors.amber.shade900,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!_isInPortfolio && widget.isVerified) ...[
                        const SizedBox(width: 8),
                        SizedBox(
                          height: 36,
                          child: AppButton(
                            label: '+ Save',
                            fullWidth: false,
                            isLoading: _isAddingToPortfolio,
                            onPressed: _addToPortfolio,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Gazette Search Results Section
                AppSectionHeader(
                  title: _searchResults.isNotEmpty
                      ? 'Won in ${_searchResults.length} Gazette Draw(s)'
                      : 'Gazette Search Results',
                  tagline: 'OFFICIAL MATCHES',
                ),
                const SizedBox(height: 8),

                _searchResults.isEmpty
                    ? AppEmptyState(
                        icon: Icons.find_in_page_outlined,
                        title: 'No Winning Draws Found',
                        message:
                            'Prize bond #$_searchedBondNo was not drawn as a winner in any official Rs. $_selectedDenomination gazette draws.',
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _searchResults.length,
                        itemBuilder: (context, index) {
                          final item = _searchResults[index];
                          final pos = item['prize_position'] as int? ?? 0;
                          final prizeName =
                              item['prize_name']?.toString() ?? '$pos Prize';
                          final prizeAmount = item['prize_amount'] as int? ?? 0;
                          final drawDate = item['draw_date']?.toString() ?? '';

                          AppBadgeType badgeType;
                          if (pos == 1) {
                            badgeType = AppBadgeType.warning;
                          } else if (pos == 2) {
                            badgeType = AppBadgeType.success;
                          } else {
                            badgeType = AppBadgeType.info;
                          }

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: AppCard(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: AppColors.primaryContainer
                                              .withValues(alpha: 0.1),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.emoji_events,
                                          color: AppColors.primary,
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          AppBadge(
                                            label: prizeName,
                                            type: badgeType,
                                            isSmall: true,
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Draw Date: $drawDate',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  Text(
                                    'Rs. ${formatNumber(prizeAmount)}',
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w900,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
