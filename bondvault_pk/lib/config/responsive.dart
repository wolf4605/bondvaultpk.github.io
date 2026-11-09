import 'package:flutter/widgets.dart';

/// Relative units and responsive scaling utility for BondVault PK.
class Responsive {
  static double width(BuildContext context) => MediaQuery.sizeOf(context).width;
  static double height(BuildContext context) =>
      MediaQuery.sizeOf(context).height;

  static bool isMobile(BuildContext context) => width(context) < 600;
  static bool isTablet(BuildContext context) =>
      width(context) >= 600 && width(context) < 1024;
  static bool isDesktop(BuildContext context) => width(context) >= 1024;

  /// Scale size relative to reference screen width (375dp base) with clamping
  static double w(
    BuildContext context,
    double size, {
    double minScale = 0.85,
    double maxScale = 1.3,
  }) {
    final scale = (width(context) / 375.0).clamp(minScale, maxScale);
    return size * scale;
  }

  /// Scale size relative to reference screen height (812dp base) with clamping
  static double h(
    BuildContext context,
    double size, {
    double minScale = 0.85,
    double maxScale = 1.3,
  }) {
    final scale = (height(context) / 812.0).clamp(minScale, maxScale);
    return size * scale;
  }

  /// Relative font size (sp) clamped to prevent extreme text shrinking/stretching
  static double sp(
    BuildContext context,
    double size, {
    double minScale = 0.88,
    double maxScale = 1.25,
  }) {
    final scale = (width(context) / 375.0).clamp(minScale, maxScale);
    return size * scale;
  }

  /// Responsive grid columns based on device width
  static int gridColumns(
    BuildContext context, {
    int mobile = 2,
    int tablet = 3,
    int desktop = 4,
  }) {
    if (isDesktop(context)) return desktop;
    if (isTablet(context)) return tablet;
    return mobile;
  }

  /// Max content width for clean centered layouts on larger viewports
  static double maxContentWidth(BuildContext context) {
    if (isDesktop(context)) return 900;
    if (isTablet(context)) return 680;
    return double.infinity;
  }
}

extension ResponsiveNum on num {
  double w(BuildContext context) => Responsive.w(context, toDouble());
  double h(BuildContext context) => Responsive.h(context, toDouble());
  double sp(BuildContext context) => Responsive.sp(context, toDouble());
}
