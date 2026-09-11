import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppDarkPalette {
  charcoalTeal,
  goldenAmber,
  trueBlack,
  royalPurple,
}

const String _kPrefsKeyPalette = 'dark_palette';

const Map<String, String> _legacyPaletteNames = {
  'midnightNavy': 'goldenAmber',
  'warmGraphite': 'royalPurple',
};

class ThemeNotifier extends ChangeNotifier {
  bool _isDarkMode = false;

  bool get isDarkMode => _isDarkMode;

  AppDarkPalette get darkPalette => ThemeService.currentPalette;

  void toggleTheme(bool value) {
    _isDarkMode = value;
    notifyListeners();
    _persist();
  }

  void setDarkPalette(AppDarkPalette palette) {
    ThemeService.setPalette(palette);
    notifyListeners();
    _persist();
  }

  Future<void> loadSavedPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    _isDarkMode = prefs.getBool('is_dark_mode') ?? _isDarkMode;

    final savedPaletteName = prefs.getString(_kPrefsKeyPalette);
    if (savedPaletteName != null) {
      final resolvedName =
          _legacyPaletteNames[savedPaletteName] ?? savedPaletteName;
      final match = AppDarkPalette.values.where((p) => p.name == resolvedName);
      if (match.isNotEmpty) {
        ThemeService.setPalette(match.first);
      }
    }
    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_dark_mode', _isDarkMode);
    await prefs.setString(_kPrefsKeyPalette, ThemeService.currentPalette.name);
  }

  ThemeData get themeData =>
      _isDarkMode ? ThemeService.darkTheme : ThemeService.lightTheme;
}

class _PaletteSpec {
  final String label;
  final String description;
  final Color bg;
  final Color surface;
  final Color surfaceAlt;
  final Color border;
  final Color accent;
  final Color accentLight;
  final Color textPrimary;
  final Color textSecondary;

  const _PaletteSpec({
    required this.label,
    required this.description,
    required this.bg,
    required this.surface,
    required this.surfaceAlt,
    required this.border,
    required this.accent,
    required this.accentLight,
    required this.textPrimary,
    required this.textSecondary,
  });
}

class ThemeService {
  ThemeService._();

  static AppDarkPalette _currentPalette = AppDarkPalette.charcoalTeal;
  static AppDarkPalette get currentPalette => _currentPalette;
  static void setPalette(AppDarkPalette palette) {
    _currentPalette = palette;
  }

  static const Map<AppDarkPalette, _PaletteSpec> _darkPalettes = {
    AppDarkPalette.charcoalTeal: _PaletteSpec(
      label: 'Slate Blue',
      description: 'Deep slate-navy background, steel-blue accent (default)',
      bg: Color(0xFF0F1720),
      surface: Color(0xFF16212C),
      surfaceAlt: Color(0xFF1E2C39),
      border: Color(0xFF2C3E4E),
      accent: Color(0xFF5B9BD5),
      accentLight: Color(0xFF8FC1E8),
      textPrimary: Color(0xFFF5F8FA),
      textSecondary: Color(0xFF9DB0C0),
    ),
    AppDarkPalette.goldenAmber: _PaletteSpec(
      label: 'Soft Yellow',
      description: 'Neutral charcoal background, bright yellow accent',
      bg: Color(0xFF17181B),
      surface: Color(0xFF1E2024),
      surfaceAlt: Color(0xFF272A2F),
      border: Color(0xFF3B3E44),
      accent: Color(0xFFFFD400),
      accentLight: Color(0xFFFFE566),
      textPrimary: Color(0xFFFAFAF8),
      textSecondary: Color(0xFFB1B4B9),
    ),
    AppDarkPalette.trueBlack: _PaletteSpec(
      label: 'Deep Forest',
      description: 'Near-black background, soft sage-green accent',
      bg: Color(0xFF0A0D0B),
      surface: Color(0xFF101512),
      surfaceAlt: Color(0xFF171E19),
      border: Color(0xFF2A362E),
      accent: Color(0xFF5B9E7C),
      accentLight: Color(0xFF93C7AA),
      textPrimary: Color(0xFFF5FAF6),
      textSecondary: Color(0xFF9DB5A5),
    ),
    AppDarkPalette.royalPurple: _PaletteSpec(
      label: 'Midnight Indigo',
      description: 'Dark indigo-gray background, muted periwinkle accent',
      bg: Color(0xFF14161F),
      surface: Color(0xFF1B1E2A),
      surfaceAlt: Color(0xFF232838),
      border: Color(0xFF37405A),
      accent: Color(0xFF7B8FD4),
      accentLight: Color(0xFFADB9EA),
      textPrimary: Color(0xFFF6F7FB),
      textSecondary: Color(0xFFA6ACC4),
    ),
  };

