import 'package:flutter/material.dart';

abstract final class AppTheme {
  static const primary = Color(0xFF1B4D3E);
  static const primaryLight = Color(0xFF2A6B55);
  static const accent = Color(0xFFC9A227);
  static const surfaceLight = Color(0xFFF7F6F3);
  static const surfaceDark = Color(0xFF121212);
  static const cardDark = Color(0xFF1E1E1E);
  static const inputDark = Color(0xFF2C2C2C);

  static ThemeData get light => _build(Brightness.light);

  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isLight = brightness == Brightness.light;
    final onSurface = isLight ? const Color(0xFF1A1A1A) : const Color(0xFFF2F2F2);
    final onSurfaceVariant =
        isLight ? const Color(0xFF4A4A4A) : const Color(0xFFB8B8B8);

    final scheme = ColorScheme(
      brightness: brightness,
      primary: isLight ? primary : const Color(0xFF3D9B7A),
      onPrimary: Colors.white,
      primaryContainer: isLight ? const Color(0xFFD4E8DE) : const Color(0xFF1F4D3E),
      onPrimaryContainer: isLight ? primary : const Color(0xFFB8E6D4),
      secondary: accent,
      onSecondary: const Color(0xFF1A1508),
      secondaryContainer:
          isLight ? const Color(0xFFF5E6B8) : const Color(0xFF4A3D10),
      onSecondaryContainer: isLight ? const Color(0xFF3D3010) : const Color(0xFFF5E6B8),
      surface: isLight ? surfaceLight : surfaceDark,
      onSurface: onSurface,
      surfaceContainerHighest:
          isLight ? const Color(0xFFE6E6E6) : const Color(0xFF2E2E2E),
      onSurfaceVariant: onSurfaceVariant,
      outline: isLight ? const Color(0xFF8A9A94) : const Color(0xFF6A7A74),
      error: const Color(0xFFB3261E),
      onError: Colors.white,
      tertiary: const Color(0xFF2E6B5A),
      onTertiary: Colors.white,
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      brightness: brightness,
    );

    return base.copyWith(
      textTheme: _textTheme(base.textTheme, onSurface, onSurfaceVariant),
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: scheme.surface,
        foregroundColor: onSurface,
        titleTextStyle: TextStyle(
          fontFamily: 'Segoe UI',
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: onSurface,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          disabledBackgroundColor:
              isLight ? const Color(0xFFB8C9C3) : const Color(0xFF3A4A44),
          disabledForegroundColor: Colors.white54,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          minimumSize: const Size(64, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(
            fontFamily: 'Segoe UI',
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.primary,
          side: BorderSide(color: scheme.primary, width: 2),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          minimumSize: const Size(64, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(
            fontFamily: 'Segoe UI',
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 4,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isLight ? Colors.white : inputDark,
        labelStyle: TextStyle(color: onSurfaceVariant),
        hintStyle: TextStyle(color: onSurfaceVariant.withValues(alpha: 0.8)),
        floatingLabelStyle: TextStyle(color: scheme.primary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isLight ? Colors.grey.shade300 : const Color(0xFF4A4A4A),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isLight ? Colors.grey.shade300 : const Color(0xFF4A4A4A),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: isLight ? Colors.white : cardDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isLight ? Colors.grey.shade200 : const Color(0xFF333333),
          ),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: isLight ? Colors.grey.shade200 : const Color(0xFF333333),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: isLight ? Colors.white : cardDark,
        modalBackgroundColor: isLight ? Colors.white : cardDark,
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        textStyle: TextStyle(color: onSurface),
      ),
      listTileTheme: ListTileThemeData(
        textColor: onSurface,
        iconColor: onSurfaceVariant,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: isLight ? primary : primaryLight,
        contentTextStyle: const TextStyle(color: Colors.white),
      ),
    );
  }

  static TextTheme _textTheme(
    TextTheme base,
    Color onSurface,
    Color onSurfaceVariant,
  ) {
    return base.copyWith(
      displayLarge: base.displayLarge?.copyWith(color: onSurface),
      displayMedium: base.displayMedium?.copyWith(color: onSurface),
      displaySmall: base.displaySmall?.copyWith(color: onSurface),
      headlineLarge: base.headlineLarge?.copyWith(color: onSurface),
      headlineMedium: base.headlineMedium?.copyWith(color: onSurface),
      headlineSmall: base.headlineSmall?.copyWith(color: onSurface),
      titleLarge: base.titleLarge?.copyWith(
        color: onSurface,
        fontWeight: FontWeight.w600,
      ),
      titleMedium: base.titleMedium?.copyWith(
        color: onSurface,
        fontWeight: FontWeight.w600,
      ),
      titleSmall: base.titleSmall?.copyWith(color: onSurface),
      bodyLarge: base.bodyLarge?.copyWith(color: onSurface),
      bodyMedium: base.bodyMedium?.copyWith(color: onSurface),
      bodySmall: base.bodySmall?.copyWith(color: onSurfaceVariant),
      labelLarge: base.labelLarge?.copyWith(color: onSurface),
      labelMedium: base.labelMedium?.copyWith(color: onSurfaceVariant),
      labelSmall: base.labelSmall?.copyWith(color: onSurfaceVariant),
    ).apply(fontFamily: 'Segoe UI');
  }
}
