/// Pointer style options the user can pick in Settings for the drone's
/// position marker on the map. Maps 1:1 to the three SVGs in
/// assets/icons/ — see MarkerStyleAsset below for the actual file paths.
enum MarkerStyle { drone, droneAlt, airplane }

/// Centralizes "which SVG file + label goes with which style" in one
/// place, so drone_map_view.dart (rendering) and settings_screen.dart
/// (picker UI) both read from the same source instead of duplicating
/// this mapping and risking them drifting out of sync.
extension MarkerStyleAsset on MarkerStyle {
  String get assetPath {
    switch (this) {
      case MarkerStyle.drone:
        return 'assets/icons/drone_marker.svg';
      case MarkerStyle.droneAlt:
        return 'assets/icons/drone_marker_1.svg';
      case MarkerStyle.airplane:
        return 'assets/icons/airplane_marker.svg';
    }
  }

  String get label {
    switch (this) {
      case MarkerStyle.drone:
        return 'Drone';
      case MarkerStyle.droneAlt:
        return 'Drone Alt';
      case MarkerStyle.airplane:
        return 'Airplane';
    }
  }
}
