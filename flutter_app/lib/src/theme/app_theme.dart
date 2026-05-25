import 'package:flutter/material.dart';

import 'app_colors.dart';

class AppTheme {
  const AppTheme._();

  static ThemeData dark({Color? accent}) {
    final Color activeAccent = accent ?? AppColors.accent;
    final ColorScheme colorScheme = ColorScheme.dark(
      primary: activeAccent,
      secondary: activeAccent,
      surface: AppColors.surface,
      onPrimary: AppColors.background,
      onSecondary: AppColors.text,
      onSurface: AppColors.text,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: colorScheme,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: activeAccent,
        elevation: 0,
        centerTitle: false,
      ),
      iconTheme: IconThemeData(color: activeAccent),
      listTileTheme: ListTileThemeData(
        iconColor: activeAccent,
        selectedColor: activeAccent,
      ),
      textTheme: const TextTheme(
        headlineMedium: TextStyle(
          color: AppColors.text,
          fontWeight: FontWeight.w700,
        ),
        headlineSmall: TextStyle(
          color: AppColors.text,
          fontWeight: FontWeight.w700,
        ),
        bodyLarge: TextStyle(
          color: AppColors.text,
        ),
        bodyMedium: TextStyle(
          color: AppColors.textMuted,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surface,
        indicatorColor: activeAccent,
        labelTextStyle: const WidgetStatePropertyAll<TextStyle>(
          TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: activeAccent,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((Set<WidgetState> states) {
          if (states.contains(WidgetState.selected)) {
            return activeAccent;
          }
          return null;
        }),
        trackColor: WidgetStateProperty.resolveWith((Set<WidgetState> states) {
          if (states.contains(WidgetState.selected)) {
            return activeAccent.withOpacity(0.34);
          }
          return null;
        }),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: activeAccent),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: activeAccent,
          foregroundColor: AppColors.background,
        ),
      ),
    );
  }
}
