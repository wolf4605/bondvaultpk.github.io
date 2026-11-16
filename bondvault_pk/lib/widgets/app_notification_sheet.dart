import 'package:flutter/material.dart';

import '../config/app_theme.dart';
import '../config/responsive.dart';

enum AppNotificationType { success, error, warning, info }

class AppNotificationSheet extends StatelessWidget {
  final String title;
  final String message;
  final AppNotificationType type;
  final String dismissLabel;
  final VoidCallback? onDismiss;
  final Widget? customAction;

  const AppNotificationSheet({
    super.key,
    required this.title,
    required this.message,
    this.type = AppNotificationType.error,
    this.dismissLabel = 'Dismiss',
    this.onDismiss,
    this.customAction,
  });

  @override
  Widget build(BuildContext context) {
    final isLandscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    final mediaQuery = MediaQuery.of(context);

    Color iconBgColor;
    Color iconColor;
    IconData icon;

    switch (type) {
      case AppNotificationType.success:
        iconBgColor = const Color(0xFFD1FAE5);
        iconColor = AppColors.success;
        icon = Icons.check_circle_outline;
        break;
      case AppNotificationType.error:
        iconBgColor = Colors.red.shade50;
        iconColor = AppColors.error;
        icon = Icons.error_outline;
        break;
      case AppNotificationType.warning:
        iconBgColor = Colors.amber.shade50;
        iconColor = AppColors.warning;
        icon = Icons.warning_amber_rounded;
        break;
      case AppNotificationType.info:
        iconBgColor = Colors.blue.shade50;
        iconColor = Colors.blue.shade700;
        icon = Icons.info_outline;
        break;
    }

    final verticalSpacer = isLandscape ? 12.0 : 20.0;
    final iconSize = isLandscape ? 48.0 : 64.0;
    final innerIconSize = isLandscape ? 26.0 : 34.0;

    return Align(
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: Responsive.maxContentWidth(context),
          maxHeight: mediaQuery.size.height * 0.90,
        ),
        child: Container(
          padding: EdgeInsets.fromLTRB(
            Responsive.w(context, 20),
            Responsive.h(context, 10),
            Responsive.w(context, 20),
            Responsive.h(context, 24),
          ),
          decoration: const BoxDecoration(
            color: AppColors.surfaceCard,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 20,
                offset: Offset(0, -4),
              ),
            ],
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag handle
                Container(
                  width: Responsive.w(context, 40),
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                SizedBox(height: verticalSpacer),
                // Icon Badge
                Container(
                  width: iconSize,
                  height: iconSize,
                  decoration: BoxDecoration(
                    color: iconBgColor,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: iconColor, size: innerIconSize),
                ),
                SizedBox(height: verticalSpacer),
                // Title
                Text(
                  title,
                  style: TextStyle(
                    fontSize: Responsive.sp(context, 18),
                    fontWeight: FontWeight.w900,
                    color: AppColors.onSurface,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                // Message
                Text(
                  message,
                  style: TextStyle(
                    fontSize: Responsive.sp(context, 13),
                    color: AppColors.onSurfaceVariant,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: verticalSpacer + 4),
                if (customAction != null) ...[
                  customAction!,
                  const SizedBox(height: 10),
                ],
                // Dismiss Button
                SizedBox(
                  width: double.infinity,
                  height: Responsive.h(context, 48),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      onDismiss?.call();
                    },
                    child: Text(
                      dismissLabel,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: Responsive.sp(context, 15),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

void showAppNotificationSheet({
  required BuildContext context,
  required String title,
  required String message,
  AppNotificationType type = AppNotificationType.error,
  String dismissLabel = 'Dismiss',
  VoidCallback? onDismiss,
  Widget? customAction,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => AppNotificationSheet(
      title: title,
      message: message,
      type: type,
      dismissLabel: dismissLabel,
      onDismiss: onDismiss,
      customAction: customAction,
    ),
  );
}
