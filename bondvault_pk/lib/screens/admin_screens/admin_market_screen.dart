import 'dart:convert';

import 'package:flutter/material.dart';

import '../../config/app_theme.dart';
import '../../config/responsive.dart';
import '../../utils/api_service.dart';
import '../../utils/app_utils.dart';
import '../../widgets/widgets.dart';

class AdminMarketScreen extends StatefulWidget {
  final String accessToken;

  const AdminMarketScreen({super.key, required this.accessToken});

  @override
  State<AdminMarketScreen> createState() => _AdminMarketScreenState();
}

class _AdminMarketScreenState extends State<AdminMarketScreen> {
  bool _isLoading = true;
  List<dynamic> _listings = [];

  String _filterCategory = 'All'; // 'All', 'buy', 'sell'
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String? _deletingId;

  @override
  void initState() {
    super.initState();
    _fetchListings();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchListings() async {
    setState(() => _isLoading = true);
    try {
      final list = await ApiService.fetchAdminMarketListings(
        widget.accessToken,
      );
      if (list != null && mounted) {
        setState(() {
          _listings = list;
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showDeleteDialog(Map<String, dynamic> item) async {
    final listingId = item['id']?.toString() ?? '';
    final title = item['title']?.toString() ?? 'Listing';
    final ownerUsername =
        item['owner_username']?.toString() ??
        item['username']?.toString() ??
        'User';
    final ownerEmail =
        item['owner_email']?.toString() ?? item['email']?.toString() ?? '';

    final reasonCtrl = TextEditingController(
      text: 'Violates marketplace community guidelines.',
    );
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
                        colors: [Color(0xFF8B0000), Color(0xFFBA1A1A)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.delete_forever_outlined,
                          color: Colors.white,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text(
                                'Delete Marketplace Listing',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Owner will receive an automated removal email',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFFFFDBAD),
                                ),
                              ),
                            ],
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
                        Text(
                          'Removing listing "$title" by @$ownerUsername ($ownerEmail)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'REASON FOR REMOVAL',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        AppTextField(
                          controller: reasonCtrl,
                          labelText: 'Reason sent to owner (min 3 chars)',
                          hintText: 'e.g. Violates marketplace rules or misleading price',
                          prefixIcon: const Icon(Icons.rate_review_outlined),
                          maxLines: 3,
                          validator: (v) {
                            if (v == null || v.trim().length < 3) {
                              return 'Reason must be at least 3 characters long';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),
                        AppButton(
                          label: 'Confirm Delete & Email Owner',
                          variant: AppButtonVariant.danger,
                          isLoading: isSubmitting,
                          icon: const Icon(Icons.send_outlined, size: 18),
                          onPressed: () async {
                            if (!formKey.currentState!.validate()) return;
                            setDialogState(() => isSubmitting = true);
                            final reason = reasonCtrl.text.trim();

                            try {
                              setState(() => _deletingId = listingId);
                              final res =
                                  await ApiService.deleteAdminMarketListing(
                                    accessToken: widget.accessToken,
                                    listingId: listingId,
                                    reason: reason,
                                  );

                              if (dialogContext.mounted) {
                                Navigator.pop(dialogContext);
                              }

                              if (!mounted) return;
                              if (res.statusCode == 200) {
                                _fetchListings();
                                showAppNotificationSheet(
                                  context: this.context,
                                  title: 'Listing Removed & Owner Notified',
                                  message:
                                      'Listing "$title" has been deleted. An automated removal notification email was sent to $ownerEmail.',
                                  type: AppNotificationType.success,
                                );
                              } else {
                                final data = jsonDecode(res.body);
                                showAppToast(
                                  this.context,
                                  data['detail'] ?? 'Failed to delete listing.',
                                  type: AppNotificationType.error,
                                );
                              }
                            } catch (e) {
                              if (!mounted) return;
                              showAppToast(
                                this.context,
                                'Error: $e',
                                type: AppNotificationType.error,
                              );
                            } finally {
                              if (mounted) setState(() => _deletingId = null);
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
      reasonCtrl.dispose();
    });
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _listings.where((item) {
      final category = item['category']?.toString().toLowerCase() ?? '';
      final title = item['title']?.toString().toLowerCase() ?? '';
      final price = item['price']?.toString() ?? '';
      final username = (item['owner_username'] ?? item['username'] ?? '')
          .toString()
          .toLowerCase();
      final email = (item['owner_email'] ?? item['email'] ?? '')
          .toString()
          .toLowerCase();

      bool matchesCategory = true;
      if (_filterCategory == 'buy') {
        matchesCategory = category == 'buy';
      } else if (_filterCategory == 'sell') {
        matchesCategory = category == 'sell';
      }

      final query = _searchQuery.toLowerCase().trim();
      bool matchesSearch =
          query.isEmpty ||
          title.contains(query) ||
          price.contains(query) ||
          username.contains(query) ||
          email.contains(query);

      return matchesCategory && matchesSearch;
    }).toList();

    int totalBuy = 0;
    int totalSell = 0;
    for (final item in _listings) {
      final cat = item['category']?.toString().toLowerCase();
      if (cat == 'buy') totalBuy++;
      if (cat == 'sell') totalSell++;
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'Marketplace Management',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const AppLoadingIndicator(
              message: 'Loading marketplace listings for admin moderation...',
            )
          : RefreshIndicator(
              onRefresh: _fetchListings,
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
                        // Stats Banner Card
                        AppCard(
                          padding: const EdgeInsets.all(18),
                          borderRadius: 20,
                          gradient: const LinearGradient(
                            colors: [Color(0xFF003527), Color(0xFF064E3B)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              Column(
                                children: [
                                  Text(
                                    '${_listings.length}',
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  const Text(
                                    'TOTAL POSTS',
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
                                    '$totalBuy',
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  const Text(
                                    'BUY OFFERS',
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
                                    '$totalSell',
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  const Text(
                                    'SELL OFFERS',
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
                        ),
                        const SizedBox(height: 20),

                        // Search and Filter Section
                        const AppSectionHeader(
                          title: 'All Active Listings',
                          tagline: 'MODERATION',
                        ),
                        const SizedBox(height: 8),

                        AppTextField(
                          controller: _searchController,
                          labelText: 'Search Listings',
                          hintText: 'e.g. 750 bond or @username',
                          prefixIcon: const Icon(Icons.search),
                          onChanged: (v) => setState(() => _searchQuery = v),
                        ),
                        const SizedBox(height: 12),

                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            ChoiceChip(
                              label: const Text('All Offers'),
                              selected: _filterCategory == 'All',
                              selectedColor: AppColors.primary,
                              labelStyle: TextStyle(
                                color: _filterCategory == 'All'
                                    ? Colors.white
                                    : AppColors.onSurface,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                              onSelected: (s) {
                                if (s) setState(() => _filterCategory = 'All');
                              },
                            ),
                            ChoiceChip(
                              label: const Text('Buy Offers'),
                              selected: _filterCategory == 'buy',
                              selectedColor: AppColors.primary,
                              labelStyle: TextStyle(
                                color: _filterCategory == 'buy'
                                    ? Colors.white
                                    : AppColors.onSurface,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                              onSelected: (s) {
                                if (s) setState(() => _filterCategory = 'buy');
                              },
                            ),
                            ChoiceChip(
                              label: const Text('Sell Offers'),
                              selected: _filterCategory == 'sell',
                              selectedColor: AppColors.primary,
                              labelStyle: TextStyle(
                                color: _filterCategory == 'sell'
                                    ? Colors.white
                                    : AppColors.onSurface,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                              onSelected: (s) {
                                if (s) setState(() => _filterCategory = 'sell');
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        filtered.isEmpty
                            ? const AppEmptyState(
                                icon: Icons.storefront_outlined,
                                title: 'No Listings Found',
                                message: 'No marketplace listings match your filter criteria.',
                              )
                            : ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: filtered.length,
                                itemBuilder: (context, index) {
                                  final item = filtered[index];
                                  final id = item['id']?.toString() ?? '';
                                  final title = item['title']?.toString() ?? '';
                                  final description =
                                      item['description']?.toString() ?? '';
                                  final price = item['price'] as int? ?? 0;
                                  final category =
                                      item['category']
                                          ?.toString()
                                          .toLowerCase() ??
                                      'sell';
                                  final ownerUsername =
                                      item['owner_username']?.toString() ??
                                      item['username']?.toString() ??
                                      'User';
                                  final ownerEmail =
                                      item['owner_email']?.toString() ??
                                      item['email']?.toString() ??
                                      '';
                                  final createdAt =
                                      item['created_at']?.toString() ?? '';

                                  final isBuy = category == 'buy';
                                  final isDeleting = _deletingId == id;

                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: AppCard(
                                      padding: const EdgeInsets.all(16),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              AppBadge(
                                                label: isBuy
                                                    ? 'BUY OFFER'
                                                    : 'SELL OFFER',
                                                type: isBuy
                                                    ? AppBadgeType.success
                                                    : AppBadgeType.warning,
                                                isSmall: true,
                                              ),
                                              Text(
                                                'Rs. ${formatNumber(price)}',
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w900,
                                                  color: AppColors.primary,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 10),
                                          Text(
                                            title,
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold,
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onSurface,
                                            ),
                                          ),
                                          if (description.isNotEmpty) ...[
                                            const SizedBox(height: 4),
                                            Text(
                                              description,
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .onSurfaceVariant,
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                          const SizedBox(height: 12),
                                          const Divider(height: 1),
                                          const SizedBox(height: 10),

                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Row(
                                                      children: [
                                                        const Icon(
                                                          Icons.person_outline,
                                                          size: 14,
                                                          color:
                                                              AppColors.primary,
                                                        ),
                                                        const SizedBox(
                                                          width: 4,
                                                        ),
                                                        Expanded(
                                                          child: Text(
                                                            '@$ownerUsername ($ownerEmail)',
                                                            style: const TextStyle(
                                                              fontSize: 11,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              color: AppColors
                                                                  .onSurface,
                                                            ),
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    if (createdAt
                                                        .isNotEmpty) ...[
                                                      const SizedBox(height: 2),
                                                      Text(
                                                        'Posted: $createdAt',
                                                        style: const TextStyle(
                                                          fontSize: 10,
                                                          color: AppColors
                                                              .onSurfaceVariant,
                                                        ),
                                                      ),
                                                    ],
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              isDeleting
                                                  ? const SizedBox(
                                                      width: 18,
                                                      height: 18,
                                                      child:
                                                          CircularProgressIndicator(
                                                            strokeWidth: 2,
                                                          ),
                                                    )
                                                  : ElevatedButton.icon(
                                                      style: ElevatedButton.styleFrom(
                                                        backgroundColor:
                                                            Colors.red,
                                                        foregroundColor:
                                                            Colors.white,
                                                        elevation: 1,
                                                        padding:
                                                            const EdgeInsets.symmetric(
                                                              horizontal: 10,
                                                              vertical: 6,
                                                            ),
                                                      ),
                                                      onPressed: () =>
                                                          _showDeleteDialog(
                                                            item,
                                                          ),
                                                      icon: const Icon(
                                                        Icons.delete_outline,
                                                        size: 14,
                                                      ),
                                                      label: const Text(
                                                        'Delete Listing',
                                                        style: TextStyle(
                                                          fontSize: 11,
                                                          fontWeight:
                                                              FontWeight.bold,
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
                ),
              ),
            ),
    );
  }
}
