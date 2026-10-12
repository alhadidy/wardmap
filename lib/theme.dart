/// Wardmap's design system: colors, type, spacing and the light and dark
/// themes built from them. Screens read these through Theme.of(context)
/// rather than hard-coding values. See docs/design-system.md.
library;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Spacing steps. Use these for padding and gaps so screens line up.
abstract final class Space {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
}

/// Corner radii.
abstract final class Radii {
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double pill = 999;
}

/// The palette. Teal is the brand (it matches the "your patient" beds on the
/// floor plan); slate greys keep everything else calm and readable.
abstract final class Palette {
  // Brand
  static const teal = Color(0xFF0F766E);
  static const tealLight = Color(0xFF2DD4BF);
  static const tealTint = Color(0xFFCCFBF1);
  static const tealDeep = Color(0xFF134E4A);

  // Light neutrals
  static const ink = Color(0xFF0F172A);
  static const inkMuted = Color(0xFF475569);
  static const line = Color(0xFFE2E8F0);
  static const lineStrong = Color(0xFFCBD5E1);
  static const canvas = Color(0xFFF4F6F8);
  static const paper = Color(0xFFFFFFFF);
  static const paperDim = Color(0xFFEEF2F5);

  // Dark neutrals
  static const night = Color(0xFF0B1220);
  static const nightPaper = Color(0xFF131C2B);
  static const nightRaised = Color(0xFF1B2638);
  static const nightLine = Color(0xFF283548);
  static const nightInk = Color(0xFFE2E8F0);
  static const nightInkMuted = Color(0xFF94A3B8);
}

/// How serious something is: drives the color of pills and banners.
enum Tone { neutral, brand, success, warning, danger, info }

/// Status colors that Material's ColorScheme has no slot for. Read with
/// `context.tones`.
@immutable
class ToneColors extends ThemeExtension<ToneColors> {
  const ToneColors(this._colors);

  /// For each tone: (background, foreground).
  final Map<Tone, (Color, Color)> _colors;

  Color background(Tone t) => _colors[t]!.$1;
  Color foreground(Tone t) => _colors[t]!.$2;

  static const light = ToneColors({
    Tone.neutral: (Color(0xFFEEF2F5), Color(0xFF475569)),
    Tone.brand: (Palette.tealTint, Palette.tealDeep),
    Tone.success: (Color(0xFFDCFCE7), Color(0xFF166534)),
    Tone.warning: (Color(0xFFFEF3C7), Color(0xFF92400E)),
    Tone.danger: (Color(0xFFFEE2E2), Color(0xFF991B1B)),
    Tone.info: (Color(0xFFDBEAFE), Color(0xFF1E40AF)),
  });

  static const dark = ToneColors({
    Tone.neutral: (Color(0xFF243044), Color(0xFFCBD5E1)),
    Tone.brand: (Color(0xFF123B38), Color(0xFF5EEAD4)),
    Tone.success: (Color(0xFF14352A), Color(0xFF86EFAC)),
    Tone.warning: (Color(0xFF3B2C12), Color(0xFFFCD34D)),
    Tone.danger: (Color(0xFF3F1D22), Color(0xFFFCA5A5)),
    Tone.info: (Color(0xFF1C2D4F), Color(0xFF93C5FD)),
  });

  @override
  ToneColors copyWith() => this;

  @override
  ToneColors lerp(ToneColors? other, double t) {
    if (other == null) return this;
    return ToneColors({
      for (final tone in Tone.values)
        tone: (
          Color.lerp(background(tone), other.background(tone), t)!,
          Color.lerp(foreground(tone), other.foreground(tone), t)!,
        ),
    });
  }
}

extension ThemeShortcuts on BuildContext {
  ColorScheme get colors => Theme.of(this).colorScheme;
  TextTheme get text => Theme.of(this).textTheme;
  ToneColors get tones => Theme.of(this).extension<ToneColors>()!;
}

ThemeData lightTheme() => _theme(
  ColorScheme.fromSeed(seedColor: Palette.teal).copyWith(
    primary: Palette.teal,
    onPrimary: Colors.white,
    primaryContainer: Palette.tealTint,
    onPrimaryContainer: Palette.tealDeep,
    secondaryContainer: Palette.tealTint,
    onSecondaryContainer: Palette.tealDeep,
    surface: Palette.paper,
    onSurface: Palette.ink,
    onSurfaceVariant: Palette.inkMuted,
    surfaceContainerLowest: Palette.paper,
    surfaceContainerLow: Palette.canvas,
    surfaceContainer: Palette.canvas,
    surfaceContainerHigh: Palette.paperDim,
    surfaceContainerHighest: Palette.paperDim,
    outline: Palette.lineStrong,
    outlineVariant: Palette.line,
    error: const Color(0xFFB91C1C),
  ),
  canvas: Palette.canvas,
  tones: ToneColors.light,
);

ThemeData darkTheme() => _theme(
  ColorScheme.fromSeed(
    seedColor: Palette.teal,
    brightness: Brightness.dark,
  ).copyWith(
    primary: Palette.tealLight,
    onPrimary: const Color(0xFF042F2E),
    primaryContainer: const Color(0xFF123B38),
    onPrimaryContainer: const Color(0xFF99F6E4),
    secondaryContainer: const Color(0xFF123B38),
    onSecondaryContainer: const Color(0xFF99F6E4),
    surface: Palette.nightPaper,
    onSurface: Palette.nightInk,
    onSurfaceVariant: Palette.nightInkMuted,
    surfaceContainerLowest: Palette.night,
    surfaceContainerLow: Palette.night,
    surfaceContainer: Palette.nightPaper,
    surfaceContainerHigh: Palette.nightRaised,
    surfaceContainerHighest: Palette.nightRaised,
    outline: const Color(0xFF3A4A61),
    outlineVariant: Palette.nightLine,
    error: const Color(0xFFF87171),
  ),
  canvas: Palette.night,
  tones: ToneColors.dark,
);

