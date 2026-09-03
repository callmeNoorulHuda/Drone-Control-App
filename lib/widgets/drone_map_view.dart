import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:easy_localization/easy_localization.dart';
import '../config/map_keys.dart';
import '../state/marker_style.dart';
import '../theme/app_theme.dart';
import '../models/mission_waypoint.dart';

class DroneMapView extends StatefulWidget {
  const DroneMapView({
    super.key,
    required this.latitude,
    required this.longitude,
    required this.headingDegrees,
    required this.connected,
    required this.hasFix,
    this.isDarkMode = false,
    this.isMapDark = true,
    this.markerStyle = MarkerStyle.drone,
    this.useSatelliteMap = false,
    this.onMapTap,
    this.waypoints = const [],
    this.homeLat,
    this.homeLon,
    this.currentWaypointIndex,
    this.wifiRangeMeters = 500.0,
    this.showSearch = true,
  });

  final double latitude;
  final double longitude;
  final double headingDegrees;
  final bool connected;
  final bool hasFix;
  final bool isDarkMode;
  final bool isMapDark;
  final MarkerStyle markerStyle;
  final bool useSatelliteMap;
  final Function(ll.LatLng)? onMapTap;
  final List<MissionWaypoint> waypoints;
  final double? homeLat;
  final double? homeLon;
  final int? currentWaypointIndex;
  final double wifiRangeMeters;
  final bool showSearch;

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
                onTap: (tapPosition, point) {
                  widget.onMapTap?.call(point);
                },
              ),
              children: [
                widget.useSatelliteMap
                    ? TileLayer(
                        urlTemplate:
                            'https://server.arcgisonline.com/ArcGIS/rest/services/'
                            'World_Imagery/MapServer/tile/{z}/{y}/{x}',
                        userAgentPackageName: 'com.safesky.drone_control',
                        maxNativeZoom: 19,
                      )
                    : MapKeys.hasCartoKey
                    ? TileLayer(
                        urlTemplate:
                            'https://basemaps.cartocdn.com/rastertiles/'
                            '${widget.isMapDark ? "dark_all" : "light_all"}'
                            '/{z}/{x}/{y}.png?key={key}',
                        additionalOptions: {'key': MapKeys.cartoApiKey},
                        userAgentPackageName: 'com.safesky.drone_control',
                        maxNativeZoom: 19,
                      )
                    : TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.safesky.drone_control',
                        maxNativeZoom: 19,
                      ),
                if (widget.waypoints.length > 1)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: widget.waypoints
                            .map((w) => w.toLatLng)
                            .toList(),
                        color: AppColors.amber.withValues(alpha: 0.7),
                        strokeWidth: 3.0,
                      ),
                    ],
                  ),
                MarkerLayer(
                  markers: [
                    if (widget.homeLat != null && widget.homeLon != null)
                      Marker(
                        point: ll.LatLng(widget.homeLat!, widget.homeLon!),
                        width: 40,
                        height: 40,
                        child: _HomeMarker(isDarkMode: widget.isDarkMode),
                      ),
                    ...widget.waypoints.asMap().entries.map((entry) {
                      final i = entry.key;
                      final wp = entry.value;
                      final isActive = widget.currentWaypointIndex == i;
                      final isDone =
                          widget.currentWaypointIndex != null &&
                          i < widget.currentWaypointIndex!;

                      final dist = ll.Distance().as(
                        ll.LengthUnit.Meter,
                        _point,
                        wp.toLatLng,
                      );
                      final tooFar = dist > widget.wifiRangeMeters;

                      return Marker(
                        point: wp.toLatLng,
                        width: 45,
                        height: 45,
                        child: _WaypointMarker(
                          index: i + 1,
                          isActive: isActive,
                          isDone: isDone,
                          tooFar: tooFar,
                        ),
                      );
                    }),
                    if (widget.hasFix)
                      Marker(
                        point: _point,
                        width: 120,
                        height: 120,
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
                  attributions: [
                    if (widget.useSatelliteMap)
                      const TextSourceAttribution(
                        'Esri, Maxar, Earthstar Geographics',
                      )
                    else if (MapKeys.hasCartoKey)
                      const TextSourceAttribution(
                        'CARTO, OpenStreetMap contributors',
                      )
                    else
                      const TextSourceAttribution('OpenStreetMap contributors'),
                  ],
                ),
              ],
            ),
            if (!widget.hasFix) _NoFixBanner(isDarkMode: widget.isDarkMode),
            if (widget.showSearch)
              Positioned(
                left: 12,
                top: 12,
                right: 60,
                child: _SearchBar(
                  onSearch: (point) {
                    setState(() => _followDrone = false);
                    _mapController.move(point, 17);
                  },
                  isDarkMode: widget.isDarkMode,
                ),
              ),
            Positioned(
              left: 12,
              top: widget.showSearch ? 60 : 12,
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
                    blurRadius: 28,
                    spreadRadius: 4,
                  ),
                ]
              : null,
        ),
        child: SvgPicture.asset(
          style.assetPath,
          width: 60,
          height: 60,
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
              'no_gps_fix_waiting'.tr().toUpperCase(),
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

class _HomeMarker extends StatelessWidget {
  const _HomeMarker({required this.isDarkMode});
  final bool isDarkMode;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.2),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.blue, width: 2),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: const Icon(Icons.home, color: Colors.blue, size: 20),
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

