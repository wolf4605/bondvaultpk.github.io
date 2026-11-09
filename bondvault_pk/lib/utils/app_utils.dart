import 'package:flutter/material.dart';

import '../widgets/app_badge.dart';
import '../widgets/app_notification_sheet.dart';

Widget buildVerifiedBadge(bool isVerified) {
  return AppBadge.verified(isVerified: isVerified);
}

String formatNumber(int number) {
  return number.toString().replaceAllMapped(
    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
    (Match m) => '${m[1]},',
  );
}

void showErrorBottomSheet({
  required BuildContext context,
  required String title,
  required String message,
  VoidCallback? onDismiss,
}) {
  showAppNotificationSheet(
    context: context,
    title: title,
    message: message,
    type: AppNotificationType.error,
    onDismiss: onDismiss,
  );
}

void showSuccessBottomSheet({
  required BuildContext context,
  required String title,
  required String message,
  VoidCallback? onDismiss,
}) {
  showAppNotificationSheet(
    context: context,
    title: title,
    message: message,
    type: AppNotificationType.success,
    onDismiss: onDismiss,
  );
}
