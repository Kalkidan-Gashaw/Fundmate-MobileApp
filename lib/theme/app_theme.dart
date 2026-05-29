import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';

abstract final class AppTheme {
  static const duration = Duration(milliseconds: 350);
  static const curve = Curves.easeInOutCubic;

  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final fm = isDark ? FundMateColors.dark : FundMateColors.light;

    final scheme = ColorScheme(
      brightness: brightness,
      primary: isDark ? AppColors.accentSoft : AppColors.primary,
      onPrimary: isDark ? const Color(0xFF0A0E18) : Colors.white,
      primaryContainer: isDark ? const Color(0xFF1E3A5F) : const Color(0xFFDDE4FF),
      onPrimaryContainer:
          isDark ? AppColors.accentSoft : AppColors.primary,
      secondary: AppColors.accent,
      onSecondary: isDark ? const Color(0xFF0A0E18) : const Color(0xFF0F172A),
      secondaryContainer:
          isDark ? const Color(0xFF1A3D3C) : const Color(0xFFD0FAF9),
      onSecondaryContainer:
          isDark ? AppColors.accentSoft : const Color(0xFF0F4F4E),
      tertiary: isDark ? const Color(0xFF7C9CFF) : AppColors.primaryLight,
      onTertiary: Colors.white,
      error: isDark ? const Color(0xFFFF6B6B) : Colors.red.shade700,
      onError: Colors.white,
      surface: isDark ? AppColors.darkScaffold : AppColors.lightScaffold,
      onSurface: isDark ? AppColors.darkText : AppColors.lightText,
      onSurfaceVariant:
          isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
      outline: isDark ? const Color(0xFF3A4A66) : const Color(0xFFCBD5E1),
      outlineVariant:
          isDark ? const Color(0xFF243044) : const Color(0xFFE2E8F0),
      shadow: fm.shadow,
      surfaceContainerHighest: fm.surfaceElevated,
    );

    final textTheme = TextTheme(
      displaySmall: TextStyle(
        color: scheme.onSurface,
        fontWeight: FontWeight.bold,
        letterSpacing: -0.5,
      ),
      headlineSmall: TextStyle(
        color: scheme.onSurface,
        fontWeight: FontWeight.bold,
      ),
      titleLarge: TextStyle(
        color: scheme.onSurface,
        fontWeight: FontWeight.bold,
      ),
      titleMedium: TextStyle(
        color: scheme.onSurface,
        fontWeight: FontWeight.w600,
      ),
      titleSmall: TextStyle(color: scheme.onSurface),
      bodyLarge: TextStyle(
        color: scheme.onSurface,
        height: 1.45,
      ),
      bodyMedium: TextStyle(
        color: scheme.onSurface,
        height: 1.4,
      ),
      bodySmall: TextStyle(color: scheme.onSurfaceVariant),
      labelLarge: TextStyle(
        color: scheme.onSurface,
        fontWeight: FontWeight.w600,
      ),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      textTheme: textTheme,
      iconTheme: IconThemeData(color: scheme.onSurface),
      primaryIconTheme: IconThemeData(color: scheme.primary),
      dividerColor: scheme.outlineVariant,
      splashColor: AppColors.accent.withValues(alpha: 0.12),
      highlightColor: AppColors.accent.withValues(alpha: 0.08),
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
      cardTheme: CardThemeData(
        color: fm.card,
        elevation: isDark ? 0 : 1,
        shadowColor: fm.shadow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: fm.cardBorder),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: isDark ? const Color(0xFF0F1524) : Colors.white,
        selectedItemColor: scheme.primary,
        unselectedItemColor: scheme.onSurfaceVariant,
        type: BottomNavigationBarType.fixed,
        elevation: isDark ? 0 : 8,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: scheme.primary,
        unselectedLabelColor: scheme.onSurfaceVariant,
        indicatorColor: AppColors.accent,
        dividerColor: scheme.outlineVariant,
        labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: fm.inputFill,
        labelStyle: TextStyle(color: scheme.onSurfaceVariant),
        floatingLabelStyle: TextStyle(color: scheme.primary),
        hintStyle: TextStyle(color: scheme.onSurfaceVariant),
        prefixIconColor: scheme.primary,
        suffixIconColor: scheme.onSurfaceVariant,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: fm.cardBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: fm.cardBorder),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: fm.card,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: textTheme.titleLarge,
        contentTextStyle: textTheme.bodyMedium,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark ? fm.surfaceElevated : const Color(0xFF1E293B),
        contentTextStyle: TextStyle(color: scheme.onSurface),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: AppColors.accent,
        linearTrackColor: isDark ? fm.cardBorder : null,
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant),
      chipTheme: ChipThemeData(
        backgroundColor: fm.chipUnselected,
        selectedColor: fm.chipSelected,
        labelStyle: TextStyle(color: scheme.onSurface, fontSize: 12),
        side: BorderSide(color: fm.chipBorder),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: isDark ? AppColors.accent : AppColors.primary,
          foregroundColor: isDark ? const Color(0xFF0A0E18) : Colors.white,
          disabledBackgroundColor:
              isDark ? fm.cardBorder : Colors.grey.shade300,
          disabledForegroundColor: scheme.onSurfaceVariant,
          elevation: isDark ? 0 : 2,
          shadowColor: fm.shadow,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: fm.link,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.primary,
          side: BorderSide(color: scheme.primary),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.accent,
        foregroundColor: isDark ? const Color(0xFF0A0E18) : Colors.white,
      ),
      listTileTheme: ListTileThemeData(
        textColor: scheme.onSurface,
        iconColor: scheme.primary,
      ),
      extensions: [fm],
    );
  }
}
