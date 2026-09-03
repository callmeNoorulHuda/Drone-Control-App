# Implementation Plan - Enhanced Theme and Localization

This plan details the steps to implement a responsive light/dark mode for all screens, add a map theme option, and integrate multi-language support.

## User Review Required

> [!IMPORTANT]
> - I will be adding `easy_localization` to the project. This requires running `flutter pub get` which I will attempt via shell.
> - Translation files will be created in `assets/translations/`.
> - The joystick colors in light mode will be light gray with orange accents to maintain design consistency.
> - The map theme option will affect the "Street" view tiles.

## Proposed Changes

### Dependencies
#### [MODIFY] [pubspec.yaml](file:///E:/Summer 2026/SafeSky/Mobile App Dev/Mobile_Drone_Control/pubspec.yaml)
- Add `easy_localization: ^3.0.7`
- Add `assets/translations/` to assets.

### State Management
#### [MODIFY] [settings_controller.dart](file:///E:/Summer 2026/SafeSky/Mobile App Dev/Mobile_Drone_Control/lib/state/settings_controller.dart)
- Add `mapTheme` (Light/Dark) property.
- Add language/locale management (or use `easy_localization`'s built-in locale management).

### Theming
#### [MODIFY] [app_theme.dart](file:///E:/Summer 2026/SafeSky/Mobile App Dev/Mobile_Drone_Control/lib/theme/app_theme.dart)
- Refine `buildAppLightTheme` to provide semantic colors (surface, onSurface, etc.) that match the user's requirements (white background for telemetry, top bar, etc.).
- Update `telemetryNumberStyle` and other styles to be theme-aware.

### Localization Assets
#### [NEW] [en.json](file:///E:/Summer 2026/SafeSky/Mobile App Dev/Mobile_Drone_Control/assets/translations/en.json)
#### [NEW] [ur.json](file:///E:/Summer 2026/SafeSky/Mobile App Dev/Mobile_Drone_Control/assets/translations/ur.json)
#### [NEW] [zh.json](file:///E:/Summer 2026/SafeSky/Mobile App Dev/Mobile_Drone_Control/assets/translations/zh.json)
#### [NEW] [es.json](file:///E:/Summer 2026/SafeSky/Mobile App Dev/Mobile_Drone_Control/assets/translations/es.json)

### UI Components (Theme Awareness & Localization)
#### [MODIFY] [main.dart](file:///E:/Summer 2026/SafeSky/Mobile App Dev/Mobile_Drone_Control/lib/main.dart)
- Initialize `EasyLocalization`.
- Wrap `MaterialApp` with `EasyLocalization`.

#### [MODIFY] [top_bar.dart](file:///E:/Summer 2026/SafeSky/Mobile App Dev/Mobile_Drone_Control/lib/widgets/top_bar.dart)
- Use theme colors for background and text.
- Localize labels.

#### [MODIFY] [telemetry_panel.dart](file:///E:/Summer 2026/SafeSky/Mobile App Dev/Mobile_Drone_Control/lib/widgets/telemetry_panel.dart)
- Use theme colors for background and text.
- Localize labels.

#### [MODIFY] [flight_status_panel.dart](file:///E:/Summer 2026/SafeSky/Mobile App Dev/Mobile_Drone_Control/lib/widgets/flight_status_panel.dart)
- Use theme colors for background and text.
- Localize labels.

#### [MODIFY] [virtual_joystick.dart](file:///E:/Summer 2026/SafeSky/Mobile App Dev/Mobile_Drone_Control/lib/widgets/virtual_joystick.dart) & [arrow_joystick.dart](file:///E:/Summer 2026/SafeSky/Mobile App Dev/Mobile_Drone_Control/lib/widgets/arrow_joystick.dart)
- Update colors to be theme-aware.

#### [MODIFY] [settings_screen.dart](file:///E:/Summer 2026/SafeSky/Mobile App Dev/Mobile_Drone_Control/lib/screens/settings_screen.dart)
- Add "Map Theme" toggle.
- Add "Language" selection dropdown/row.
- Localize all text.

#### [MODIFY] [main_flight_screen.dart](file:///E:/Summer 2026/SafeSky/Mobile App Dev/Mobile_Drone_Control/lib/screens/main_flight_screen.dart)
- Ensure the overall background responds to the theme.

## Verification Plan

### Automated Tests
- N/A (UI focused changes).

### Manual Verification
1. Open Settings, toggle Light Mode. Verify Main screen, Telemetry, Top Bar, and Arm Panel turn white.
2. Toggle Map Theme in street view. Verify map changes between light and dark tiles.
3. Change language to Urdu, Chinese, and Spanish. Verify all UI strings update accordingly.
4. Verify orange elements remain orange in both themes.
