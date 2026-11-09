import 'package:flutter/material.dart';

import '../config/app_theme.dart';
import '../config/responsive.dart';

class AppLoadingIndicator extends StatelessWidget {
  final String? message;
  final Color? color;

  const AppLoadingIndicator({super.key, this.message, this.color});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final spinnerColor =
        color ??
        (isDark ? const Color(0xFF80BEA6) : AppColors.primaryContainer);

    return Center(
      child: Padding(
        padding: EdgeInsets.all(Responsive.w(context, 24)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(spinnerColor),
              strokeWidth: 3,
            ),
            if (message != null) ...[
              SizedBox(height: Responsive.h(context, 16)),
              Text(
                message!,
                style: TextStyle(
                  fontSize: Responsive.sp(context, 13),
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white70 : AppColors.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
