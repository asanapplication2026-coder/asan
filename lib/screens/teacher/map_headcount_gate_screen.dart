import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:asan_evac_app/controllers/teacher/map_headcounter_gate_controller.dart';
import 'package:asan_evac_app/screens/teacher/head_count_screen.dart';
import 'package:latlong2/latlong.dart';

const _primaryRed = Color(0xFF7B1113);
const _iosBlue = Color(0xFF007AFF);

/// Live map gate shown after a teacher claims a section, before
/// headcount opens. Features an iOS-style interface, smooth walking
/// interpolation, a pulsing directional arrow, and a line distance indicator.
class MapHeadcountGateScreen extends StatefulWidget {
  const MapHeadcountGateScreen({
    super.key,
    required this.drillEventId,
    required this.sectionId,
    required this.sectionLabel,
  });

  final String drillEventId;
  final String sectionId;
  final String sectionLabel;

  static const _userAgentPackageName = 'com.yourschool.drillapp';

  @override
  State<MapHeadcountGateScreen> createState() => _MapHeadcountGateScreenState();
}

class _MapHeadcountGateScreenState extends State<MapHeadcountGateScreen> with TickerProviderStateMixin {
  late final controller = Get.put(
    MapHeadcountGateController(),
    tag: '${widget.drillEventId}-${widget.sectionId}-mapgate',
  );

  final _mapController = MapController();
  bool _didInitialFit = false;

