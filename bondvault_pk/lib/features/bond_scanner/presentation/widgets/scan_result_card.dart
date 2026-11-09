import 'package:flutter/material.dart';

import '../../../../config/app_theme.dart';
import '../../../../utils/app_utils.dart';
import '../../../../widgets/widgets.dart';
import '../../data/models/recognition_result.dart';

class ScanResultCard extends StatelessWidget {
  final RecognitionResult result;
  final ValueChanged<String>? onCandidateSelected;

  const ScanResultCard({
    super.key,
    required this.result,
    this.onCandidateSelected,
  });

  @override
  Widget build(BuildContext context) {
    AppBadgeType badgeType;
    String statusTitle;

    switch (result.status) {
      case RecognitionStatus.success:
        badgeType = AppBadgeType.success;
        statusTitle = 'High Confidence';
        break;
      case RecognitionStatus.partial:
        badgeType = AppBadgeType.warning;
        statusTitle = 'Partial Recognition';
        break;
      case RecognitionStatus.uncertain:
        badgeType = AppBadgeType.warning;
        statusTitle = 'Uncertain Recognition';
        break;
      case RecognitionStatus.failed:
        badgeType = AppBadgeType.error;
        statusTitle = 'Recognition Failed';
        break;
    }

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'AI OCR RESULTS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                  color: AppColors.primary,
                ),
              ),
              AppBadge(label: statusTitle, type: badgeType, isSmall: true),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Detected Denomination',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      result.detectedDenomination != null
                          ? 'Rs. ${formatNumber(result.detectedDenomination!)}'
                          : 'Not Detected',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Detected Serial Number',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      result.detectedSerial != null &&
                              result.detectedSerial!.isNotEmpty
                          ? result.detectedSerial!
                          : 'Not Detected',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (result.serialCandidates.length > 1) ...[
            const SizedBox(height: 14),
            const Text(
              'Other Candidate Serials:',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: AppColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: result.serialCandidates.map((cand) {
                final isSelected = cand == result.detectedSerial;
                return ChoiceChip(
                  label: Text(
                    cand,
                    style: TextStyle(
                      fontSize: 12,
                      color: isSelected ? Colors.white : AppColors.onSurface,
                    ),
                  ),
                  selected: isSelected,
                  selectedColor: AppColors.primary,
                  onSelected: (sel) {
                    if (sel && onCandidateSelected != null) {
                      onCandidateSelected!(cand);
                    }
                  },
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}
