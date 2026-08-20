import 'package:flutter/material.dart';

/// Lets code outside VirtualJoystick move its knob programmatically —
/// e.g. snapping throttle to idle on arm, or recentering on mode change.
class JoystickController extends ChangeNotifier {
  Offset _target = Offset.zero;
  Offset get target => _target;

  void moveTo(Offset offset) {
    _target = offset;
    notifyListeners();
  }

  void center() => moveTo(Offset.zero);
}
