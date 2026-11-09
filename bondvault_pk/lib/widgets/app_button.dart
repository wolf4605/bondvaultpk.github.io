import 'package:flutter/material.dart';

import '../config/app_theme.dart';
import '../config/responsive.dart';

enum AppButtonVariant { primary, secondary, outlined, danger, text }

class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final bool isLoading;
  final Widget? icon;
  final bool fullWidth;
  final double height;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;

  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.isLoading = false,
    this.icon,
    this.fullWidth = true,
    this.height = 50,
    this.borderRadius = 12,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final isDisabled = onPressed == null || isLoading;
    final responsiveHeight = Responsive.h(context, height);

    Widget child;
    if (isLoading) {
      child = SizedBox(
        width: Responsive.w(context, 20),
        height: Responsive.w(context, 20),
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          valueColor: AlwaysStoppedAnimation<Color>(_loadingColor(context)),
        ),
      );
    } else {
      child = Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[
            icon!,
            SizedBox(width: Responsive.w(context, 6)),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: Responsive.sp(context, 14),
                fontWeight: FontWeight.bold,
                letterSpacing: -0.2,
              ),
            ),
          ),
        ],
      );
    }

    ButtonStyle buttonStyle;
    final radius = BorderRadius.circular(borderRadius);
    final responsivePadding =
        padding ?? EdgeInsets.symmetric(horizontal: Responsive.w(context, 12));

    switch (variant) {
      case AppButtonVariant.primary:
        buttonStyle = ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.4),
          disabledForegroundColor: Colors.white60,
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: radius),
          padding: responsivePadding,
        );
        break;
      case AppButtonVariant.secondary:
        buttonStyle = ElevatedButton.styleFrom(
          backgroundColor: AppColors.secondaryContainer,
          foregroundColor: AppColors.onSecondaryContainer,
          elevation: 1,
          shape: RoundedRectangleBorder(borderRadius: radius),
          padding: responsivePadding,
        );
        break;
      case AppButtonVariant.outlined:
        buttonStyle = OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: radius),
          padding: responsivePadding,
        );
        break;
      case AppButtonVariant.danger:
        buttonStyle = ElevatedButton.styleFrom(
          backgroundColor: AppColors.error,
          foregroundColor: Colors.white,
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: radius),
          padding: responsivePadding,
        );
        break;
      case AppButtonVariant.text:
        buttonStyle = TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          padding:
              padding ??
              EdgeInsets.symmetric(horizontal: Responsive.w(context, 12)),
        );
        break;
    }

    Widget buttonWidget;
    if (variant == AppButtonVariant.outlined) {
      buttonWidget = OutlinedButton(
        onPressed: isDisabled ? null : onPressed,
        style: buttonStyle,
        child: child,
      );
    } else if (variant == AppButtonVariant.text) {
      buttonWidget = TextButton(
        onPressed: isDisabled ? null : onPressed,
        style: buttonStyle,
        child: child,
      );
    } else {
      buttonWidget = ElevatedButton(
        onPressed: isDisabled ? null : onPressed,
        style: buttonStyle,
        child: child,
      );
    }

    if (fullWidth) {
      return SizedBox(
        width: double.infinity,
        height: responsiveHeight,
        child: buttonWidget,
      );
    }

    return SizedBox(height: responsiveHeight, child: buttonWidget);
  }

  Color _loadingColor(BuildContext context) {
    switch (variant) {
      case AppButtonVariant.outlined:
      case AppButtonVariant.text:
        return AppColors.primary;
      case AppButtonVariant.secondary:
        return AppColors.onSecondaryContainer;
      case AppButtonVariant.primary:
      case AppButtonVariant.danger:
        return Colors.white;
    }
  }
}