class _WaypointMarker extends StatelessWidget {
  const _WaypointMarker({
    required this.index,
    required this.isActive,
    required this.isDone,
    required this.tooFar,
  });

  final int index;
  final bool isActive;
  final bool isDone;
  final bool tooFar;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        if (isActive) const _PulseRing(color: AppColors.amber),
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: isDone
                ? Colors.grey
                : (tooFar ? AppColors.danger : AppColors.amber),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
          ),
          child: Center(
            child: Text(
              '$index',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ),
        if (isDone)
          const Positioned(
            right: 0,
            bottom: 0,
            child: Icon(Icons.check_circle, color: Colors.green, size: 16),
          ),
        if (tooFar)
          const Positioned(
            left: 0,
            top: 0,
            child: Icon(Icons.warning, color: Colors.white, size: 14),
          ),
      ],
    );
  }
}

class _PulseRing extends StatefulWidget {
  const _PulseRing({required this.color});
  final Color color;

  @override
  State<_PulseRing> createState() => _PulseRingState();
}

class _PulseRingState extends State<_PulseRing>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: 30 + (20 * _controller.value),
          height: 30 + (20 * _controller.value),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: widget.color.withValues(alpha: 1 - _controller.value),
              width: 2,
            ),
          ),
        );
      },
    );
  }
}

class _SearchBar extends StatefulWidget {
  const _SearchBar({required this.onSearch, required this.isDarkMode});
  final Function(ll.LatLng) onSearch;
  final bool isDarkMode;

  @override
  State<_SearchBar> createState() => _SearchBarState();
}

class _SearchBarState extends State<_SearchBar> {
  final TextEditingController _controller = TextEditingController();

  void _handleSearch() {
    final text = _controller.text;
    if (text.isEmpty) return;

    final parts = text.split(',');
    if (parts.length == 2) {
      final lat = double.tryParse(parts[0].trim());
      final lon = double.tryParse(parts[1].trim());
      if (lat != null && lon != null) {
        widget.onSearch(ll.LatLng(lat, lon));
        return;
      }
    }

    final mocks = {
      'islamabad': ll.LatLng(33.6844, 73.0479),
      'london': ll.LatLng(51.5074, -0.1278),
      'new york': ll.LatLng(40.7128, -74.0060),
    };

    final mock = mocks[text.toLowerCase().trim()];
    if (mock != null) {
      widget.onSearch(mock);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bg = widget.isDarkMode ? AppColors.surface : Colors.white;
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: bg.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: widget.isDarkMode ? AppColors.hairline : Colors.black12,
        ),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: TextField(
        controller: _controller,
        onSubmitted: (_) => _handleSearch(),
        decoration: InputDecoration(
          hintText: 'search_hint'.tr(),
          hintStyle: const TextStyle(fontSize: 12),
          prefixIcon: const Icon(Icons.search, size: 20),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
        ),
        style: const TextStyle(fontSize: 14),
      ),
    );
  }
}
