import 'package:flutter/material.dart';

/// Lets code outside VirtualJoystick move its knob programmatically —
/// e.g. snapping throttle to idle on arm, or recentering on mode change.
///
/// Deliberately NOT wired through Provider — this is a per-widget-instance
/// controller (same category as TextEditingController / ScrollController),
/// not shared app-wide state. It's created directly in MainFlightScreen
/// (_leftController, _rightController) and passed straight into
/// VirtualJoystick's constructor, listened to there via addListener.
class JoystickController extends ChangeNotifier {
  Offset _target = Offset.zero;
  Offset get target => _target;

  void moveTo(Offset offset) {
    _target = offset;
    notifyListeners();
  }

  void center() => moveTo(Offset.zero);
}
