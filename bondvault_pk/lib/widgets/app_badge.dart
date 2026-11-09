import 'package:flutter/material.dart';

import '../config/app_theme.dart';
import '../config/responsive.dart';

enum AppBadgeType { success, warning, error, info, neutral }

class AppBadge extends StatelessWidget {
  final String label;
  final AppBadgeType type;
  final IconData? icon;
  final Color? backgroundColor;
  final Color? textColor;
  final Color? borderColor;
  final bool isSmall;

  const AppBadge({
    super.key,
    required this.label,
    this.type = AppBadgeType.neutral,
    this.icon,
    this.backgroundColor,
    this.textColor,
    this.borderColor,
    this.isSmall = false,
  });

  factory AppBadge.verified({bool isVerified = true}) {
    return AppBadge(
      label: isVerified ? 'Verified' : 'Verification Pending',
      type: isVerified ? AppBadgeType.success : AppBadgeType.warning,
      icon: isVerified ? Icons.verified : Icons.hourglass_top,
    );
  }

  factory AppBadge.admin() {
    return const AppBadge(
      label: '● ADMINISTRATOR',
      type: AppBadgeType.warning,
      isSmall: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color text;
    Color border;

    switch (type) {
      case AppBadgeType.success:
        bg = const Color(0xFF0F5132);
        text = Colors.white;
        border = const Color(0xFF80BEA6);
        break;
      case AppBadgeType.warning:
        bg = Colors.amber.shade800;
        text = Colors.white;
        border = Colors.amber.shade300;
        break;
      case AppBadgeType.error:
        bg = AppColors.error.withValues(alpha: 0.15);
        text = AppColors.error;
        border = AppColors.error.withValues(alpha: 0.4);
        break;
      case AppBadgeType.info:
        bg = Colors.blue.shade800;
        text = Colors.white;
        border = Colors.blue.shade300;
        break;
      case AppBadgeType.neutral:
        bg = Colors.grey.shade200;
        text = Colors.grey.shade800;
        border = Colors.grey.shade400;
        break;
    }

    if (backgroundColor != null) bg = backgroundColor!;
    if (textColor != null) text = textColor!;
    if (borderColor != null) border = borderColor!;

    final padding = isSmall
        ? EdgeInsets.symmetric(
            horizontal: Responsive.w(context, 8),
            vertical: Responsive.h(context, 2),
          )
        : EdgeInsets.symmetric(
            horizontal: Responsive.w(context, 10),
            vertical: Responsive.h(context, 4),
          );

    final fontSize = isSmall
        ? Responsive.sp(context, 10)
        : Responsive.sp(context, 11);

    final iconSize = isSmall
        ? Responsive.w(context, 11)
        : Responsive.w(context, 13);

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: iconSize, color: text),
            SizedBox(width: Responsive.w(context, 4)),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.bold,
                color: text,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
