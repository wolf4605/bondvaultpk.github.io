import 'package:flutter/material.dart';

import '../../../config/app_theme.dart';
import '../../../config/responsive.dart';
import '../../../widgets/widgets.dart';

class MarketplaceTab extends StatelessWidget {
  final bool isVerified;
  const MarketplaceTab({super.key, required this.isVerified});

  @override
  Widget build(BuildContext context) {
    if (!isVerified) {
      return const AppEmptyState(
        icon: Icons.storefront_outlined,
        title: 'Feature Locked',
        message: 'Your account is currently under verification review. Marketplace trading will unlock automatically once approved.',
      );
    }
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
                title: 'Prize Bond Marketplace',
                tagline: 'TRADE & OFFERS',
              ),
              const SizedBox(height: 12),
              AppCard(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.storefront_outlined,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'Rs. 750 Prize Bond (Series A)',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.onSurface,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              AppBadge(
                                label: 'SELL',
                                type: AppBadgeType.info,
                                isSmall: true,
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Asking Price: Rs. 750 | Serial: 004921',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    AppButton(
                      label: 'Contact',
                      fullWidth: false,
                      height: 38,
                      onPressed: () {
                        showAppToast(
                          context,
                          'Contacting seller...',
                          type: AppNotificationType.info,
                        );
                      },
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
