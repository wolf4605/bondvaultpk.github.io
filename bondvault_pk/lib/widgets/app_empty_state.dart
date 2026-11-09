import 'package:flutter/material.dart';

import '../config/app_theme.dart';
import '../config/responsive.dart';
import 'app_button.dart';

class AppEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Color? iconColor;

  const AppEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryIconColor =
        iconColor ??
        (isDark ? const Color(0xFF80BEA6) : AppColors.primaryContainer);

    final iconContainerSize = Responsive.w(context, 80);
    final iconSize = Responsive.w(context, 40);

    return Center(
      child: Padding(
        padding: EdgeInsets.all(Responsive.w(context, 24)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: iconContainerSize,
              height: iconContainerSize,
              decoration: BoxDecoration(
                color: primaryIconColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: iconSize, color: primaryIconColor),
            ),
            SizedBox(height: Responsive.h(context, 20)),
            Text(
              title,
              style: TextStyle(
                fontSize: Responsive.sp(context, 18),
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : AppColors.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: Responsive.h(context, 8)),
            Text(
              message,
              style: TextStyle(
                fontSize: Responsive.sp(context, 13),
                color: isDark ? Colors.white70 : AppColors.onSurfaceVariant,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            if (actionLabel != null && onAction != null) ...[
              SizedBox(height: Responsive.h(context, 24)),
              AppButton(
                label: actionLabel!,
                onPressed: onAction,
                fullWidth: false,
                padding: EdgeInsets.symmetric(
                  horizontal: Responsive.w(context, 24),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
