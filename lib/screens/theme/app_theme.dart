import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── Global font scale ─────────────────────────────────────────────────────────

class FontScaleNotifier extends ValueNotifier<double> {
  static const String _key = 'app_font_scale';
  static const double defaultScale = 1.15;

  // Available options: label → scale factor
  static const Map<String, double> options = {
    'Small': 0.85,
    'Default': 1.20,
    'Large': 1.30,
    'Extra Large': 1.50,
  };

  FontScaleNotifier() : super(defaultScale);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    value = prefs.getDouble(_key) ?? defaultScale;
  }

  Future<void> setScale(double scale) async {
    value = scale;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_key, scale);
  }
}

/// Single global instance — import app_theme.dart to access it
final fontScaleNotifier = FontScaleNotifier();

// ── Global theme mode ─────────────────────────────────────────────────────────

class ThemeModeNotifier extends ValueNotifier<ThemeMode> {
  static const String _key = 'app_theme_mode';

  ThemeModeNotifier() : super(ThemeMode.system);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_key) ?? 'system';
    value = _fromString(stored);
  }

  Future<void> setMode(ThemeMode mode) async {
    value = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, _toString(mode));
  }

  static ThemeMode _fromString(String s) {
    switch (s) {
      case 'light': return ThemeMode.light;
      case 'dark': return ThemeMode.dark;
      default: return ThemeMode.system;
    }
  }

  static String _toString(ThemeMode m) {
    switch (m) {
      case ThemeMode.light: return 'light';
      case ThemeMode.dark: return 'dark';
      case ThemeMode.system: return 'system';
    }
  }
}

final themeModeNotifier = ThemeModeNotifier();

// ── Brightness flag (set by MyApp builder) ────────────────────────────────────

Brightness _appBrightness = Brightness.light;
void setAppBrightness(Brightness b) => _appBrightness = b;

// ── Colors ────────────────────────────────────────────────────────────────────

class AppColors {
  static bool get _dark => _appBrightness == Brightness.dark;

  // Semantic colors
  static Color get background    => _dark ? const Color(0xFF121218) : const Color(0xFFF7F8FA);
  static Color get surface       => _dark ? const Color(0xFF1E1E2A) : const Color(0xFFFFFFFF);
  static Color get textPrimary   => _dark ? const Color(0xFFE8E8ED) : const Color(0xFF1A1A2E);
  static Color get textSecondary => _dark ? const Color(0xFF8A8A9A) : const Color(0xFF9CA3AF);
  static Color get divider       => _dark ? const Color(0xFF2C2C3A) : const Color(0xFFE5E7EB);
  static Color get pillBg        => _dark ? const Color(0xFF252535) : const Color(0xFFF3F4F6);
  static Color get chartGrid     => _dark ? const Color(0xFF2C2C3A) : const Color(0xFFD1D5DB);

  // Brand colors — same in both modes
  static const blue   = Color(0xFF2D8BE0);
  static const green  = Color(0xFF16A34A);
  static const red    = Color(0xFFEF4444);
  static const amber  = Color(0xFFF59E0B);
  static const purple = Color(0xFF8B5CF6);

  // Icon backgrounds — dimmed for dark
  static Color get iconBgBlue   => _dark ? const Color(0xFF1A2A40) : const Color(0xFFEBF5FF);
  static Color get iconBgGreen  => _dark ? const Color(0xFF152E20) : const Color(0xFFECFDF5);
  static Color get iconBgAmber  => _dark ? const Color(0xFF2E2510) : const Color(0xFFFFFBEB);
  static Color get iconBgPurple => _dark ? const Color(0xFF201A35) : const Color(0xFFF5F3FF);
  static Color get iconBgRed    => _dark ? const Color(0xFF2E1515) : const Color(0xFFFEF2F2);
}

// ── Typography ────────────────────────────────────────────────────────────────

class AppTypography {
  static const String fontBody = 'Inter';
  static const String fontSerif = 'Inter';

  static TextStyle get dashboardLabel => TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.5,
    color: AppColors.textSecondary,
  );

  static TextStyle get companyName => TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  static TextStyle get cardLabel => TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.8,
    color: AppColors.textSecondary,
  );

  static TextStyle get cardValue => TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    letterSpacing: -0.5,
  );

  static TextStyle get cardUnit => TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondary,
  );

  static TextStyle get pageTitle => TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );

  static TextStyle get itemTitle => TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  static TextStyle get itemSubtitle => TextStyle(
    fontSize: 12,
    color: AppColors.textSecondary,
  );

  // ── Chart common styles ──────────────────────────────────────────────
  static TextStyle get chartAxisLabel => TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondary,
  );

  static TextStyle get chartSectionTitle => TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.5,
    color: AppColors._dark ? const Color(0xFFD0D0DA) : const Color(0xFF4A4A5A),
  );

  static TextStyle get chartLegendLabel => TextStyle(
    fontSize: 11,
    color: AppColors.textSecondary,
  );

  static TextStyle get chartLegendValue => TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  static const chartTooltipLabel = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: Colors.white,
  );

  static const chartTooltipValue = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w700,
    color: Colors.white,
  );

  static const chartPieLabel = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    color: Colors.white,
  );

  static TextStyle get badge => TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w600,
  );

  static const pillActive = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: Colors.white,
  );

  static TextStyle get pillInactive => TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondary,
  );
}

class AppSpacing {
  static const double pagePadding = 20.0;
  static const double cardGap = 12.0;
  static const double sectionGap = 20.0;
}

class AppRadius {
  static const double card = 14.0;
  static const double pill = 20.0;
  static const double pillInner = 16.0;
}

class AppShadows {
  static bool get _dark => _appBrightness == Brightness.dark;

  static List<BoxShadow> get card => _dark
      ? []
      : [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 2))];

  static List<BoxShadow> get headerIcon => _dark
      ? []
      : [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 1))];

  static List<BoxShadow> get pillActive => _dark
      ? []
      : [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 4, offset: const Offset(0, 1))];

  // Use this border for cards in dark mode instead of shadows
  static Border? get cardBorder => _dark
      ? Border.all(color: AppColors.divider, width: 0.5)
      : null;
}
