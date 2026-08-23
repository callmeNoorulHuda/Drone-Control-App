import 'package:flutter/foundation.dart';
import 'marker_style.dart';

/// Holds app-wide user preferences set from the Settings screen: dark/light
/// mode and which SVG marker represents the drone on the map.
///
/// Same shape as VehicleState — a plain ChangeNotifier, exposed app-wide
/// via Provider from main.dart, watched wherever it needs to affect
/// rendering (MaterialApp's theme, DroneMapView, SettingsScreen itself).
///
/// NOTE: values reset to defaults on app restart — there's no persistence
/// layer yet. If you want the choice to survive a restart, that's a
/// `shared_preferences` addition (save on every change, load once in
/// main() before runApp) — ask if you want that wired up.
class SettingsController extends ChangeNotifier {
  bool _isDarkMode = true; // matches the app's original default look
  MarkerStyle _markerStyle = MarkerStyle.drone;

  bool get isDarkMode => _isDarkMode;
  MarkerStyle get markerStyle => _markerStyle;

  void setDarkMode(bool value) {
    if (_isDarkMode == value) return;
    _isDarkMode = value;
    notifyListeners();
  }

  void toggleDarkMode() => setDarkMode(!_isDarkMode);

  void setMarkerStyle(MarkerStyle style) {
    if (_markerStyle == style) return;
    _markerStyle = style;
    notifyListeners();
  }
}
