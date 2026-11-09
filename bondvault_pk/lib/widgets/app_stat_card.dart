import 'package:flutter/material.dart';

import '../config/app_theme.dart';
import '../config/responsive.dart';

class AppStatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final String? subtitle;
  final Color? iconColor;
  final Color? iconBackgroundColor;
  final VoidCallback? onTap;
  final Widget? badge;
  final Gradient? gradient;
  final EdgeInsetsGeometry? padding;

  const AppStatCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    this.subtitle,
    this.iconColor,
    this.iconBackgroundColor,
    this.onTap,
    this.badge,
    this.gradient,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryIconColor = iconColor ?? AppColors.primary;
    final bgIconColor =
        iconBackgroundColor ?? primaryIconColor.withValues(alpha: 0.12);
    final badgeWidget = badge;

    final responsivePadding =
        padding ??
        EdgeInsets.symmetric(
          horizontal: Responsive.w(context, 10),
          vertical: Responsive.h(context, 10),
        );

    Widget content = Container(
      padding: responsivePadding,
      decoration: BoxDecoration(
        color: gradient == null
            ? (isDark ? const Color(0xFF064E3B) : Colors.white)
            : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: EdgeInsets.all(Responsive.w(context, 5)),
                decoration: BoxDecoration(
                  color: bgIconColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  color: primaryIconColor,
                  size: Responsive.w(context, 16),
                ),
              ),
              if (badgeWidget != null)
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: badgeWidget,
                  ),
                ),
            ],
          ),
          SizedBox(height: Responsive.h(context, 6)),
          Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: Responsive.sp(context, 10),
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
              color: isDark ? Colors.white70 : AppColors.onSurfaceVariant,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: Responsive.h(context, 2)),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                fontSize: Responsive.sp(context, 18),
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : AppColors.onSurface,
                letterSpacing: -0.5,
              ),
            ),
          ),
          if (subtitle != null) ...[
            SizedBox(height: Responsive.h(context, 2)),
            Text(
              subtitle!,
              style: TextStyle(
                fontSize: Responsive.sp(context, 10),
                color: isDark ? Colors.white60 : Colors.grey.shade600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: content,
        ),
      );
    }

    return content;
  }
}
