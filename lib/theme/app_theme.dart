import 'package:flutter/material.dart';

abstract final class AppColors {
  static const background = Color(0xFF0B0F13);
  static const surface = Color(0xFF151B22);
  static const raised = Color(0xFF1C242D);
  static const border = Color(0xFF2B3541);
  static const text = Color(0xFFF5F7FA);
  static const muted = Color(0xFFA1ADB9);
  static const subtle = Color(0xFF768594);
  static const accent = Color(0xFFD8FA7A);
  static const ink = Color(0xFF152018);
  static const positive = Color(0xFF66DFB0);
  static const negative = Color(0xFFFF8F9C);
  static const btc = Color(0xFFF8AA4B);
  static const eth = Color(0xFFB7ABFF);
  static const sol = Color(0xFF77DCE1);
}

abstract final class AppTheme {
  static final dark = _buildDark();

  static ThemeData _buildDark() {
    const radius = BorderRadius.all(Radius.circular(16));
    const scheme = ColorScheme.dark(
      primary: AppColors.accent,
      onPrimary: AppColors.ink,
      secondary: AppColors.positive,
      onSecondary: AppColors.ink,
      surface: AppColors.surface,
      onSurface: AppColors.text,
      error: AppColors.negative,
      onError: AppColors.ink,
      outline: AppColors.border,
      outlineVariant: AppColors.border,
      onSurfaceVariant: AppColors.muted,
    );
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: 'Manrope',
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.background,
      visualDensity: VisualDensity.standard,
    );
    final text = base.textTheme
        .copyWith(
          displayLarge: const TextStyle(
            fontSize: 34,
            height: 1.2,
            fontWeight: FontWeight.w800,
            letterSpacing: -1.1,
          ),
          displayMedium: const TextStyle(
            fontSize: 34,
            height: 1.2,
            fontWeight: FontWeight.w800,
            letterSpacing: -1.1,
          ),
          displaySmall: const TextStyle(
            fontSize: 32,
            height: 1.2,
            fontWeight: FontWeight.w700,
            letterSpacing: -1,
          ),
          headlineLarge: const TextStyle(
            fontSize: 28,
            height: 1.25,
            fontWeight: FontWeight.w700,
            letterSpacing: -.7,
          ),
          headlineMedium: const TextStyle(
            fontSize: 24,
            height: 1.3,
            fontWeight: FontWeight.w700,
            letterSpacing: -.5,
          ),
          headlineSmall: const TextStyle(
            fontSize: 20,
            height: 1.3,
            fontWeight: FontWeight.w700,
            letterSpacing: -.3,
          ),
          titleLarge: const TextStyle(
            fontSize: 28,
            height: 1.25,
            fontWeight: FontWeight.w700,
            letterSpacing: -.7,
          ),
          titleMedium: const TextStyle(
            fontSize: 17,
            height: 1.4,
            fontWeight: FontWeight.w700,
          ),
          titleSmall: const TextStyle(
            fontSize: 14,
            height: 1.4,
            fontWeight: FontWeight.w700,
          ),
          bodyLarge: const TextStyle(fontSize: 16, height: 1.5),
          bodyMedium: const TextStyle(
            fontSize: 14,
            height: 1.5,
            fontWeight: FontWeight.w500,
          ),
          bodySmall: const TextStyle(
            fontSize: 12,
            height: 1.45,
            color: AppColors.muted,
          ),
          labelLarge: const TextStyle(
            fontSize: 14,
            height: 1.4,
            fontWeight: FontWeight.w700,
          ),
          labelMedium: const TextStyle(
            fontSize: 12,
            height: 1.4,
            fontWeight: FontWeight.w600,
          ),
          labelSmall: const TextStyle(
            fontSize: 12,
            height: 1.4,
            color: AppColors.muted,
          ),
        )
        .apply(
          fontFamily: 'Manrope',
          bodyColor: AppColors.text,
          displayColor: AppColors.text,
        );

    return base.copyWith(
      textTheme: text,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.text,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: const CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: AppColors.border),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 50),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: const RoundedRectangleBorder(borderRadius: radius),
          textStyle: text.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.text,
          minimumSize: const Size(0, 50),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          side: const BorderSide(color: AppColors.border),
          shape: const RoundedRectangleBorder(borderRadius: radius),
          textStyle: text.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 48),
          textStyle: text.labelMedium,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(48, 48),
          foregroundColor: AppColors.muted,
        ),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        hintStyle: TextStyle(fontSize: 14, color: AppColors.muted),
        labelStyle: TextStyle(fontSize: 14, color: AppColors.muted),
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: AppColors.accent),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: AppColors.negative),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: AppColors.negative),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.surface,
        selectedItemColor: AppColors.accent,
        unselectedItemColor: AppColors.muted,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        height: 66,
        indicatorColor: AppColors.accent,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontFamily: 'Manrope',
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
            color: states.contains(WidgetState.selected)
                ? AppColors.accent
                : AppColors.muted,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? AppColors.ink
                : AppColors.muted,
            size: 23,
          ),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 1,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surface,
        selectedColor: AppColors.accent,
        side: const BorderSide(color: AppColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        labelStyle: text.labelMedium,
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: AppColors.raised,
        contentTextStyle: TextStyle(
          color: AppColors.text,
          fontFamily: 'Manrope',
          fontSize: 14,
        ),
        behavior: SnackBarBehavior.floating,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.accent,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: AppColors.raised,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        textStyle: const TextStyle(
          color: AppColors.text,
          fontFamily: 'Manrope',
          fontSize: 12,
        ),
      ),
    );
  }
}
