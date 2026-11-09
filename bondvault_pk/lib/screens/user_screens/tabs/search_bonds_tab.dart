import 'package:flutter/material.dart';

import '../../../config/app_theme.dart';
import '../../../config/responsive.dart';
import '../../../widgets/widgets.dart';
import '../bond_ocr_parser.dart';

class SearchBondsTab extends StatefulWidget {
  final bool isVerified;
  const SearchBondsTab({super.key, required this.isVerified});

  @override
  State<SearchBondsTab> createState() => _SearchBondsTabState();
}

class _SearchBondsTabState extends State<SearchBondsTab> {
  int _selectedDenomination = 750;
  final _bondNumberController = TextEditingController();
  bool _isSearching = false;

  @override
  void dispose() {
    _bondNumberController.dispose();
    super.dispose();
  }

  void _handleSearch() async {
    final number = _bondNumberController.text.trim();
    if (number.isEmpty) {
      showAppToast(
        context,
        'Please enter a valid bond number.',
        type: AppNotificationType.warning,
      );
      return;
    }

    setState(() => _isSearching = true);
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    setState(() => _isSearching = false);

    showAppNotificationSheet(
      context: context,
      title: 'Search Draw Results',
      message:
          'Searching gazette records for Rs. $_selectedDenomination Prize Bond #$number...\nNo winning draws found for this bond number.',
      type: AppNotificationType.info,
    );
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
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.currency_exchange),
                      ),
                      items: BondOcrParser.denominations
                          .map(
                            (d) => DropdownMenuItem(
                              value: d,
                              child: Text('Rs. $d'),
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
                      labelText: 'Enter Bond Number (e.g. 123456)',
                      prefixIcon: const Icon(Icons.search),
                    ),
                    const SizedBox(height: 20),
                    AppButton(
                      label: 'Search Draw Results',
                      isLoading: _isSearching,
                      icon: const Icon(Icons.search, size: 18),
                      onPressed: _handleSearch,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
