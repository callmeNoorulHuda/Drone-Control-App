import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_tile_switcher/flutter_map_tile_switcher.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:latlong2/latlong.dart' as ll;
import '../state/marker_style.dart';
import '../theme/app_theme.dart';

class DroneMapView extends StatefulWidget {
  const DroneMapView({
    super.key,
    required this.latitude,
    required this.longitude,
    required this.headingDegrees,
    required this.connected,
    required this.hasFix,
    this.isDarkMode = false,
    this.markerStyle = MarkerStyle.drone,
    this.useSatelliteMap = false,
  });

  final double latitude;
  final double longitude;
  final double headingDegrees;
  final bool connected;
  final bool hasFix;
  final bool isDarkMode;
  final MarkerStyle markerStyle;
  final bool useSatelliteMap;

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
        color: widget.isDarkMode ? AppColors.surface : Colors.white,
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
                  if (hasGesture && _followDrone) {
                    setState(() => _followDrone = false);
                  }
                },
              ),
              children: [
                // This one widget replaces your old TileLayer entirely.
                // mapType stays osm (free CartoDB tiles, no API key, safe
                // for Play Store). isDarkMode is passed explicitly instead
                // of relying on auto-detection from Theme.of(context), so
                // it stays in sync with your own app-level toggle.
                MapTileLayer(
                  mapType: widget.useSatelliteMap
                      ? MapTileType.satellite
                      : MapTileType.osm,
                  isDarkMode: widget.isDarkMode,
                  userAgentPackageName: 'com.safesky.drone_control',
                ),
                if (widget.hasFix)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _point,
                        width: 60,
                        height: 60,
                        child: _PositionMarker(
                          headingDegrees: widget.headingDegrees,
                          connected: widget.connected,
                          isDarkMode: widget.isDarkMode,
                          style: widget.markerStyle,
                        ),
                      ),
                    ],
                  ),
                RichAttributionWidget(
                  alignment: AttributionAlignment.bottomLeft,
                  popupInitialDisplayDuration: const Duration(seconds: 3),
                  attributions: const [
                    TextSourceAttribution('OpenStreetMap contributors'),
                    TextSourceAttribution('CARTO'),
                  ],
                ),
              ],
            ),
            if (!widget.hasFix) _NoFixBanner(isDarkMode: widget.isDarkMode),
            Positioned(
              left: 12,
              top: 12,
              child: Column(
                children: [
                  _CompassBadge(
                    headingDegrees: widget.headingDegrees,
                    hasFix: widget.hasFix,
                    isDarkMode: widget.isDarkMode,
                  ),
                  const SizedBox(height: 8),
                  _RecenterButton(
                    active: _followDrone,
                    onTap: _recenter,
                    isDarkMode: widget.isDarkMode,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Marker rendering — now that every MarkerStyle option is SVG-based (the
// built-in "simple" arrow icon option was replaced by a 3rd real SVG, see
// state/marker_style.dart), this no longer needs a per-case switch — it
// just reads whichever asset path the current style maps to.
class _PositionMarker extends StatelessWidget {
  const _PositionMarker({
    required this.headingDegrees,
    required this.connected,
    required this.isDarkMode,
    required this.style,
  });

  final double headingDegrees;
  final bool connected;
  final bool isDarkMode;
  final MarkerStyle style;

  @override
  Widget build(BuildContext context) {
    final color = connected
        ? AppColors.amber
        : (isDarkMode ? AppColors.textSecondary : Colors.black45);

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
        child: SvgPicture.asset(
          style.assetPath,
          width: 32,
          height: 32,
          colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
        ),
      ),
    );
  }
}

class _CompassBadge extends StatelessWidget {
  const _CompassBadge({
    required this.headingDegrees,
    required this.hasFix,
    required this.isDarkMode,
  });

  final double headingDegrees;
  final bool hasFix;
  final bool isDarkMode;

  @override
  Widget build(BuildContext context) {
    final bg = isDarkMode ? AppColors.surface : Colors.white;
    final border = isDarkMode ? AppColors.hairline : Colors.black12;
    final textColor = isDarkMode ? AppColors.textSecondary : Colors.black54;

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: bg.withValues(alpha: 0.92),
        shape: BoxShape.circle,
        border: Border.all(color: border),
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
          Positioned(
            top: 4,
            child: Text(
              'N',
              style: TextStyle(
                color: textColor,
                fontSize: 9,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),

          Positioned(
            top: 15,
            child: AnimatedRotation(
              turns: hasFix ? headingDegrees / 360 : 0,
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOut,
              child: Icon(
                Icons.navigation,
                size: 18,
                color: hasFix ? AppColors.amber : textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NoFixBanner extends StatelessWidget {
  const _NoFixBanner({required this.isDarkMode});
  final bool isDarkMode;

  @override
  Widget build(BuildContext context) {
    final bg = isDarkMode ? AppColors.bg : Colors.white;
    final textColor = isDarkMode ? AppColors.textSecondary : Colors.black54;

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: IgnorePointer(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          color: bg.withValues(alpha: 0.85),
          child: Center(
            child: Text(
              'NO GPS FIX — waiting for satellites',
              style: TextStyle(
                color: textColor,
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
  const _RecenterButton({
    required this.active,
    required this.onTap,
    required this.isDarkMode,
  });

  final bool active;
  final VoidCallback onTap;
  final bool isDarkMode;

  @override
  Widget build(BuildContext context) {
    final inactiveColor = isDarkMode ? AppColors.textSecondary : Colors.black54;
    final color = active ? AppColors.amber : inactiveColor;
    final bg = isDarkMode ? AppColors.surface : Colors.white;
    final border = isDarkMode ? AppColors.hairline : Colors.black12;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: bg.withValues(alpha: 0.92),
          shape: BoxShape.circle,
          border: Border.all(color: border),
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