  static List<AppDarkPalette> get availableDarkPalettes =>
      _darkPalettes.keys.toList(growable: false);

  static String labelOf(AppDarkPalette p) => _darkPalettes[p]!.label;
  static String descriptionOf(AppDarkPalette p) =>
      _darkPalettes[p]!.description;
  static Color previewColorOf(AppDarkPalette p) => _darkPalettes[p]!.accent;
  static Color previewBgOf(AppDarkPalette p) => _darkPalettes[p]!.bg;

  static Color get darkBg => _darkPalettes[_currentPalette]!.bg;
  static Color get darkSurface => _darkPalettes[_currentPalette]!.surface;
  static Color get darkSurfaceAlt => _darkPalettes[_currentPalette]!.surfaceAlt;
  static Color get darkBorder => _darkPalettes[_currentPalette]!.border;
  static Color get darkAccent => _darkPalettes[_currentPalette]!.accent;
  static Color get darkAccentLight =>
      _darkPalettes[_currentPalette]!.accentLight;
  static Color get darkTextPrimary =>
      _darkPalettes[_currentPalette]!.textPrimary;
  static Color get darkTextSecondary =>
      _darkPalettes[_currentPalette]!.textSecondary;

  static const Color lightBg = Color(0xFFF4F6FA);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceAlt = Color(0xFFF7F9FC);
  static const Color lightBorder = Color(0xFFE2E7F0);

  static const Color accentDeep = Color(0xFF2C5F8A);
  static const Color accent = Color(0xFF4A90C4);
  static const Color accentLight = Color(0xFF7FB3DC);
  static const Color accentSky = Color(0xFF9CC9E8);

  static const Color danger = Color(0xFFD35B5B);
  static const Color success = Color(0xFF4C9E76);
  static const Color warning = Color(0xFFCB9A4E);

  static Color infoBlue(bool isDark) =>
      isDark ? const Color(0xFF8AAEDD) : const Color(0xFF4A70B0);
  static Color dangerSoft(bool isDark) =>
      isDark ? const Color(0xFFE08585) : danger;

  static Color bg(bool isDark) => isDark ? darkBg : lightBg;
  static Color surface(bool isDark) => isDark ? darkSurface : lightSurface;
  static Color surfaceAlt(bool isDark) =>
      isDark ? darkSurfaceAlt : lightSurfaceAlt;
  static Color border(bool isDark) => isDark ? darkBorder : lightBorder;
  static Color textPrimary(bool isDark) =>
      isDark ? darkTextPrimary : const Color(0xFF1B2635);
  static Color textSecondary(bool isDark) =>
      isDark ? darkTextSecondary : const Color(0xFF64748B);

  static Color activeAccent(bool isDark) => isDark ? darkAccent : accent;
  static Color activeAccentLight(bool isDark) =>
      isDark ? darkAccentLight : accentLight;

  static Color darkTintedChip(Color moduleColor, {double amount = 0.20}) {
    return Color.alphaBlend(
      moduleColor.withValues(alpha: amount),
      darkSurfaceAlt,
    );
  }