  // Animation variables for smooth "walking" movement
  late final AnimationController _moveController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );
  LatLng? _currentLocation;
  double _currentHeading = 0.0;
  LatLng? _animStart;
  LatLng? _animEnd;
  Worker? _positionWorker;

  @override
  void initState() {
    super.initState();

    // Rebuild the map with the interpolated location during movement
    _moveController.addListener(() {
      if (_animStart != null && _animEnd != null) {
        setState(() {
          _currentLocation = _lerp(_animStart!, _animEnd!, _moveController.value);
        });
      }
    });

    // Initialize with existing position if already fetched by the controller[cite: 2]
    final initialPos = controller.currentPosition.value;
    if (initialPos != null) {
      _currentLocation = LatLng(initialPos.latitude, initialPos.longitude);
      _currentHeading = initialPos.heading;
    }

    // Watch for position updates to trigger the smooth walking animation
    _positionWorker = ever(controller.currentPosition, (Position? pos) {
      if (pos == null) return;
      final newLoc = LatLng(pos.latitude, pos.longitude);

      setState(() {
        _currentHeading = pos.heading;
      });

      if (_currentLocation == null) {
        setState(() => _currentLocation = newLoc);
      } else {
        _animStart = _currentLocation;
        _animEnd = newLoc;
        _moveController.forward(from: 0);
      }
    });
  }

  @override
  void dispose() {
    _positionWorker?.dispose();
    _moveController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  void _fitBounds(LatLng a, LatLng b) {
    final bounds = LatLngBounds.fromPoints([a, b]);
    _mapController.fitCamera(
      CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.fromLTRB(48, 120, 48, 220)),
    );
  }

  LatLng _centroid(List<LatLng> points) {
    if (points.isEmpty) return const LatLng(0, 0);
    var sumLat = 0.0, sumLng = 0.0;
    for (final p in points) {
      sumLat += p.latitude;
      sumLng += p.longitude;
    }
    return LatLng(sumLat / points.length, sumLng / points.length);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: Colors.white.withValues(alpha: 0.85),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(color: Colors.transparent),
          ),
        ),
        iconTheme: const IconThemeData(color: _primaryRed),
        title: Text(
          widget.sectionLabel,
          style: const TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w600,
            fontSize: 17,
            letterSpacing: -0.4,
          ),
        ),
      ),
      body: Obx(() {
        if (controller.status.value == MapGateStatus.loading) {
          return const Center(child: CupertinoActivityIndicator(radius: 16));
        }

        if (controller.status.value == MapGateStatus.locationError) {
          return _LocationErrorState(
            message: controller.errorMessage.value ?? 'Could not determine your location.',
            onRetry: controller.retry,
          );
        }

        final currentLatLng = _currentLocation;
        if (currentLatLng == null) {
          return const Center(child: CupertinoActivityIndicator(radius: 16));
        }

        final zone = controller.targetZone.value;
        final zoneCenter = zone == null ? null : _centroid(zone.points);
        final inside = controller.isInsideZone.value;

        if (!_didInitialFit && zoneCenter != null) {
          _didInitialFit = true;
          WidgetsBinding.instance.addPostFrameCallback((_) => _fitBounds(currentLatLng, zoneCenter));
        }

        return Stack(
          children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(initialCenter: currentLatLng, initialZoom: 17),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: MapHeadcountGateScreen._userAgentPackageName,
                ),
                if (zone != null)
                  PolygonLayer(
                    polygons: [
                      Polygon(
                        points: zone.points,
                        color: (inside ? CupertinoColors.activeGreen : _primaryRed).withValues(alpha: 0.15),
                        borderColor: inside ? CupertinoColors.activeGreen : _primaryRed,
                        borderStrokeWidth: 2,
                      ),
                    ],
                  ),
                if (zoneCenter != null && !inside)
                  PolylineLayer(polylines: _dashedSegments(currentLatLng, zoneCenter)),
                MarkerLayer(
                  markers: [
                    if (zoneCenter != null)
                      Marker(
                        point: zoneCenter,
                        width: 40,
                        height: 40,
                        child: Icon(
                          CupertinoIcons.flag_fill,
                          color: inside ? CupertinoColors.activeGreen : _primaryRed,
                          size: 32,
                        ),
                      ),
                    // Distance indicator badge on the dotted line
                    if (zoneCenter != null && !inside)
                      Marker(
                        point: _lerp(currentLatLng, zoneCenter, 0.5),
                        width: 70,
                        height: 30,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.9),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: _primaryRed, width: 1.5),
                              boxShadow: [
                                BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4, offset: const Offset(0, 2))
                              ]
                          ),
                          child: Center(
                            child: Text(
                              '${controller.distanceMeters.value ?? 0}m',
                              style: const TextStyle(color: _primaryRed, fontWeight: FontWeight.w700, fontSize: 12),
                            ),
                          ),
                        ),
                      ),
                    Marker(
                      point: currentLatLng,
                      width: 60,
                      height: 60,
                      child: _PulsingArrowMarker(heading: _currentHeading),
                    ),
                  ],
                ),
              ],
            ),
            Positioned(
              top: MediaQuery.of(context).padding.top + kToolbarHeight + 16,
              left: 16,
              right: 16,
              child: _DistanceBanner(controller: controller),
            ),
            Positioned(
              right: 16,
              bottom: 120,
              child: _FrostedGlassButton(
                icon: CupertinoIcons.location_fill,
                color: _iosBlue,
                onPressed: () {
                  if (zoneCenter != null) {
                    _fitBounds(currentLatLng, zoneCenter);
                  } else {
                    _mapController.move(currentLatLng, 17);
                  }
                },
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _BottomBar(
                inside: inside,
                onStart: () => Get.off(() => HeadcountScreen(
                  drillEventId: widget.drillEventId,
                  sectionId: widget.sectionId,
                  sectionLabel: widget.sectionLabel,
                )),
              ),
            ),
          ],
        );
      }),
    );
  }
}

List<Polyline> _dashedSegments(LatLng start, LatLng end, {int segmentCount = 16}) {
  final segments = <Polyline>[];
  for (var i = 0; i < segmentCount; i += 2) {
    final t0 = i / segmentCount;
    final t1 = (i + 1) / segmentCount;
    segments.add(Polyline(
      points: [_lerp(start, end, t0), _lerp(start, end, t1)],
      strokeWidth: 3,
      color: _primaryRed,
    ));
  }
  return segments;
}

LatLng _lerp(LatLng a, LatLng b, double t) {
  return LatLng(
    a.latitude + (b.latitude - a.latitude) * t,
    a.longitude + (b.longitude - a.longitude) * t,
  );
}

/// A custom widget that combines the user's heading rotation with an outer pulsing ring animation.
class _PulsingArrowMarker extends StatefulWidget {
  const _PulsingArrowMarker({required this.heading});
  final double heading;

