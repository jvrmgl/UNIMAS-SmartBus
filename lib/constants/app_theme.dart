import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppTheme {
  // ── Brand Colors ─────────────────────────────────────────────────────────
  static const Color primaryColor    = Color(0xFF1976D2); // Blue
  static const Color secondaryColor  = Color(0xFFFF6B35); // Orange
  static const Color accentColor     = Color(0xFF004E89); // Dark Blue
  static const Color successColor    = Color(0xFF4CAF50); // Green
  static const Color warningColor    = Color(0xFFFFC107); // Amber
  static const Color errorColor      = Color(0xFFF44336); // Red
  static const Color backgroundColor = Color(0xFFF5F7FA); // Soft off-white
  static const Color surfaceColor    = Color(0xFFFFFFFF); // White
  static const Color textPrimary     = Color(0xFF1A1A2E); // Near-black
  static const Color textSecondary   = Color(0xFF6B7280); // Cool grey
  static const Color textTertiary    = Color(0xFFB0B8C4); // Light slate
  static const Color dividerColor    = Color(0xFFE8ECF0); // Subtle divider

  // ── Semantic shadows (downward only — no top ghost-line) ─────────────────
  /// Use on elevated cards / FABs that need a floating feel.
  static List<BoxShadow> get cardShadow => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.06),
      blurRadius: 12,
      spreadRadius: 0,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> get subtleShadow => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.04),
      blurRadius: 8,
      spreadRadius: 0,
      offset: const Offset(0, 2),
    ),
  ];

  // ── Light Theme ───────────────────────────────────────────────────────────
  static ThemeData get lightTheme {
    const scheme = ColorScheme(
      brightness: Brightness.light,
      primary:          primaryColor,
      onPrimary:        Colors.white,
      primaryContainer: Color(0xFFD6E8FF),
      onPrimaryContainer: Color(0xFF001E3F),
      secondary:        secondaryColor,
      onSecondary:      Colors.white,
      secondaryContainer: Color(0xFFFFDCD0),
      onSecondaryContainer: Color(0xFF3B0900),
      error:            errorColor,
      onError:          Colors.white,
      errorContainer:   Color(0xFFFFDAD6),
      onErrorContainer: Color(0xFF410002),
      surface:          surfaceColor,
      onSurface:        textPrimary,
      surfaceContainerHighest: Color(0xFFEEF2F7),
      outline:          Color(0xFFD0D5DD),
      outlineVariant:   Color(0xFFE8ECF0),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: backgroundColor,
      splashFactory: InkRipple.splashFactory,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS:     CupertinoPageTransitionsBuilder(),
        },
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        titleTextStyle: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: Colors.white,
          letterSpacing: 0.2,
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: surfaceColor,
        selectedItemColor: primaryColor,
        unselectedItemColor: textSecondary,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surfaceColor,
        indicatorColor: primaryColor.withValues(alpha: 0.12),
        labelTextStyle: WidgetStateProperty.all(
          const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryColor,
          side: const BorderSide(color: primaryColor),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryColor,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF7F9FC),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFD0D5DD)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFD0D5DD)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: errorColor),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: errorColor, width: 2),
        ),
        labelStyle: const TextStyle(color: textSecondary, fontSize: 14),
        hintStyle: const TextStyle(color: textTertiary, fontSize: 14),
      ),
      // Elevation 0 with a border — eliminates the ghost top-shadow line.
      cardTheme: CardThemeData(
        elevation: 0,
        shadowColor: Colors.transparent,
        margin: EdgeInsets.zero,
        color: surfaceColor,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFE8ECF0)),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: dividerColor,
        thickness: 1,
        space: 1,
      ),
      dialogTheme: DialogThemeData(
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        backgroundColor: surfaceColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      textTheme: const TextTheme(
        displayLarge:  TextStyle(fontSize: 32, fontWeight: FontWeight.bold,  color: textPrimary, letterSpacing: -0.5),
        displayMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.bold,  color: textPrimary, letterSpacing: -0.3),
        displaySmall:  TextStyle(fontSize: 24, fontWeight: FontWeight.bold,  color: textPrimary),
        headlineMedium:TextStyle(fontSize: 20, fontWeight: FontWeight.bold,  color: textPrimary),
        headlineSmall: TextStyle(fontSize: 18, fontWeight: FontWeight.bold,  color: textPrimary),
        titleLarge:    TextStyle(fontSize: 17, fontWeight: FontWeight.w600,  color: textPrimary),
        titleMedium:   TextStyle(fontSize: 15, fontWeight: FontWeight.w600,  color: textPrimary),
        titleSmall:    TextStyle(fontSize: 13, fontWeight: FontWeight.w600,  color: textPrimary),
        bodyLarge:     TextStyle(fontSize: 16, color: textPrimary,  height: 1.5),
        bodyMedium:    TextStyle(fontSize: 14, color: textSecondary, height: 1.5),
        bodySmall:     TextStyle(fontSize: 12, color: textTertiary,  height: 1.4),
        labelLarge:    TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textPrimary),
        labelMedium:   TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: textSecondary),
        labelSmall:    TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: textTertiary, letterSpacing: 0.5),
      ),
    );
  }

  // ── Dark Theme ────────────────────────────────────────────────────────────
  static ThemeData get darkTheme {
    const darkSurface      = Color(0xFF1C1C1E);
    const darkBackground   = Color(0xFF121214);
    const darkCard         = Color(0xFF2C2C2E);
    const darkDivider      = Color(0xFF38383A);
    const darkTextPrimary  = Color(0xFFF5F5F7);
    const darkTextSecondary= Color(0xFF98989F);

    return ThemeData(
      useMaterial3: true,
      colorScheme: const ColorScheme(
        brightness: Brightness.dark,
        primary:            primaryColor,
        onPrimary:          Colors.white,
        primaryContainer:   Color(0xFF0D3C7A),
        onPrimaryContainer: Color(0xFFD6E8FF),
        secondary:          secondaryColor,
        onSecondary:        Colors.white,
        secondaryContainer: Color(0xFF5A2008),
        onSecondaryContainer: Color(0xFFFFDCD0),
        error:              errorColor,
        onError:            Colors.white,
        errorContainer:     Color(0xFF93000A),
        onErrorContainer:   Color(0xFFFFDAD6),
        surface:            darkSurface,
        onSurface:          darkTextPrimary,
        surfaceContainerHighest: Color(0xFF3A3A3C),
        outline:            Color(0xFF48484A),
        outlineVariant:     darkDivider,
      ),
      scaffoldBackgroundColor: darkBackground,
      splashFactory: InkRipple.splashFactory,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS:     CupertinoPageTransitionsBuilder(),
        },
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF1C1C1E),
        foregroundColor: darkTextPrimary,
        elevation: 0,
        centerTitle: true,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        titleTextStyle: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: darkTextPrimary,
          letterSpacing: 0.2,
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: darkSurface,
        selectedItemColor: primaryColor,
        unselectedItemColor: darkTextSecondary,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: darkSurface,
        indicatorColor: primaryColor.withValues(alpha: 0.20),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryColor,
          side: const BorderSide(color: primaryColor),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryColor,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF2C2C2E),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF48484A)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF48484A)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: errorColor),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: errorColor, width: 2),
        ),
        labelStyle: const TextStyle(color: darkTextSecondary, fontSize: 14),
        hintStyle: const TextStyle(color: Color(0xFF636366), fontSize: 14),
      ),
      // Elevation 0 + subtle border — no ghost top-shadow in dark mode.
      cardTheme: const CardThemeData(
        elevation: 0,
        shadowColor: Colors.transparent,
        margin: EdgeInsets.zero,
        color: darkCard,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
          side: BorderSide(color: darkDivider),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: darkDivider,
        thickness: 1,
        space: 1,
      ),
      dialogTheme: const DialogThemeData(
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        backgroundColor: darkCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(20)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      textTheme: const TextTheme(
        displayLarge:  TextStyle(fontSize: 32, fontWeight: FontWeight.bold,  color: darkTextPrimary, letterSpacing: -0.5),
        displayMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.bold,  color: darkTextPrimary, letterSpacing: -0.3),
        displaySmall:  TextStyle(fontSize: 24, fontWeight: FontWeight.bold,  color: darkTextPrimary),
        headlineMedium:TextStyle(fontSize: 20, fontWeight: FontWeight.bold,  color: darkTextPrimary),
        headlineSmall: TextStyle(fontSize: 18, fontWeight: FontWeight.bold,  color: darkTextPrimary),
        titleLarge:    TextStyle(fontSize: 17, fontWeight: FontWeight.w600,  color: darkTextPrimary),
        titleMedium:   TextStyle(fontSize: 15, fontWeight: FontWeight.w600,  color: darkTextPrimary),
        titleSmall:    TextStyle(fontSize: 13, fontWeight: FontWeight.w600,  color: Color(0xFFB0B0B8)),
        bodyLarge:     TextStyle(fontSize: 16, color: darkTextPrimary,   height: 1.5),
        bodyMedium:    TextStyle(fontSize: 14, color: darkTextSecondary, height: 1.5),
        bodySmall:     TextStyle(fontSize: 12, color: Color(0xFF636366),  height: 1.4),
        labelLarge:    TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: darkTextPrimary),
        labelMedium:   TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: darkTextSecondary),
        labelSmall:    TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: Color(0xFF636366), letterSpacing: 0.5),
      ),
    );
  }
}
