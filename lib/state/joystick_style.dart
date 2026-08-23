/// Visual style for the two flight joysticks, picked in Settings — same
/// pattern as MarkerStyle for the map pointer.
enum JoystickStyle { classic, arrows }

extension JoystickStyleLabel on JoystickStyle {
  String get label {
    switch (this) {
      case JoystickStyle.classic:
        return 'Classic';
      case JoystickStyle.arrows:
        return 'Arrows';
    }
  }
}
