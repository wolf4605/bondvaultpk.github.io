import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../config/app_theme.dart';
import '../../../config/responsive.dart';
import '../../../utils/api_service.dart';
import '../../../utils/app_utils.dart';
import '../../../widgets/widgets.dart';

class MarketplaceTab extends StatefulWidget {
  final bool isVerified;
  final String accessToken;
  final String userId;

  const MarketplaceTab({
    super.key,
    required this.isVerified,
    required this.accessToken,
    this.userId = '',
  });

  @override
  State<MarketplaceTab> createState() => _MarketplaceTabState();
}

class _MarketplaceTabState extends State<MarketplaceTab>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  List<dynamic> _listings = [];
  String _categoryFilter = 'All'; // 'All', 'sell', 'buy'
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    if (widget.isVerified) {
      _fetchListings();
    } else {
      _isLoading = false;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchListings() async {
    setState(() => _isLoading = true);
    try {
      final list = await ApiService.fetchMarketListings(widget.accessToken);
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

  String _getTimeAgo(String createdAt) {
    if (createdAt.isEmpty) return 'Recent';
    try {
      final date = DateTime.tryParse(createdAt);
      if (date == null) return createdAt;
      final diff = DateTime.now().difference(date);
      if (diff.inMinutes < 60) {
        final mins = diff.inMinutes <= 0 ? 1 : diff.inMinutes;
        return '$mins ${mins == 1 ? 'min' : 'mins'} ago';
      } else if (diff.inHours < 24) {
        return '${diff.inHours} ${diff.inHours == 1 ? 'hour' : 'hours'} ago';
      } else if (diff.inDays < 30) {
        return '${diff.inDays} ${diff.inDays == 1 ? 'day' : 'days'} ago';
      } else {
        return createdAt.split('T')[0];
      }
    } catch (_) {
      return createdAt;
    }
  }

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    } else if (parts.isNotEmpty && parts[0].isNotEmpty) {
      return parts[0][0].toUpperCase();
    }
    return 'VT';
  }

  Future<void> _showListingDialog({
    bool isEdit = false,
    Map<String, dynamic>? listing,
  }) async {
    final titleController = TextEditingController(
      text: isEdit ? (listing?['title']?.toString() ?? '') : '',
    );
    final priceController = TextEditingController(
      text: isEdit ? (listing?['price']?.toString() ?? '') : '',
    );
    final descController = TextEditingController(
      text: isEdit ? (listing?['description']?.toString() ?? '') : '',
    );
    String category = isEdit
        ? (listing?['category']?.toString().toLowerCase() ?? 'sell')
        : 'sell';
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
              maxHeight: MediaQuery.sizeOf(context).height * 0.85,
            ),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header Banner
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 18,
                    ),
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
                            isEdit ? Icons.edit_note : Icons.add_shopping_cart,
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
                                isEdit
                                    ? 'Edit Marketplace Listing'
                                    : 'Create Market Listing',
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                isEdit
                                    ? 'Update your bond offer details'
                                    : 'Post a new bond buy/sell listing',
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
                          onPressed: () => Navigator.pop(dialogContext),
                        ),
                      ],
                    ),
                  ),

                  // Body Form
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                        // Category Selector (Sell vs Buy)
                        const Text(
                          'Listing Category',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: ChoiceChip(
                                label: const Center(
                                  child: Text(
                                    'SELL OFFER',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                selected: category == 'sell',
                                selectedColor: AppColors.primary,
                                labelStyle: TextStyle(
                                  color: category == 'sell'
                                      ? Colors.white
                                      : AppColors.onSurface,
                                ),
                                onSelected: (sel) {
                                  if (sel) {
                                    setDialogState(() => category = 'sell');
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: ChoiceChip(
                                label: const Center(
                                  child: Text(
                                    'BUY REQUEST',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                selected: category == 'buy',
                                selectedColor: AppColors.secondary,
                                labelStyle: TextStyle(
                                  color: category == 'buy'
                                      ? Colors.white
                                      : AppColors.onSurface,
                                ),
                                onSelected: (sel) {
                                  if (sel) {
                                    setDialogState(() => category = 'buy');
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        const Text(
                          'Listing Title',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        AppTextField(
                          controller: titleController,
                          labelText: 'e.g. Rs. 750 Prize Bond (Series A)',
                          prefixIcon: const Icon(Icons.title),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Listing title is required';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),

                        const Text(
                          'Asking Price (PKR)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        AppTextField(
                          controller: priceController,
                          keyboardType: TextInputType.number,
                          labelText: 'Price in Rs. (e.g. 750)',
                          prefixIcon: const Icon(Icons.attach_money),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Price is required';
                            }
                            final p = int.tryParse(v.trim());
                            if (p == null || p < 0) {
                              return 'Must be a valid non-negative price';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),

                        const Text(
                          'Description (Optional)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        AppTextField(
                          controller: descController,
                          maxLines: 3,
                          labelText:
                              'Additional bond details, serials or notes',
                          hintText:
                              'e.g. Clean series bond available in Lahore.',
                          prefixIcon: const Icon(Icons.notes),
                        ),
                        const SizedBox(height: 24),

                        AppButton(
                          label: isEdit
                              ? 'Update Listing'
                              : 'Publish Market Listing',
                          isLoading: isSubmitting,
                          icon: Icon(
                            isEdit ? Icons.save_outlined : Icons.publish,
                            size: 18,
                          ),
                          onPressed: () async {
                            if (formKey.currentState!.validate()) {
                              setDialogState(() => isSubmitting = true);
                              try {
                                final title = titleController.text.trim();
                                final price = int.parse(
                                  priceController.text.trim(),
                                );
                                final desc = descController.text.trim().isEmpty
                                    ? null
                                    : descController.text.trim();

                                final res = isEdit
                                    ? await ApiService.updateMarketListing(
                                        accessToken: widget.accessToken,
                                        listingId: listing!['id'].toString(),
                                        title: title,
                                        price: price,
                                        category: category,
                                        description: desc,
                                      )
                                    : await ApiService.createMarketListing(
                                        accessToken: widget.accessToken,
                                        title: title,
                                        price: price,
                                        category: category,
                                        description: desc,
                                      );

                                if (res.statusCode == 200 ||
                                    res.statusCode == 201) {
                                  _fetchListings();
                                  if (!dialogContext.mounted) return;
                                  Navigator.pop(dialogContext);
                                  if (!mounted) return;
                                  showAppNotificationSheet(
                                    context: context,
                                    title: isEdit
                                        ? 'Listing Updated'
                                        : 'Listing Published',
                                    message: isEdit
                                        ? 'Your marketplace listing has been updated successfully.'
                                        : 'Your new bond offer is live on the marketplace!',
                                    type: AppNotificationType.success,
                                  );
                                } else {
                                  final data = jsonDecode(res.body);
                                  final msg =
                                      data['detail'] ?? 'Operation failed.';
                                  if (!dialogContext.mounted) return;
                                  showAppToast(
                                    dialogContext,
                                    msg.toString(),
                                    type: AppNotificationType.error,
                                  );
                                }
                              } catch (e) {
                                if (!mounted) return;
                                showAppToast(
                                  context,
                                  'Error: $e',
                                  type: AppNotificationType.error,
                                );
                              } finally {
                                if (dialogContext.mounted) {
                                  setDialogState(() => isSubmitting = false);
                                }
                              }
                            }
                          },
                        ),
                      ],
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

    titleController.dispose();
    priceController.dispose();
    descController.dispose();
  }

  Future<void> _deleteListing(String listingId) async {
    showAppNotificationSheet(
      context: context,
      title: 'Delete Listing',
      message:
          'Are you sure you want to remove this listing from the marketplace?',
      type: AppNotificationType.error,
      dismissLabel: 'Cancel',
      customAction: AppButton(
        label: 'Confirm Delete',
        variant: AppButtonVariant.danger,
        onPressed: () async {
          Navigator.pop(context);
          setState(() => _isLoading = true);
          try {
            final res = await ApiService.deleteMarketListing(
              accessToken: widget.accessToken,
              listingId: listingId,
            );
            if (res.statusCode == 200) {
              _fetchListings();
              if (!mounted) return;
              showAppNotificationSheet(
                context: context,
                title: 'Listing Removed',
                message: 'Marketplace listing deleted successfully.',
                type: AppNotificationType.success,
              );
            } else {
              if (!mounted) return;
              showAppToast(
                context,
                'Failed to delete listing.',
                type: AppNotificationType.error,
              );
            }
          } catch (_) {
          } finally {
            if (mounted) setState(() => _isLoading = false);
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isVerified) {
      return const AppEmptyState(
        icon: Icons.storefront_outlined,
        title: 'Feature Locked',
        message: 'Your account is currently under verification review. Marketplace trading will unlock automatically once approved.',
      );
    }

    final myUserId = widget.userId.trim();
    final myListings = _listings.where((item) {
      final ownerId = item['posted_by']?.toString() ?? '';
      return ownerId.isNotEmpty && ownerId == myUserId;
    }).toList();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'Prize Bond Marketplace',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: Colors.grey,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold),
          tabs: [
            Tab(
              icon: const Icon(Icons.storefront_outlined),
              text: 'Marketplace (${_listings.length})',
            ),
            Tab(
              icon: const Icon(Icons.sell_outlined),
              text: 'My Listings (${myListings.length})',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: Marketplace Overview
          _buildMarketplaceTab(),

          // Tab 2: My Listings
          _buildMyListingsTab(myListings),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        onPressed: () => _showListingDialog(isEdit: false),
        icon: const Icon(Icons.add),
        label: const Text('New Listing'),
      ),
    );
  }

  Widget _buildMarketplaceTab() {
    final filtered = _listings.where((item) {
      final title = (item['title'] ?? '').toString().toLowerCase();
      final category = (item['category'] ?? '').toString().toLowerCase();

      bool matchesCat =
          _categoryFilter == 'All' ||
          (_categoryFilter == 'sell' && category == 'sell') ||
          (_categoryFilter == 'buy' && category == 'buy');

      bool matchesSearch =
          _searchQuery.isEmpty ||
          title.contains(_searchQuery.trim().toLowerCase());

      return matchesCat && matchesSearch;
    }).toList();

    return _isLoading
        ? const AppLoadingIndicator(message: 'Fetching marketplace listings...')
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
                      const AppSectionHeader(
                        title: 'Active Market Offers',
                        tagline: 'TRADE & OFFERS',
                      ),
                      const SizedBox(height: 8),

                      // Search Bar
                      AppTextField(
                        controller: _searchController,
                        labelText: 'Search Marketplace Offers',
                        hintText: 'e.g. Rs. 750, Series A',
                        prefixIcon: const Icon(Icons.search),
                        onChanged: (v) => setState(() => _searchQuery = v),
                      ),
                      const SizedBox(height: 12),

                      // Category Filter Chips
                      Wrap(
                        spacing: 8,
                        children: [
                          ChoiceChip(
                            label: const Text('All Offers'),
                            selected: _categoryFilter == 'All',
                            selectedColor: AppColors.primary,
                            labelStyle: TextStyle(
                              color: _categoryFilter == 'All'
                                  ? Colors.white
                                  : AppColors.onSurface,
                            ),
                            onSelected: (s) {
                              if (s) setState(() => _categoryFilter = 'All');
                            },
                          ),
                          ChoiceChip(
                            label: const Text('Sell Offers'),
                            selected: _categoryFilter == 'sell',
                            selectedColor: AppColors.primary,
                            labelStyle: TextStyle(
                              color: _categoryFilter == 'sell'
                                  ? Colors.white
                                  : AppColors.onSurface,
                            ),
                            onSelected: (s) {
                              if (s) setState(() => _categoryFilter = 'sell');
                            },
                          ),
                          ChoiceChip(
                            label: const Text('Buy Requests'),
                            selected: _categoryFilter == 'buy',
                            selectedColor: AppColors.secondary,
                            labelStyle: TextStyle(
                              color: _categoryFilter == 'buy'
                                  ? Colors.white
                                  : AppColors.onSurface,
                            ),
                            onSelected: (s) {
                              if (s) setState(() => _categoryFilter = 'buy');
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      filtered.isEmpty
                          ? const AppEmptyState(
                              icon: Icons.storefront_outlined,
                              title: 'No Market Listings Found',
                              message: 'No active marketplace listings match your selected filter.',
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: filtered.length,
                              itemBuilder: (context, index) {
                                final item = filtered[index];
                                return _buildListingCard(item, isMine: false);
                              },
                            ),
                    ],
                  ),
                ),
              ),
            ),
          );
  }

  Widget _buildMyListingsTab(List<dynamic> myListings) {
    return _isLoading
        ? const AppLoadingIndicator(message: 'Fetching your listings...')
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
                      const AppSectionHeader(
                        title: 'My Published Listings',
                        tagline: 'MY OFFERS',
                      ),
                      const SizedBox(height: 12),
                      myListings.isEmpty
                          ? const AppEmptyState(
                              icon: Icons.post_add_outlined,
                              title: 'No Listings Published Yet',
                              message: 'Tap the + New Listing button below to post a prize bond buy or sell offer to the marketplace.',
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: myListings.length,
                              itemBuilder: (context, index) {
                                final item = myListings[index];
                                return _buildListingCard(item, isMine: true);
                              },
                            ),
                    ],
                  ),
                ),
              ),
            ),
          );
  }

  Widget _buildListingCard(Map<String, dynamic> item, {required bool isMine}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final title = item['title']?.toString() ?? 'Prize Bond Offer';
    final price = item['price'] as int? ?? 0;
    final category = item['category']?.toString().toUpperCase() ?? 'SELL';
    final description = item['description']?.toString() ?? '';
    final createdAt = item['created_at']?.toString() ?? '';
    final listingId = item['id']?.toString() ?? '';

    final ownerName = (item['owner_name']?.toString() ?? '').trim();
    final ownerUsername = (item['owner_username']?.toString() ?? '').trim();
    final ownerContact = (item['owner_contact']?.toString() ?? '').trim();
    final ownerEmail = (item['owner_email']?.toString() ?? '').trim();

    final sellerDisplayName = ownerName.isNotEmpty
        ? ownerName
        : (ownerUsername.isNotEmpty ? ownerUsername : 'Verified Trader');
    final sellerHandle = ownerUsername.isNotEmpty
        ? '@$ownerUsername'
        : '@trader';
    final sellerPhone = ownerContact.isNotEmpty
        ? ownerContact
        : '+92 300 1234567';
    final sellerMail = ownerEmail.isNotEmpty ? ownerEmail : 'seller@domain.pk';
    final sellerInitials = _getInitials(sellerDisplayName);
    final timeAgo = _getTimeAgo(createdAt);

    final isSell = category == 'SELL';
    final categoryLabel = isSell ? 'SELL LISTING' : 'BUY REQUEST';
    final categoryColor = isSell
        ? const Color(0xFF012F21)
        : const Color(0xFF904D00);
    final priceColor = isSell
        ? const Color(0xFF003527)
        : const Color(0xFF904D00);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: AppCard(
        padding: const EdgeInsets.all(18),
        borderRadius: 20,
        color: isDark ? const Color(0xFF064E3B) : Colors.white,
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.grey.shade200,
          width: 1.5,
        ),
        elevation: 2,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: Category Pill Badge (Left) & Time Ago (Right)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: categoryColor,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        categoryLabel,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    Icon(
                      Icons.access_time,
                      size: 13,
                      color: isDark ? Colors.white60 : Colors.grey.shade600,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      timeAgo,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white60 : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Row 2: Title
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : AppColors.onSurface,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 12),

            // Row 3: Total Asking Price Box (Simplified: Title + Price)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.25)
                    : const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isSell ? 'TOTAL ASKING PRICE' : 'OFFERING PRICE (TOTAL)',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                      color: isDark ? Colors.white60 : Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Rs. ${formatNumber(price)}',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : priceColor,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
            ),
            if (description.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                description,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white70 : AppColors.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
            ],
            const SizedBox(height: 14),

            // Row 4: Seller Profile Box (Simplified: Avatar, Name, Handle, Location, Phone, Email)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF022C22).withValues(alpha: 0.5)
                    : const Color(0xFFEEF2FF),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? Colors.white10 : const Color(0xFFE0E7FF),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      // Avatar Pod with Checkmark
                      Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: isSell
                                ? const Color(0xFF012F21)
                                : const Color(0xFF904D00),
                            child: Text(
                              sellerInitials,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check_circle,
                              size: 12,
                              color: Color(0xFF10B981),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    sellerDisplayName,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: isDark
                                          ? Colors.white
                                          : AppColors.onSurface,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(
                                  Icons.verified,
                                  size: 14,
                                  color: Color(0xFF2563EB),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Text(
                                  '$sellerHandle • ',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark
                                        ? Colors.white60
                                        : Colors.grey.shade600,
                                  ),
                                ),
                                const Icon(
                                  Icons.location_on_outlined,
                                  size: 11,
                                  color: Color(0xFFEF4444),
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  'Lahore, Punjab',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark
                                        ? Colors.white60
                                        : Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(
                        Icons.phone_outlined,
                        size: 13,
                        color: isDark
                            ? Colors.white70
                            : AppColors.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        sellerPhone,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white70 : AppColors.onSurface,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Icon(
                        Icons.email_outlined,
                        size: 13,
                        color: isDark
                            ? Colors.white70
                            : AppColors.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          sellerMail,
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark
                                ? Colors.white70
                                : AppColors.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Row 5: Action Button Row
            if (isMine) ...[
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 44,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          side: const BorderSide(color: AppColors.primary),
                        ),
                        onPressed: () =>
                            _showListingDialog(isEdit: true, listing: item),
                        icon: const Icon(Icons.edit_outlined, size: 16),
                        label: const Text(
                          'Edit Listing',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    height: 44,
                    width: 48,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        side: BorderSide(color: Colors.red.shade300),
                      ),
                      onPressed: () => _deleteListing(listingId),
                      child: const Icon(
                        Icons.delete_outline,
                        color: Colors.red,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ] else ...[
              // Single Chat on WhatsApp Button (Matching image style)
              SizedBox(
                height: 44,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF012F21),
                    foregroundColor: Colors.white,
                    elevation: 1,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    showAppNotificationSheet(
                      context: context,
                      title: 'Contact Seller Info',
                      message:
                          'Seller: $sellerDisplayName ($sellerHandle)\n\n'
                          '📱 Phone / WhatsApp:\n$sellerPhone\n\n'
                          '✉️ Email Address:\n$sellerMail\n\n'
                          'Listing: $title (Rs. ${formatNumber(price)})',
                      type: AppNotificationType.info,
                      dismissLabel: 'Close Details',
                    );
                  },
                  icon: const Icon(Icons.chat_bubble_outline, size: 16),
                  label: const Text(
                    'Chat on WhatsApp',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
