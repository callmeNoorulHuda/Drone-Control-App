import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll;
import '../theme/app_theme.dart';

/// Live GPS map: shows the drone's real position on real map tiles, with a
/// heading-rotated marker. Replaces the earlier radar-style placeholder now
/// that VehicleState carries real lat/lon from GLOBAL_POSITION_INT.
///
/// Uses CARTO's free "dark matter" tiles (OSM data, dark-themed) so the map
/// sits naturally in the navy UI instead of a bright default basemap.
///
/// Deferred on purpose (not in this widget yet):
///   - flight path trail (polyline of recent fixes)
///   - waypoint / mission overlay
///   - detailed "why no GPS fix" reasons — this just shows a generic banner
class DroneMapView extends StatefulWidget {
  const DroneMapView({
    super.key,
    required this.latitude,
    required this.longitude,
    required this.headingDegrees,
    required this.connected,
    required this.hasFix,
  });

  final double latitude;
  final double longitude;
  final double headingDegrees;
  final bool connected;
  final bool hasFix;

  @override
  State<DroneMapView> createState() => _DroneMapViewState();
}

class _DroneMapViewState extends State<DroneMapView> {
  final MapController _mapController = MapController();
  bool _followDrone = true;

  ll.LatLng get _point => ll.LatLng(widget.latitude, widget.longitude);

  @override
  void didUpdateWidget(covariant DroneMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final moved =
        oldWidget.latitude != widget.latitude ||
        oldWidget.longitude != widget.longitude;
    if (_followDrone && widget.hasFix && moved) {
      // Keep the drone centered as new fixes arrive, without fighting the
      // user if they've manually panned away (see onPositionChanged below).
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _mapController.move(_point, _mapController.camera.zoom);
      });
    }
  }

  void _recenter() {
    setState(() => _followDrone = true);
    _mapController.move(_point, math.max(_mapController.camera.zoom, 17));
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(
        color: AppColors.surface,
        child: Stack(
          children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _point,
                initialZoom: 17,
                minZoom: 3,
                maxZoom: 19,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                ),
                onPositionChanged: (position, hasGesture) {
                  // A manual pan/pinch breaks auto-follow until the pilot
                  // taps the recenter button again.
                  if (hasGesture && _followDrone) {
                    setState(() => _followDrone = false);
                  }
                },
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
                  subdomains: const ['a', 'b', 'c', 'd'],
                  userAgentPackageName: 'com.safesky.drone_control',
                  maxZoom: 19,
                ),
                if (widget.hasFix)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _point,
                        width: 60,
                        height: 60,
                        child: _HeadingMarker(
                          headingDegrees: widget.headingDegrees,
                          connected: widget.connected,
                        ),
                      ),
                    ],
                  ),
                RichAttributionWidget(
                  alignment: AttributionAlignment.bottomLeft,
                  popupInitialDisplayDuration: const Duration(seconds: 3),
                  attributions: [
                    TextSourceAttribution('OpenStreetMap contributors'),
                    TextSourceAttribution('CARTO'),
                  ],
                ),
              ],
            ),
            if (!widget.hasFix) const _NoFixBanner(),
            // Left-side control column (compass + recenter), mirroring the
            // reference layout's icon stack on the map's left edge.
            Positioned(
              left: 12,
              top: 12,
              child: Column(
                children: [
                  _CompassBadge(
                    headingDegrees: widget.headingDegrees,
                    hasFix: widget.hasFix,
                  ),
                  const SizedBox(height: 8),
                  _RecenterButton(active: _followDrone, onTap: _recenter),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeadingMarker extends StatelessWidget {
  const _HeadingMarker({required this.headingDegrees, required this.connected});
  final double headingDegrees;
  final bool connected;

  @override
  Widget build(BuildContext context) {
    final color = connected ? AppColors.amber : AppColors.textSecondary;
    return AnimatedRotation(
      turns: headingDegrees / 360,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOut,
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: connected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.45),
                    blurRadius: 22,
                    spreadRadius: 2,
                  ),
                ]
              : null,
        ),
        child: Icon(Icons.navigation, color: color, size: 34),
      ),
    );
  }
}

class _CompassBadge extends StatelessWidget {
  const _CompassBadge({required this.headingDegrees, required this.hasFix});
  final double headingDegrees;
  final bool hasFix;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.92),
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.hairline),
        boxShadow: const [
          BoxShadow(
            color: Colors.black38,
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          const Positioned(
            top: 4,
            child: Text(
              'N',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 9,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          AnimatedRotation(
            turns: hasFix ? headingDegrees / 360 : 0,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOut,
            child: Icon(
              Icons.navigation,
              size: 18,
              color: hasFix ? AppColors.amber : AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _NoFixBanner extends StatelessWidget {
  const _NoFixBanner();

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: IgnorePointer(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          color: AppColors.bg.withValues(alpha: 0.85),
          child: const Center(
            child: Text(
              'NO GPS FIX — waiting for satellites',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RecenterButton extends StatelessWidget {
  const _RecenterButton({required this.active, required this.onTap});
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.amber : AppColors.textSecondary;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.92),
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.hairline),
          boxShadow: const [
            BoxShadow(
              color: Colors.black38,
              blurRadius: 10,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Icon(Icons.my_location, size: 20, color: color),
      ),
    );
  }
}
