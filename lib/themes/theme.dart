// app_themes.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppThemes {
  // Color Schemes
  static const ColorScheme lightColorScheme = ColorScheme(
    brightness: Brightness.light,
    primary: Color(0xFF2196F3),
    onPrimary: Color(0xFFFFFFFF),
    secondary: Colors.black,
    onSecondary: Colors.blue,
    tertiary: Color(0xFF9C27B0),
    onTertiary: Color(0xFFFFFFFF),
    error: Color(0xFFF44336),
    onError: Color(0xFFFFFFFF),
    surface: Color(0xFFF5F5F5),
    onSurface: Color(0xFF1A1A1A),
    background: Color(0xFFFFFFFF),
    onBackground: Color(0xFF1A1A1A),
    outline: Color(0xFFE0E0E0),
    shadow: Colors.black,
    inverseSurface: Color(0xFF2E2E2E),
    onInverseSurface: Color(0xFFFFFFFF),
    inversePrimary: Color(0xFF64B5F6),
  );

  static const ColorScheme darkColorScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: Color(0xFF64B5F6),
    onPrimary: Color(0xFF000000),
    secondary: Color(0xFFFFD54F),
    onSecondary: Color(0xFF000000),
    tertiary: Color(0xFFBA68C8),
    onTertiary: Color(0xFF000000),
    error: Color(0xFFE57373),
    onError: Color(0xFF000000),
    surface: Color(0xFF1E1E1E),
    onSurface: Color(0xFFFFFFFF),
    background: Color(0xFF121212),
    onBackground: Color(0xFFFFFFFF),
    outline: Color(0xFF424242),
    shadow: Color(0xFF000000),
    inverseSurface: Color(0xFFE0E0E0),
    onInverseSurface: Color(0xFF000000),
    inversePrimary: Color(0xFF2196F3),
  );

  // Custom Colors for Financial Data

  static const Color successColor = Color(0xFF4CAF50);
  static const Color primaryColor = Color(0xFF2196F3);
  static const Color successColorDark = Color(0xFF81C784);
  static const Color warningColor = Color(0xFFFF9800);
  static const Color warningColorDark = Color(0xFFFFB74D);
  static const Color debtColor = Color(0xFFF44336);
  static const Color debtColorDark = Color(0xFFE57373);
  static const Color paymentColor = Color(0xFF4CAF50);
  static const Color paymentColorDark = Color(0xFF81C784);

  // Spacing Constants
  static const double spacing4 = 4.0;
  static const double spacing8 = 8.0;
  static const double spacing12 = 12.0;
  static const double spacing16 = 16.0;
  static const double spacing24 = 24.0;
  static const double spacing32 = 32.0;
  static const double spacing48 = 48.0;

  // Border Radius Constants
  static const double radiusSmall = 8.0;
  static const double radiusMedium = 16.0;
  static const double radiusLarge = 24.0;
  static const double radiusXLarge = 32.0;

  // Elevation Constants
  static const double elevation0 = 0.0;
  static const double elevation1 = 2.0;
  static const double elevation2 = 4.0;
  static const double elevation3 = 8.0;
  static const double elevation4 = 16.0;

  // Typography Theme
  static TextTheme get textTheme => GoogleFonts.robotoTextTheme(
    const TextTheme(
      headlineLarge: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.5,
        height: 1.2,
      ),
      headlineMedium: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.25,
        height: 1.25,
      ),
      titleLarge: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w500,
        letterSpacing: 0,
        height: 1.27,
      ),
      titleMedium: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.15,
        height: 1.33,
      ),
      bodyLarge: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.5,
        height: 1.5,
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.25,
        height: 1.43,
      ),
      labelLarge: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.1,
        height: 1.43,
      ),
      bodySmall: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.4,
        height: 1.33,
      ),
    ),
  );

  // Light Theme
  static ThemeData get lightTheme => ThemeData(
    useMaterial3: true,
    colorScheme: lightColorScheme,
    textTheme: textTheme,
    scaffoldBackgroundColor: lightColorScheme.background,

    appBarTheme: AppBarTheme(
      backgroundColor: lightColorScheme.background,
      foregroundColor: lightColorScheme.onBackground,
      elevation: elevation0,
      centerTitle: true,
      titleTextStyle: textTheme.titleLarge?.copyWith(
        color: lightColorScheme.onBackground,
        fontWeight: FontWeight.w600,
      ),
      iconTheme: IconThemeData(
        color: lightColorScheme.onBackground,
        size: 24,
      ),
    ),

    cardTheme: CardThemeData(
      color: lightColorScheme.surface,
      elevation: elevation2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusMedium),
      ),
      margin: EdgeInsets.all(spacing8),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: lightColorScheme.primary,
        foregroundColor: lightColorScheme.onPrimary,
        elevation: elevation2,
        padding: EdgeInsets.symmetric(
          horizontal: spacing24,
          vertical: spacing12,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSmall),
        ),
        textStyle: textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: lightColorScheme.primary,
        side: BorderSide(
          color: lightColorScheme.primary,
          width: 1.5,
        ),
        padding: EdgeInsets.symmetric(
          horizontal: spacing24,
          vertical: spacing12,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSmall),
        ),
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: lightColorScheme.primary,
        padding: EdgeInsets.symmetric(
          horizontal: spacing16,
          vertical: spacing8,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSmall),
        ),
      ),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: lightColorScheme.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusSmall),
        borderSide: BorderSide(
          color: lightColorScheme.outline,
          width: 1,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusSmall),
        borderSide: BorderSide(
          color: lightColorScheme.outline,
          width: 1,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusSmall),
        borderSide: BorderSide(
          color: lightColorScheme.primary,
          width: 2,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusSmall),
        borderSide: BorderSide(
          color: lightColorScheme.error,
          width: 1,
        ),
      ),
      contentPadding: EdgeInsets.symmetric(
        horizontal: spacing16,
        vertical: spacing12,
      ),
    ),

    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: lightColorScheme.primary,
      foregroundColor: lightColorScheme.onPrimary,
      elevation: elevation3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusMedium),
      ),
    ),

    // NavigationBar Theme (M3)
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: lightColorScheme.surface,
      indicatorColor: lightColorScheme.primary,
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return IconThemeData(color: lightColorScheme.onPrimary);
        }
        return IconThemeData(color: lightColorScheme.onSurface);
      }),
    ),

    // BottomNavigationBar Theme (M2 Legacy support)
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: lightColorScheme.surface,
      selectedItemColor: lightColorScheme.onSecondary,
      unselectedItemColor: lightColorScheme.onSurface,
      type: BottomNavigationBarType.fixed,
      elevation: elevation2,
    ),

    tabBarTheme: TabBarThemeData(
      labelColor: lightColorScheme.primary,
      unselectedLabelColor: lightColorScheme.onSurface.withOpacity(0.6),
      indicator: UnderlineTabIndicator(
        borderSide: BorderSide(
          color: lightColorScheme.primary,
          width: 2,
        ),
      ),
    ),

    dialogTheme: DialogThemeData(
      backgroundColor: lightColorScheme.surface,
      elevation: elevation4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusLarge),
      ),
    ),

    snackBarTheme: SnackBarThemeData(
      backgroundColor: lightColorScheme.inverseSurface,
      contentTextStyle: textTheme.bodyMedium?.copyWith(
        color: lightColorScheme.onInverseSurface,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusSmall),
      ),
      behavior: SnackBarBehavior.floating,
    ),
  );

  // Dark Theme
  static ThemeData get darkTheme => ThemeData(
    useMaterial3: true,
    colorScheme: darkColorScheme,
    textTheme: textTheme,
    scaffoldBackgroundColor: darkColorScheme.background,

    appBarTheme: AppBarTheme(
      backgroundColor: darkColorScheme.background,
      foregroundColor: darkColorScheme.onBackground,
      elevation: elevation0,
      centerTitle: true,
      titleTextStyle: textTheme.titleLarge?.copyWith(
        color: darkColorScheme.onBackground,
        fontWeight: FontWeight.w600,
      ),
      iconTheme: IconThemeData(
        color: darkColorScheme.onBackground,
        size: 24,
      ),
    ),

    cardTheme: CardThemeData(
      color: darkColorScheme.surface,
      elevation: elevation2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusMedium),
      ),
      margin: EdgeInsets.all(spacing8),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: darkColorScheme.primary,
        foregroundColor: darkColorScheme.onPrimary,
        elevation: elevation2,
        padding: EdgeInsets.symmetric(
          horizontal: spacing24,
          vertical: spacing12,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSmall),
        ),
        textStyle: textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: darkColorScheme.primary,
        side: BorderSide(
          color: darkColorScheme.primary,
          width: 1.5,
        ),
        padding: EdgeInsets.symmetric(
          horizontal: spacing24,
          vertical: spacing12,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSmall),
        ),
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: darkColorScheme.primary,
        padding: EdgeInsets.symmetric(
          horizontal: spacing16,
          vertical: spacing8,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSmall),
        ),
      ),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: darkColorScheme.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusSmall),
        borderSide: BorderSide(
          color: darkColorScheme.outline,
          width: 1,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusSmall),
        borderSide: BorderSide(
          color: darkColorScheme.outline,
          width: 1,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusSmall),
        borderSide: BorderSide(
          color: darkColorScheme.primary,
          width: 2,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusSmall),
        borderSide: BorderSide(
          color: darkColorScheme.error,
          width: 1,
        ),
      ),
      contentPadding: EdgeInsets.symmetric(
        horizontal: spacing16,
        vertical: spacing12,
      ),
    ),

    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: darkColorScheme.primary,
      foregroundColor: darkColorScheme.onPrimary,
      elevation: elevation3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusMedium),
      ),
    ),

    // NavigationBar Theme (M3)
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: darkColorScheme.surface,
      indicatorColor: darkColorScheme.primary,
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return IconThemeData(color: darkColorScheme.onPrimary);
        }
        return IconThemeData(color: darkColorScheme.onSurface);
      }),
    ),

    // BottomNavigationBar Theme (M2 Legacy support)
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: darkColorScheme.surface,
      selectedItemColor: Colors.yellow,
      unselectedItemColor: darkColorScheme.onSurface.withOpacity(0.6),
      type: BottomNavigationBarType.fixed,
      elevation: elevation2,
    ),

    tabBarTheme: TabBarThemeData(
      labelColor: darkColorScheme.primary,
      unselectedLabelColor: darkColorScheme.onSurface.withOpacity(0.6),
      indicator: UnderlineTabIndicator(
        borderSide: BorderSide(
          color: darkColorScheme.primary,
          width: 2,
        ),
      ),
    ),

    dialogTheme: DialogThemeData(
      backgroundColor: darkColorScheme.surface,
      elevation: elevation4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusLarge),
      ),
    ),

    snackBarTheme: SnackBarThemeData(
      backgroundColor: darkColorScheme.inverseSurface,
      contentTextStyle: textTheme.bodyMedium?.copyWith(
        color: darkColorScheme.onInverseSurface,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusSmall),
      ),
      behavior: SnackBarBehavior.floating,
    ),
  );

  // Utility Methods
  static Color getFinancialColor(BuildContext context, bool isDebt) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (isDebt) {
      return isDark ? debtColorDark : debtColor;
    } else {
      return isDark ? paymentColorDark : paymentColor;
    }
  }

  static Color getSuccessColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? successColorDark : successColor;
  }

  static Color getWarningColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? warningColorDark : warningColor;
  }

  // Theme Data Getters
  static ThemeData getTheme(bool isDark) {
    return isDark ? darkTheme : lightTheme;
  }
}
