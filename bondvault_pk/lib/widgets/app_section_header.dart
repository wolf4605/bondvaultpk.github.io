import 'package:flutter/material.dart';

import '../config/app_theme.dart';
import '../config/responsive.dart';

class AppSectionHeader extends StatelessWidget {
  final String title;
  final String? tagline;
  final Widget? action;
  final EdgeInsetsGeometry? padding;

  const AppSectionHeader({
    super.key,
    required this.title,
    this.tagline,
    this.action,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final actionWidget = action;

    return Padding(
      padding:
          padding ?? EdgeInsets.symmetric(vertical: Responsive.h(context, 8)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (tagline != null && tagline!.isNotEmpty) ...[
                  Text(
                    tagline!.toUpperCase(),
                    style: TextStyle(
                      fontSize: Responsive.sp(context, 10),
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      color: isDark
                          ? const Color(0xFF80BEA6)
                          : AppColors.onSurfaceVariant,
                    ),
                  ),
                  SizedBox(height: Responsive.h(context, 2)),
                ],
                Text(
                  title,
                  style: TextStyle(
                    fontSize: Responsive.sp(context, 18),
                    fontWeight: FontWeight.w800,
                    color: isDark ? const Color(0xFFFAFAFF) : AppColors.primary,
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
          ),
          ?actionWidget,
        ],
      ),
    );
  }
}
