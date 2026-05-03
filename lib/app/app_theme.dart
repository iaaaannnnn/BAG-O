part of 'app.dart';

class BagoColors {
  const BagoColors._();

  static const primary = Color(0xFF1F6B3A);
  static const primaryDark = Color(0xFF2F8A4C);
  static const accent = Color(0xFFCA8A04);
  static const success = Color(0xFF2E7D32);
  static const warning = Color(0xFFF59E0B);
  static const danger = Color(0xFFB91C1C);
  static const ink = Color(0xFF18231D);
  static const muted = Color(0xFF66736A);
  static const border = Color(0xFFD8DED9);
  static const canvas = Color(0xFFF5F7F4);
  static const surface = Color(0xFFFFFFFF);
  static const darkCanvas = Color(0xFF101713);
  static const darkSurface = Color(0xFF17211B);
  static const darkBorder = Color(0xFF2C3B31);
}

class AppTheme {
  const AppTheme._();

  static ThemeData get light => _build(
        brightness: Brightness.light,
        primary: BagoColors.primary,
        surface: BagoColors.surface,
        scaffold: BagoColors.canvas,
        onSurface: BagoColors.ink,
        muted: BagoColors.muted,
        border: BagoColors.border,
        error: BagoColors.danger,
      );

  static ThemeData get dark => _build(
        brightness: Brightness.dark,
        primary: BagoColors.primaryDark,
        surface: BagoColors.darkSurface,
        scaffold: BagoColors.darkCanvas,
        onSurface: const Color(0xFFE8EEE9),
        muted: const Color(0xFFA7B2AA),
        border: BagoColors.darkBorder,
        error: const Color(0xFFEF4444),
      );

  static ThemeData _build({
    required Brightness brightness,
    required Color primary,
    required Color surface,
    required Color scaffold,
    required Color onSurface,
    required Color muted,
    required Color border,
    required Color error,
  }) {
    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: scaffold,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        brightness: brightness,
        primary: primary,
        secondary: BagoColors.accent,
        surface: surface,
        error: error,
        onPrimary: Colors.white,
        onSurface: onSurface,
        outline: border,
      ),
      fontFamily: GoogleFonts.outfit().fontFamily,
      dividerColor: border,
    );

    final textTheme = GoogleFonts.outfitTextTheme(base.textTheme).apply(
      bodyColor: onSurface,
      displayColor: onSurface,
    );

    return base.copyWith(
      textTheme: textTheme.copyWith(
        headlineMedium: textTheme.headlineMedium?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: -0.2,
          height: 1.1,
        ),
        headlineSmall: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700, letterSpacing: 0),
        titleSmall: textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: 0.1,
        ),
        titleLarge: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700, letterSpacing: 0),
        titleMedium: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700, letterSpacing: 0),
        bodyMedium: textTheme.bodyMedium?.copyWith(color: muted),
        bodySmall: textTheme.bodySmall?.copyWith(color: muted),
        labelLarge: textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: 0.1,
        ),
      ),
      iconTheme: IconThemeData(
        size: 20,
        color: onSurface,
      ),
      appBarTheme: AppBarTheme(
        elevation: 0,
        centerTitle: false,
        scrolledUnderElevation: 0,
        backgroundColor: primary,
        foregroundColor: Colors.white,
        titleTextStyle: GoogleFonts.outfit(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          letterSpacing: 0,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: surface,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: border.withValues(alpha: 0.72)),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(48, 44),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: GoogleFonts.outfit(fontWeight: FontWeight.w700, letterSpacing: 0),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: GoogleFonts.outfit(fontWeight: FontWeight.w700, letterSpacing: 0),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: BorderSide(color: border),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: GoogleFonts.outfit(fontWeight: FontWeight.w700, letterSpacing: 0),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: primary, width: 1.5)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: error)),
        labelStyle: TextStyle(color: muted),
        helperStyle: TextStyle(color: muted),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        minVerticalPadding: 8,
        iconColor: muted,
      ),
      chipTheme: base.chipTheme.copyWith(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
          side: BorderSide(color: border.withValues(alpha: 0.8)),
        ),
        side: BorderSide(color: border.withValues(alpha: 0.8)),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        labelStyle: textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: primary,
        unselectedLabelColor: muted,
        dividerColor: Colors.transparent,
        indicatorSize: TabBarIndicatorSize.tab,
        labelStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        unselectedLabelStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        labelPadding: const EdgeInsets.symmetric(horizontal: 12),
        indicator: BoxDecoration(
          color: primary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: primary.withValues(alpha: 0.22)),
        ),
      ),
    );
  }
}
