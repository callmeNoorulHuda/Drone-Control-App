import 'package:flutter/foundation.dart';
import '../state/joystick_style.dart';
import 'marker_style.dart';
import 'unit_system.dart';

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
  JoystickStyle _joystickStyle = JoystickStyle.classic;
  JoystickStyle get joystickStyle => _joystickStyle;

  bool _isMapDark = true;
  bool get isMapDark => _isMapDark;

  void setMapDark(bool value) {
    if (_isMapDark == value) return;
    _isMapDark = value;
    notifyListeners();
  }

  void setJoystickStyle(JoystickStyle style) {
    if (_joystickStyle == style) return;
    _joystickStyle = style;
    notifyListeners();
  }

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

  UnitSystem _unitSystem = UnitSystem.metric;
  UnitSystem get unitSystem => _unitSystem;

  void setUnitSystem(UnitSystem system) {
    if (_unitSystem == system) return;
    _unitSystem = system;
    notifyListeners();
  }

  // Street = OSM/CartoDB tiles (existing default). Satellite = imagery
  // tiles. Just a bool since there are only two options right now.
  bool _useSatelliteMap = false;
  bool get useSatelliteMap => _useSatelliteMap;

  void setUseSatelliteMap(bool value) {
    if (_useSatelliteMap == value) return;
    _useSatelliteMap = value;
    notifyListeners();
  }
}
