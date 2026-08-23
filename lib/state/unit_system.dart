/// Measurement system for displayed telemetry — picked in Settings.
/// Metric shows raw values (already what VehicleState stores); imperial
/// converts on the way to the screen only. Nothing upstream (MAVLink
/// parsing, VehicleState storage) ever changes units — conversion is
/// purely a presentation concern, done here.
enum UnitSystem { metric, imperial }

extension UnitSystemLabel on UnitSystem {
  String get label {
    switch (this) {
      case UnitSystem.metric:
        return 'Metric';
      case UnitSystem.imperial:
        return 'Imperial';
    }
  }
}

extension UnitConversion on UnitSystem {
  String formatSpeed(double metersPerSecond) {
    switch (this) {
      case UnitSystem.metric:
        return '${metersPerSecond.toStringAsFixed(1)} m/s';
      case UnitSystem.imperial:
        return '${(metersPerSecond * 2.23694).toStringAsFixed(1)} mph';
    }
  }

  /// Same as formatSpeed but keeps the sign, for climb/descent rate
  /// where +/- carries meaning (e.g. "+1.2 m/s" vs "-1.2 m/s").
  String formatVerticalSpeed(double metersPerSecond) {
    final sign = metersPerSecond > 0 ? '+' : '';
    switch (this) {
      case UnitSystem.metric:
        return '$sign${metersPerSecond.toStringAsFixed(1)} m/s';
      case UnitSystem.imperial:
        return '$sign${(metersPerSecond * 2.23694).toStringAsFixed(1)} mph';
    }
  }

  String formatDistance(double meters) {
    switch (this) {
      case UnitSystem.metric:
        return '${meters.toStringAsFixed(1)} m';
      case UnitSystem.imperial:
        return '${(meters * 3.28084).toStringAsFixed(0)} ft';
    }
  }
}