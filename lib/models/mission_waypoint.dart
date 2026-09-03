import 'package:latlong2/latlong.dart';

class MissionWaypoint {
  MissionWaypoint({
    required this.lat,
    required this.lon,
    this.alt = 30.0,
    required this.seq,
  });

  final double lat;
  final double lon;
  double alt;
  final int seq;

  LatLng get toLatLng => LatLng(lat, lon);

  MissionWaypoint copyWith({double? lat, double? lon, double? alt, int? seq}) {
    return MissionWaypoint(
      lat: lat ?? this.lat,
      lon: lon ?? this.lon,
      alt: alt ?? this.alt,
      seq: seq ?? this.seq,
    );
  }
}
