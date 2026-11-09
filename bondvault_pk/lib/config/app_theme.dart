import 'package:flutter/material.dart';

/// Global theme mode controller for dynamic Material 3 light/dark switching.
final ValueNotifier<ThemeMode> themeModeNotifier = ValueNotifier(
  ThemeMode.light,
);

/// Centralized theme colors and styling configuration for BondVault PK.
/// Includes Emerald Vault palette for Light Mode and GitHub Dark Mode palette for Dark Mode.
class AppColors {
  // Emerald Vault Sovereign Palette (Light Mode)
  static const Color primary = Color(0xFF003527);
  static const Color primaryDark = Color(0xFF002117);
  static const Color primaryContainer = Color(0xFF064E3B);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color onPrimaryContainer = Color(0xFF80BEA6);

  static const Color secondary = Color(0xFF904D00);
  static const Color secondaryContainer = Color(0xFFFE932C);
  static const Color onSecondary = Color(0xFFFFFFFF);
  static const Color onSecondaryContainer = Color(0xFF663500);

  static const Color surface = Color(0xFFFAFAFF);
  static const Color surfaceContainerLow = Color(0xFFF2F3FF);
  static const Color surfaceCard = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFDAE2FD);

  static const Color onSurface = Color(0xFF131B2E);
  static const Color onSurfaceVariant = Color(0xFF404944);
  static const Color outline = Color(0xFF707974);

  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFD97706);
  static const Color error = Color(0xFFBA1A1A);

  // GitHub Dark Mode Palette
  static const Color darkCanvas = Color(0xFF0D1117);
  static const Color darkCard = Color(0xFF161B22);
  static const Color darkHeader = Color(0xFF21262D);
  static const Color darkBorder = Color(0xFF30363D);
  static const Color darkOnSurface = Color(0xFFC9D1D9);
  static const Color darkOnSurfaceBright = Color(0xFFF0F6FC);
  static const Color darkOnSurfaceVariant = Color(0xFF8B949E);
  static const Color darkGreen = Color(0xFF2EA043);
  static const Color darkGreenAccent = Color(0xFF3FB950);
  static const Color darkGold = Color(0xFFD29922);
  static const Color darkOrange = Color(0xFFF0883E);
  static const Color darkBlue = Color(0xFF58A6FF);
  static const Color darkRed = Color(0xFFF85149);

  /// Helper to get appropriate card background based on current brightness
  static Color getCardColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? darkCard : surfaceCard;
  }

  /// Helper to get appropriate border color based on current brightness
  static Color getBorderColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? darkBorder : Colors.grey.shade200;
  }

  /// Helper to get primary text color based on current brightness
  static Color getTextPrimary(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? darkOnSurfaceBright : onSurface;
  }

  /// Helper to get secondary/muted text color based on current brightness
  static Color getTextSecondary(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? darkOnSurfaceVariant : onSurfaceVariant;
  }
}

class AppTheme {
  static const Color _seedColor = Color(0xFF064E3B);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: _seedColor,
        brightness: Brightness.light,
        primary: AppColors.primary,
        primaryContainer: AppColors.primaryContainer,
        secondary: AppColors.secondary,
        secondaryContainer: AppColors.secondaryContainer,
        surface: AppColors.surface,
        onSurface: AppColors.onSurface,
        onSurfaceVariant: AppColors.onSurfaceVariant,
        outline: AppColors.outline,
        error: AppColors.error,
      ),
      scaffoldBackgroundColor: AppColors.surface,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.onSurface,
        elevation: 0,
        centerTitle: true,
        scrolledUnderElevation: 2,
        titleTextStyle: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 18,
          color: AppColors.onSurface,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.grey.shade200, width: 1.5),
        ),
        color: AppColors.surfaceCard,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surfaceCard,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surfaceCard,
        surfaceTintColor: Colors.transparent,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceContainerLow,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: AppColors.primaryContainer,
            width: 2,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
      ),
      tabBarTheme: const TabBarThemeData(
        indicatorColor: AppColors.primary,
        labelColor: AppColors.primary,
        unselectedLabelColor: AppColors.onSurfaceVariant,
        labelStyle: TextStyle(fontWeight: FontWeight.bold),
      ),
      dividerTheme: DividerThemeData(
        color: Colors.grey.shade200,
        space: 1,
        thickness: 1,
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.darkGreen,
        brightness: Brightness.dark,
        primary: AppColors.darkGreenAccent,
        primaryContainer: AppColors.darkHeader,
        secondary: AppColors.darkOrange,
        secondaryContainer: AppColors.darkGold,
        surface: AppColors.darkCanvas,
        onSurface: AppColors.darkOnSurfaceBright,
        onSurfaceVariant: AppColors.darkOnSurfaceVariant,
        outline: AppColors.darkBorder,
        error: AppColors.darkRed,
      ),
      scaffoldBackgroundColor: AppColors.darkCanvas,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.darkCanvas,
        foregroundColor: AppColors.darkOnSurfaceBright,
        elevation: 0,
        centerTitle: true,
        scrolledUnderElevation: 2,
        titleTextStyle: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 18,
          color: AppColors.darkOnSurfaceBright,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.darkBorder, width: 1.5),
        ),
        color: AppColors.darkCard,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.darkCard,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.darkCard,
        surfaceTintColor: Colors.transparent,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.darkHeader,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.darkBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.darkBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: AppColors.darkGreenAccent,
            width: 2,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.darkGreen,
          foregroundColor: AppColors.darkOnSurfaceBright,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
      ),
      tabBarTheme: const TabBarThemeData(
        indicatorColor: AppColors.darkGreenAccent,
        labelColor: AppColors.darkGreenAccent,
        unselectedLabelColor: AppColors.darkOnSurfaceVariant,
        labelStyle: TextStyle(fontWeight: FontWeight.bold),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.darkBorder,
        space: 1,
        thickness: 1,
      ),
    );
  }
}