  @override
  State<_PulsingArrowMarker> createState() => _PulsingArrowMarkerState();
}

class _PulsingArrowMarkerState extends State<_PulsingArrowMarker> with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  )..repeat();

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedRotation(
      turns: widget.heading / 360,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Expanding and fading pulse ring
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              return Transform.scale(
                scale: 1.0 + (_pulseController.value * 1.5),
                child: Opacity(
                  opacity: 1.0 - _pulseController.value,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _iosBlue.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              );
            },
          ),
          // Solid Arrow Base
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: _iosBlue.withValues(alpha: 0.3),
                  blurRadius: 8,
                  spreadRadius: 2,
                )
              ],
            ),
            child: const Center(
              child: Icon(
                CupertinoIcons.location_north_fill,
                color: _iosBlue,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DistanceBanner extends StatelessWidget {
  const _DistanceBanner({required this.controller});

  final MapHeadcountGateController controller;

  @override
  Widget build(BuildContext context) {
    final inside = controller.isInsideZone.value;
    final noZones = controller.noZonesConfigured.value;
    final zone = controller.targetZone.value;
    final distance = controller.distanceMeters.value;

    late final String text;
    late final Color color;
    late final IconData icon;

    if (noZones) {
      text = 'No safe zones — proceeding without location check';
      color = CupertinoColors.systemYellow.darkColor;
      icon = CupertinoIcons.exclamationmark_triangle_fill;
    } else if (inside) {
      text = zone == null ? "You're in the safe zone" : "You're in ${zone.name}";
      color = CupertinoColors.activeGreen;
      icon = CupertinoIcons.checkmark_alt_circle_fill;
    } else if (zone != null && distance != null) {
      text = '${distance}m to ${zone.name}';
      color = _primaryRed;
      icon = CupertinoIcons.location_solid;
    } else {
      text = 'Locating nearest safe zone…';
      color = CupertinoColors.systemGrey;
      icon = CupertinoIcons.hourglass;
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          color: Colors.white.withValues(alpha: 0.85),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(fontWeight: FontWeight.w600, color: color, fontSize: 15, letterSpacing: -0.2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FrostedGlassButton extends StatelessWidget {
  const _FrostedGlassButton({required this.icon, required this.color, required this.onPressed});

  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: 48,
          height: 48,
          color: Colors.white.withValues(alpha: 0.85),
          child: IconButton(
            icon: Icon(icon, color: color),
            onPressed: onPressed,
          ),
        ),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.inside, required this.onStart});

  final bool inside;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).padding.bottom + 16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.85),
            border: Border(top: BorderSide(color: Colors.black.withValues(alpha: 0.1), width: 0.5)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!inside)
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Text(
                    'Walk to the highlighted area to enable headcount',
                    style: TextStyle(fontSize: 13, color: CupertinoColors.systemGrey, letterSpacing: -0.1),
                    textAlign: TextAlign.center,
                  ),
                ),
              SizedBox(
                width: double.infinity,
                child: CupertinoButton(
                  color: CupertinoColors.activeGreen,
                  disabledColor: CupertinoColors.systemGrey5,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  borderRadius: BorderRadius.circular(12),
                  onPressed: inside ? onStart : null,
                  child: Text(
                    'Start Headcount',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 17,
                      color: inside ? Colors.white : CupertinoColors.systemGrey,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LocationErrorState extends StatelessWidget {
  const _LocationErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(CupertinoIcons.location_slash_fill, size: 56, color: CupertinoColors.systemOrange),
            const SizedBox(height: 20),
            const Text('Location Unavailable', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, letterSpacing: -0.5)),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(color: CupertinoColors.systemGrey)),
            const SizedBox(height: 32),
            CupertinoButton.filled(
              onPressed: onRetry,
              child: const Text('Try Again', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
            const SizedBox(height: 16),
            CupertinoButton(onPressed: () => Geolocator.openAppSettings(), child: const Text('Open App Settings')),
            CupertinoButton(onPressed: () => Geolocator.openLocationSettings(), child: const Text('Open Location Settings')),
          ],
        ),
      ),
    );
  }
}