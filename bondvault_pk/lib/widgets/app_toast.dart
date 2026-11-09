import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_theme.dart';
import '../config/responsive.dart';
import 'app_notification_sheet.dart';

class AppToast {
  static OverlayEntry? _currentEntry;
  static Timer? _timer;

  static Future<int> getToastDuration() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('toast_duration_seconds') ?? 3;
  }

  static void show(
    BuildContext context,
    String message, {
    AppNotificationType type = AppNotificationType.info,
    int? durationSeconds,
  }) async {
    _timer?.cancel();
    _currentEntry?.remove();
    _currentEntry = null;

    final overlay = Overlay.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final actualDurationSeconds = durationSeconds ?? await getToastDuration();

    Color bg;
    Color border;
    Color textColor;
    IconData icon;

    switch (type) {
      case AppNotificationType.success:
        bg = isDark ? const Color(0xFF0F5132) : const Color(0xFF064E3B);
        border = const Color(0xFF80BEA6);
        textColor = Colors.white;
        icon = Icons.check_circle;
        break;
      case AppNotificationType.error:
        bg = isDark ? const Color(0xFF4A0E0E) : AppColors.error;
        border = Colors.red.shade300;
        textColor = Colors.white;
        icon = Icons.error;
        break;
      case AppNotificationType.warning:
        bg = isDark ? const Color(0xFF5C3C00) : Colors.amber.shade900;
        border = Colors.amber.shade300;
        textColor = Colors.white;
        icon = Icons.warning_rounded;
        break;
      case AppNotificationType.info:
        bg = isDark ? const Color(0xFF002117) : AppColors.primary;
        border = AppColors.onPrimaryContainer;
        textColor = Colors.white;
        icon = Icons.info_rounded;
        break;
    }

    final entry = OverlayEntry(
      builder: (overlayContext) => _ToastWidget(
        message: message,
        backgroundColor: bg,
        borderColor: border,
        textColor: textColor,
        icon: icon,
        durationSeconds: actualDurationSeconds,
        onDismissed: () {
          _timer?.cancel();
          _currentEntry?.remove();
          _currentEntry = null;
        },
      ),
    );

    _currentEntry = entry;
    overlay.insert(entry);

    _timer = Timer(Duration(seconds: actualDurationSeconds), () {
      _currentEntry?.remove();
      _currentEntry = null;
    });
  }
}

class _ToastWidget extends StatefulWidget {
  final String message;
  final Color backgroundColor;
  final Color borderColor;
  final Color textColor;
  final IconData icon;
  final int durationSeconds;
  final VoidCallback onDismissed;

  const _ToastWidget({
    required this.message,
    required this.backgroundColor,
    required this.borderColor,
    required this.textColor,
    required this.icon,
    required this.durationSeconds,
    required this.onDismissed,
  });

  @override
  State<_ToastWidget> createState() => _ToastWidgetState();
}

class _ToastWidgetState extends State<_ToastWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _slideAnimation = Tween<double>(
      begin: 40.0,
      end: 0.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _dismiss() async {
    await _controller.reverse();
    widget.onDismissed();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: Responsive.h(context, 40),
      left: Responsive.w(context, 20),
      right: Responsive.w(context, 20),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: Responsive.maxContentWidth(context),
          ),
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(0, _slideAnimation.value),
                child: Opacity(opacity: _fadeAnimation.value, child: child),
              );
            },
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: Responsive.w(context, 16),
                  vertical: Responsive.h(context, 12),
                ),
                decoration: BoxDecoration(
                  color: widget.backgroundColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: widget.borderColor, width: 1.2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(
                      widget.icon,
                      color: widget.textColor,
                      size: Responsive.w(context, 22),
                    ),
                    SizedBox(width: Responsive.w(context, 12)),
                    Expanded(
                      child: Text(
                        widget.message,
                        style: TextStyle(
                          fontSize: Responsive.sp(context, 13),
                          fontWeight: FontWeight.w600,
                          color: widget.textColor,
                        ),
                      ),
                    ),
                    SizedBox(width: Responsive.w(context, 8)),
                    GestureDetector(
                      onTap: _dismiss,
                      child: Icon(
                        Icons.close,
                        color: widget.textColor.withValues(alpha: 0.8),
                        size: Responsive.w(context, 18),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

void showAppToast(
  BuildContext context,
  String message, {
  AppNotificationType type = AppNotificationType.info,
  int? durationSeconds,
}) {
  AppToast.show(context, message, type: type, durationSeconds: durationSeconds);
}