ThemeData _theme(
  ColorScheme c, {
  required Color canvas,
  required ToneColors tones,
}) {
  final base = ThemeData(colorScheme: c, useMaterial3: true);
  final text = _textTheme(base.textTheme, c);
  final rounded = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(Radii.md),
  );
  const buttonSize = Size(64, 48);
  return base.copyWith(
    scaffoldBackgroundColor: canvas,
    textTheme: text,
    extensions: [tones],
    visualDensity: VisualDensity.standard,
    dividerTheme: DividerThemeData(
      color: c.outlineVariant,
      space: 1,
      thickness: 1,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: canvas,
      foregroundColor: c.onSurface,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: text.titleLarge,
      shape: Border(bottom: BorderSide(color: c.outlineVariant)),
    ),
    cardTheme: CardThemeData(
      color: c.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: rounded.copyWith(side: BorderSide(color: c.outlineVariant)),
      clipBehavior: Clip.antiAlias,
    ),
    listTileTheme: ListTileThemeData(
      contentPadding: const EdgeInsets.symmetric(horizontal: Space.lg),
      minVerticalPadding: Space.md,
      titleTextStyle: text.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
      subtitleTextStyle: text.bodyMedium?.copyWith(color: c.onSurfaceVariant),
      iconColor: c.onSurfaceVariant,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: c.surface,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: Space.lg,
        vertical: Space.md + 2,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Radii.sm + 2),
        borderSide: BorderSide(color: c.outline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Radii.sm + 2),
        borderSide: BorderSide(color: c.outline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Radii.sm + 2),
        borderSide: BorderSide(color: c.primary, width: 2),
      ),
      prefixIconColor: c.onSurfaceVariant,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: buttonSize,
        shape: rounded,
        textStyle: text.labelLarge,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: buttonSize,
        shape: rounded,
        side: BorderSide(color: c.outline),
        textStyle: text.labelLarge,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(shape: rounded, textStyle: text.labelLarge),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: c.primary,
      foregroundColor: c.onPrimary,
      elevation: 2,
      highlightElevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.lg),
      ),
      extendedTextStyle: text.labelLarge,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: c.surface,
      surfaceTintColor: Colors.transparent,
      indicatorColor: c.primaryContainer,
      height: 68,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (s) => text.labelMedium?.copyWith(
          color: s.contains(WidgetState.selected)
              ? c.onSurface
              : c.onSurfaceVariant,
          fontWeight: s.contains(WidgetState.selected)
              ? FontWeight.w600
              : FontWeight.w500,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (s) => IconThemeData(
          color: s.contains(WidgetState.selected)
              ? c.onPrimaryContainer
              : c.onSurfaceVariant,
        ),
      ),
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: c.primary,
      unselectedLabelColor: c.onSurfaceVariant,
      labelStyle: text.labelLarge,
      unselectedLabelStyle: text.labelLarge?.copyWith(
        fontWeight: FontWeight.w500,
      ),
      indicatorColor: c.primary,
      dividerColor: Colors.transparent,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: c.surface,
      selectedColor: c.primaryContainer,
      side: BorderSide(color: c.outlineVariant),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.sm),
      ),
      labelStyle: text.labelLarge?.copyWith(fontWeight: FontWeight.w500),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: c.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.lg),
      ),
      titleTextStyle: text.titleLarge,
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: c.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.md),
        side: BorderSide(color: c.outlineVariant),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: c.brightness == Brightness.light
          ? Palette.ink
          : Palette.nightRaised,
      contentTextStyle: text.bodyMedium?.copyWith(color: Palette.nightInk),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.md),
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? c.onPrimary : null,
      ),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: c.primary),
  );
}

/// Roboto (the platform default) with firmer weights for headings and
/// slightly taller lines for reading notes. Small print is grey.
TextTheme _textTheme(TextTheme t, ColorScheme c) => t
    .copyWith(
      headlineMedium: t.headlineMedium?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
      ),
      headlineSmall: t.headlineSmall?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.25,
      ),
      titleLarge: t.titleLarge?.copyWith(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
      ),
      titleMedium: t.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      titleSmall: t.titleSmall?.copyWith(fontWeight: FontWeight.w600),
      bodyLarge: t.bodyLarge?.copyWith(height: 1.4),
      bodyMedium: t.bodyMedium?.copyWith(height: 1.4),
      labelLarge: t.labelLarge?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
      ),
      labelSmall: t.labelSmall?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: 0.4,
      ),
    )
    .apply(bodyColor: c.onSurface, displayColor: c.onSurface)
    .copyWith(bodySmall: t.bodySmall?.copyWith(color: c.onSurfaceVariant));

/// Light, dark, or follow the phone. Remembered on this device.
final themeMode = ValueNotifier(ThemeMode.system);

const _themeKey = 'theme_mode';

Future<void> loadThemeMode() async {
  try {
    final saved = (await SharedPreferences.getInstance()).getString(_themeKey);
    themeMode.value = ThemeMode.values.firstWhere(
      (m) => m.name == saved,
      orElse: () => ThemeMode.system,
    );
  } catch (_) {
    // Storage unavailable (e.g. private browsing): follow the phone.
  }
}

Future<void> setThemeMode(ThemeMode mode) async {
  themeMode.value = mode;
  try {
    await (await SharedPreferences.getInstance()).setString(
      _themeKey,
      mode.name,
    );
  } catch (_) {}
}
