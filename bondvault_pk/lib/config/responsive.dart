import 'package:flutter/widgets.dart';

class Responsive {
  static double width(BuildContext context) => MediaQuery.sizeOf(context).width;
  static double height(BuildContext context) =>
      MediaQuery.sizeOf(context).height;

  /// Scale size relative to reference width (375dp)
  static double w(BuildContext context, double size) =>
      size * width(context) / 375.0;

  /// Scale size relative to reference height (812dp)
  static double h(BuildContext context, double size) =>
      size * height(context) / 812.0;

  /// Scale font size relative to reference width (375dp)
  static double sp(BuildContext context, double size) =>
      size * width(context) / 375.0;
}

extension ResponsiveNum on num {
  double w(BuildContext context) => Responsive.w(context, toDouble());
  double h(BuildContext context) => Responsive.h(context, toDouble());
  double sp(BuildContext context) => Responsive.sp(context, toDouble());
}