  static ThemeData get darkTheme => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: darkBg,
        primaryColor: darkAccent,
        colorScheme: ColorScheme.dark(
          primary: darkAccent,
          secondary: darkAccentLight,
          surface: darkSurface,
          error: danger,
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: darkSurface,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: false,
        ),
        cardColor: darkSurfaceAlt,
        dividerColor: darkBorder,
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith((states) =>
              states.contains(WidgetState.selected)
                  ? darkAccent
                  : Colors.grey.shade400),
          trackColor: WidgetStateProperty.resolveWith((states) =>
              states.contains(WidgetState.selected)
                  ? darkAccent.withValues(alpha: 0.4)
                  : Colors.grey.shade700),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: darkSurfaceAlt,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: darkBorder)),
        ),
        dialogTheme: DialogThemeData(backgroundColor: darkSurface),
      );

  static ThemeData get lightTheme => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: lightBg,
        primaryColor: accent,
        colorScheme: const ColorScheme.light(
          primary: accent,
          secondary: accentLight,
          surface: lightSurface,
          error: danger,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: lightSurface,
          foregroundColor: accentDeep,
          elevation: 0,
          centerTitle: false,
        ),
        cardColor: lightSurface,
        dividerColor: lightBorder,
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith((states) =>
              states.contains(WidgetState.selected)
                  ? accent
                  : Colors.grey.shade400),
          trackColor: WidgetStateProperty.resolveWith((states) =>
              states.contains(WidgetState.selected)
                  ? accent.withValues(alpha: 0.4)
                  : Colors.grey.shade300),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: lightSurfaceAlt,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: lightBorder)),
        ),
        dialogTheme: const DialogThemeData(backgroundColor: lightSurface),
      );

  // Used exclusively by Baby Health Tracker screens (profile header
  // cards, Add Baby button/FAB, selected gender chip). Previously a
  // flat navy-to-mid-blue gradient that read as dull/"ugly" in light
  // mode — now a livelier slate-blue → sky-blue combo instead.
  static const Gradient profileGradient = LinearGradient(
    colors: [Color(0xFF5B9BD5), Color(0xFF8EC9EF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const Gradient weightGradient = LinearGradient(
    colors: [Color(0xFF2B6E76), Color(0xFF4FA6B0)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const Gradient vaccinationGradient = LinearGradient(
    colors: [Color(0xFF2F5E82), Color(0xFF5A8FB5)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const Gradient milestoneGradient = LinearGradient(
    colors: [Color(0xFF2E7A6C), Color(0xFF5AAE9C)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const Gradient allergyGradient = LinearGradient(
    colors: [Color(0xFF9A4A52), Color(0xFFC97077)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const Gradient medicalGradient = LinearGradient(
    colors: [Color(0xFF2E5A87), Color(0xFF5589B8)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const Gradient dangerGradient = LinearGradient(
    colors: [Color(0xFF8A3B44), Color(0xFFC15A5A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static Color solidOf(Gradient g) => (g as LinearGradient).colors.last;
}

class AppThemeColors {
  final bool isDark;
  const AppThemeColors(this.isDark);

  Color get bg => ThemeService.bg(isDark);
  Color get surface => ThemeService.surface(isDark);
  Color get surfaceAlt => ThemeService.surfaceAlt(isDark);
  Color get border => ThemeService.border(isDark);
  Color get textPrimary => ThemeService.textPrimary(isDark);
  Color get textSecondary => ThemeService.textSecondary(isDark);
  Color get accent => ThemeService.activeAccent(isDark);
  Color get accentLight => ThemeService.activeAccentLight(isDark);
  Color get infoBlue => ThemeService.infoBlue(isDark);
  Color get danger => ThemeService.dangerSoft(isDark);
}

class ThemeAware extends StatelessWidget {
  final Widget Function(BuildContext context, AppThemeColors theme) builder;
  const ThemeAware({super.key, required this.builder});

  @override
  Widget build(BuildContext context) {
    context.watch<ThemeNotifier>();
    final isDark = context.read<ThemeNotifier>().isDarkMode;
    return builder(context, AppThemeColors(isDark));
  }
}
