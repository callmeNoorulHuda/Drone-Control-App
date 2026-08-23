import 'package:flutter/material.dart';

/// SafeSky Nexus brand palette — deep navy base (from the logo's #121358)
/// with the brand orange (#E67514) as the single accent used for actions,
/// warnings, and the drone/heading marker. A soft periwinkle is used only
/// for live telemetry numbers, so data readouts stay legible against navy
/// without competing with the orange accent.
class AppColors {
  static const bg = Color(0xFF0A0C24);
  static const surface = Color(0xFF121358);
  static const surfaceRaised = Color(0xFF1D2270);
  static const hairline = Color(0xFF2A2F6B);

  static const amber = Color(0xFFE67514); // brand orange — primary accent
  static const amberDim = Color(0xFF8A4A0D);
  static const cyan = Color(0xFF8892E0); // telemetry readout tint
  static const cyanDim = Color(0xFF363C8F);

  static const textPrimary = Color(0xFFF4F5FA);
  static const textSecondary = Color(0xFFA6ACD6);

  static const danger = Color(0xFFE05B4F);
  static const success = Color(0xFF57C785);
}

/// Telemetry numbers use tighter letter-spacing + a monospace fallback
/// so they read as instrument readouts rather than ordinary body text.
const telemetryNumberStyle = TextStyle(
  fontFamily: 'monospace',
  fontFeatures: [FontFeature.tabularFigures()],
  fontWeight: FontWeight.w600,
  letterSpacing: 0.5,
  color: AppColors.cyan,
);

ThemeData buildAppTheme() {
  final base = ThemeData.dark(useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: AppColors.bg,
    colorScheme: base.colorScheme.copyWith(
      primary: AppColors.amber,
      secondary: AppColors.cyan,
      surface: AppColors.surface,
      error: AppColors.danger,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.bg,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: AppColors.textPrimary,
        fontSize: 20,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.3,
      ),
    ),
    textTheme: base.textTheme.apply(
      bodyColor: AppColors.textPrimary,
      displayColor: AppColors.textPrimary,
    ),
    dividerColor: AppColors.hairline,
  );
}

/// Light counterpart to buildAppTheme(), same brand orange accent on a
/// clean white/soft-gray base instead of navy. Used when the person
/// toggles Light Mode in Settings.
///
/// SCOPE NOTE: this drives MaterialApp's theme (dialogs, the default
/// AppBar, switches, etc.) and any widget that reads Theme.of(context) —
/// which is exactly how the new SettingsScreen and DroneMapView's tiles
/// are built. Most of the existing screen (TopBar, FlightStatusPanel,
/// TelemetryPanel, VirtualJoystick) currently hardcodes AppColors.bg /
/// AppColors.surface directly rather than reading from Theme.of(context),
/// so those keep their current navy look regardless of this toggle. Making
/// the whole flight screen theme-aware is a bigger follow-up refactor —
/// ask if you want that done next.
ThemeData buildAppLightTheme() {
  final base = ThemeData.light(useMaterial3: true);
  const lightBg = Color(0xFFF4F6FB);
  const lightSurface = Color(0xFFFFFFFF);
  const lightText = Color(0xFF11151F);
  return base.copyWith(
    scaffoldBackgroundColor: lightBg,
    colorScheme: base.colorScheme.copyWith(
      primary: AppColors.amber,
      secondary: AppColors.cyan,
      surface: lightSurface,
      error: AppColors.danger,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: lightBg,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: lightText,
        fontSize: 20,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.3,
      ),
    ),
    textTheme: base.textTheme.apply(
      bodyColor: lightText,
      displayColor: lightText,
    ),
    dividerColor: Colors.black12,
  );
}
