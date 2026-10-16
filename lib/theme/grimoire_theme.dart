import 'package:flutter/material.dart';

abstract final class GrimoireColors {
  static const background = Color(0xFF100C16);
  static const surface = Color(0xFF21192F);
  static const deepViolet = Color(0xFF4A3B5E);
  static const antiqueGold = Color(0xFFD4AF67);
  static const ivory = Color(0xFFF0E6D2);
  static const secondaryText = Color(0xFFB8AAB9);
  static const crimson = Color(0xFF7A2638);
  static const disabled = Color(0xFF766C79);
}

abstract final class GrimoireTheme {
  static const headingFont = 'Cinzel';
  static const bodyFont = 'SourceSans3';

  static ThemeData build() {
    const colorScheme = ColorScheme.dark(
      primary: GrimoireColors.antiqueGold,
      onPrimary: GrimoireColors.background,
      secondary: GrimoireColors.deepViolet,
      onSecondary: GrimoireColors.ivory,
      surface: GrimoireColors.surface,
      onSurface: GrimoireColors.ivory,
      error: GrimoireColors.crimson,
      onError: GrimoireColors.ivory,
    );
    final base = ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      fontFamily: bodyFont,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: GrimoireColors.background,
      canvasColor: GrimoireColors.background,
    );
    final textTheme = base.textTheme
        .apply(
          bodyColor: GrimoireColors.ivory,
          displayColor: GrimoireColors.ivory,
        )
        .copyWith(
          displayLarge: _heading(base.textTheme.displayLarge),
          displayMedium: _heading(base.textTheme.displayMedium),
          displaySmall: _heading(base.textTheme.displaySmall),
          headlineLarge: _heading(base.textTheme.headlineLarge),
          headlineMedium: _heading(base.textTheme.headlineMedium),
          headlineSmall: _heading(base.textTheme.headlineSmall),
          titleLarge: _heading(base.textTheme.titleLarge),
          titleMedium: _heading(base.textTheme.titleMedium),
          bodySmall: base.textTheme.bodySmall?.copyWith(
            color: GrimoireColors.secondaryText,
          ),
        );

    final fieldBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(
        color: GrimoireColors.antiqueGold.withValues(alpha: 0.38),
      ),
    );
    return base.copyWith(
      textTheme: textTheme,
      appBarTheme: const AppBarTheme(
        elevation: 0,
        backgroundColor: GrimoireColors.background,
        foregroundColor: GrimoireColors.ivory,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: GrimoireColors.surface.withValues(alpha: 0.94),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: GrimoireColors.antiqueGold.withValues(alpha: 0.32),
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        elevation: 18,
        backgroundColor: GrimoireColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
            color: GrimoireColors.antiqueGold.withValues(alpha: 0.48),
          ),
        ),
        titleTextStyle: textTheme.headlineSmall,
        contentTextStyle: textTheme.bodyMedium,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: GrimoireColors.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: GrimoireColors.antiqueGold,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: GrimoireColors.background.withValues(alpha: 0.72),
        border: fieldBorder,
        enabledBorder: fieldBorder,
        focusedBorder: fieldBorder.copyWith(
          borderSide: const BorderSide(
            color: GrimoireColors.antiqueGold,
            width: 1.5,
          ),
        ),
        labelStyle: const TextStyle(color: GrimoireColors.secondaryText),
        hintStyle: TextStyle(
          color: GrimoireColors.secondaryText.withValues(alpha: 0.72),
        ),
      ),
      dividerColor: GrimoireColors.antiqueGold.withValues(alpha: 0.22),
      iconTheme: const IconThemeData(color: GrimoireColors.ivory),
      listTileTheme: const ListTileThemeData(
        iconColor: GrimoireColors.ivory,
        textColor: GrimoireColors.ivory,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(48, 50),
          backgroundColor: GrimoireColors.antiqueGold,
          foregroundColor: GrimoireColors.background,
          elevation: 0,
          textStyle: const TextStyle(
            fontFamily: headingFont,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.4,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          foregroundColor: GrimoireColors.ivory,
          side: BorderSide(
            color: GrimoireColors.antiqueGold.withValues(alpha: 0.55),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: GrimoireColors.antiqueGold,
          minimumSize: const Size(48, 44),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: GrimoireColors.surface,
        contentTextStyle: TextStyle(color: GrimoireColors.ivory),
        behavior: SnackBarBehavior.floating,
      ),
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: GrimoireColors.antiqueGold,
        selectionHandleColor: GrimoireColors.antiqueGold,
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? GrimoireColors.antiqueGold
              : GrimoireColors.secondaryText,
        ),
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      sliderTheme: base.sliderTheme.copyWith(
        activeTrackColor: GrimoireColors.antiqueGold,
        inactiveTrackColor: GrimoireColors.deepViolet,
        thumbColor: GrimoireColors.antiqueGold,
        overlayColor: GrimoireColors.antiqueGold.withValues(alpha: 0.12),
      ),
    );
  }

  /// Keeps the established playground controls visually stable while the
  /// surrounding app adopts the Grimoire design system.
  static ThemeData playground() {
    const background = Color(0xFF040004);
    return ThemeData(
      brightness: Brightness.dark,
      primarySwatch: Colors.blue,
      scaffoldBackgroundColor: background,
      canvasColor: background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF6F678A),
        brightness: Brightness.dark,
      ).copyWith(
        surface: const Color(0xFF4A3B5E),
        onSurface: Colors.white,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF6F678A),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF4A3B5E), width: 2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF4A3B5E), width: 2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF4A3B5E), width: 2),
        ),
        labelStyle: const TextStyle(color: Colors.white),
        hintStyle: const TextStyle(color: Colors.white),
      ),
      textTheme: const TextTheme(bodyMedium: TextStyle(color: Colors.white)),
      textSelectionTheme: const TextSelectionThemeData(
        selectionHandleColor: Colors.white,
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.all(const Color(0xFF4A3B5E)),
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
    );
  }

  static TextStyle? _heading(TextStyle? style) => style?.copyWith(
        fontFamily: headingFont,
        color: GrimoireColors.ivory,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.35,
      );

  static BoxDecoration panelDecoration({bool emphasized = false}) {
    return BoxDecoration(
      color: GrimoireColors.surface.withValues(alpha: emphasized ? 0.96 : 0.88),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: GrimoireColors.antiqueGold.withValues(
          alpha: emphasized ? 0.62 : 0.30,
        ),
        width: emphasized ? 1.2 : 0.8,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.28),
          blurRadius: 16,
          offset: const Offset(0, 7),
        ),
      ],
    );
  }
}
