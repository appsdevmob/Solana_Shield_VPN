import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hiddify/core/theme/app_theme_mode.dart';
import 'package:hiddify/core/theme/theme_extensions.dart';

/// Solana-стилизованная тема VPN Solana
class AppTheme {
  AppTheme(this.mode, this.fontFamily);
  final AppThemeMode mode;
  final String fontFamily;

  // ── Solana Color Palette ──────────────────────────────────
  static const _solanaPrimary = Color(0xFF9945FF);
  static const _solanaSecondary = Color(0xFF14F195);
  static const _solanaAccent = Color(0xFF00D1FF);
  static const _backgroundDark = Color(0xFF0A0A0F); // Deep dark
  static const _surfaceDark = Color(0xFF14141A); // Card background
  static const _surfaceContainerDark = Color(0xFF1C1C24); // Surface component
  static const _errorColor = Color(0xFFFF4757);

  /// Тёмная ColorScheme на основе Solana-палитры
  static const _darkScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: _solanaPrimary,
    onPrimary: Colors.white,
    primaryContainer: Color(0xFF2D1A5E),
    onPrimaryContainer: Color(0xFFE8DDFF),
    secondary: _solanaSecondary,
    onSecondary: Color(0xFF003822),
    secondaryContainer: Color(0xFF0A3A24),
    onSecondaryContainer: Color(0xFFA8FFD8),
    tertiary: _solanaAccent,
    onTertiary: Color(0xFF003544),
    tertiaryContainer: Color(0xFF004D63),
    onTertiaryContainer: Color(0xFFB3EEFF),
    error: _errorColor,
    onError: Colors.white,
    errorContainer: Color(0xFF5C1010),
    onErrorContainer: Color(0xFFFFDAD6),
    surface: _surfaceDark,
    onSurface: Color(0xFFE6E1E5),
    surfaceContainerHighest: _surfaceContainerDark,
    onSurfaceVariant: Color(0xFFC9C5D0),
    outline: Color(0xFF2A2B3D),
    outlineVariant: Color(0xFF1E1F30),
    scrim: Colors.black,
    inverseSurface: Color(0xFFE6E1E5),
    onInverseSurface: Color(0xFF1C1B1F),
    inversePrimary: Color(0xFF7B2FCC),
    surfaceTint: _solanaPrimary,
  );

  /// Светлая ColorScheme — адаптированная Solana
  static ColorScheme get _lightScheme => ColorScheme.fromSeed(
    seedColor: _solanaPrimary,
    brightness: Brightness.light,
    primary: _solanaPrimary,
    secondary: const Color(0xFF0AAF6A),
  );

  ThemeData lightTheme(ColorScheme? lightColorScheme) {
    final ColorScheme scheme = lightColorScheme ?? _lightScheme;
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: fontFamily,
      extensions: const <ThemeExtension<dynamic>>{ConnectionButtonTheme.solana},
    );
  }

  ThemeData darkTheme(ColorScheme? darkColorScheme) {
    // Всегда используем Solana dark scheme, игнорируем system dynamic color
    const ColorScheme scheme = _darkScheme;
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: mode.trueBlack ? Colors.black : _backgroundDark,
      fontFamily: fontFamily,
      // Дополнительная стилизация для Solana-вида
      appBarTheme: const AppBarTheme(
        backgroundColor: _backgroundDark,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      cardTheme: CardThemeData(
        color: _surfaceDark,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF2A2B3D), width: 1),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: _surfaceDark,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: Color(0xFF2A2B3D), width: 1),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: _surfaceDark,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: _surfaceDark,
        indicatorColor: _solanaPrimary.withValues(alpha: 0.2),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: _solanaPrimary);
          }
          return const IconThemeData(color: Color(0xFF8B8D9E));
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(color: _solanaPrimary, fontSize: 12, fontWeight: FontWeight.w600);
          }
          return const TextStyle(color: Color(0xFF8B8D9E), fontSize: 12);
        }),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: _surfaceDark,
        indicatorColor: _solanaPrimary.withValues(alpha: 0.2),
        selectedIconTheme: const IconThemeData(color: _solanaPrimary),
        unselectedIconTheme: const IconThemeData(color: Color(0xFF8B8D9E)),
        selectedLabelTextStyle: const TextStyle(color: _solanaPrimary, fontWeight: FontWeight.w600),
        unselectedLabelTextStyle: const TextStyle(color: Color(0xFF8B8D9E)),
      ),
      dividerTheme: const DividerThemeData(color: Color(0xFF2A2B3D)),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _surfaceContainerDark,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF2A2B3D)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF2A2B3D)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _solanaPrimary),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: _solanaPrimary,
        foregroundColor: Colors.white,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return _solanaSecondary;
          return const Color(0xFF8B8D9E);
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return _solanaSecondary.withValues(alpha: 0.3);
          return const Color(0xFF2A2B3D);
        }),
      ),
      extensions: const <ThemeExtension<dynamic>>{ConnectionButtonTheme.solana},
    );
  }

  CupertinoThemeData cupertinoThemeData(bool sysDark, ColorScheme? lightColorScheme, ColorScheme? darkColorScheme) {
    final bool isDark = switch (mode) {
      AppThemeMode.system => sysDark,
      AppThemeMode.light => false,
      AppThemeMode.dark => true,
      AppThemeMode.black => true,
    };
    final def = CupertinoThemeData(brightness: isDark ? Brightness.dark : Brightness.light);
    final defaultMaterialTheme = isDark ? darkTheme(darkColorScheme) : lightTheme(lightColorScheme);
    return MaterialBasedCupertinoThemeData(
      materialTheme: defaultMaterialTheme.copyWith(
        cupertinoOverrideTheme: def.copyWith(
          textTheme: CupertinoTextThemeData(
            textStyle: def.textTheme.textStyle.copyWith(fontFamily: fontFamily),
            actionTextStyle: def.textTheme.actionTextStyle.copyWith(fontFamily: fontFamily),
            navActionTextStyle: def.textTheme.navActionTextStyle.copyWith(fontFamily: fontFamily),
            navTitleTextStyle: def.textTheme.navTitleTextStyle.copyWith(fontFamily: fontFamily),
            navLargeTitleTextStyle: def.textTheme.navLargeTitleTextStyle.copyWith(fontFamily: fontFamily),
            pickerTextStyle: def.textTheme.pickerTextStyle.copyWith(fontFamily: fontFamily),
            dateTimePickerTextStyle: def.textTheme.dateTimePickerTextStyle.copyWith(fontFamily: fontFamily),
            tabLabelTextStyle: def.textTheme.tabLabelTextStyle.copyWith(fontFamily: fontFamily),
          ).copyWith(),
          barBackgroundColor: def.barBackgroundColor,
          scaffoldBackgroundColor: def.scaffoldBackgroundColor,
        ),
      ),
    );
  }
}
