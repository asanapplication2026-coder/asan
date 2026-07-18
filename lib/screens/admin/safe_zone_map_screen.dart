import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:get/get.dart';
import 'package:latlong2/latlong.dart';
import '../../controllers/safe_zone_controller.dart';
import '../../models/safe_zone_model.dart';
import '../widgets/glassmorphic_bottom_nav.dart';

/// Single screen for everything safe-zone related:
/// Features an edge-to-edge map with Apple-inspired glassmorphic UI elements.
class SafeZoneMapScreen extends StatefulWidget {
  const SafeZoneMapScreen({super.key});

  @override
  State<SafeZoneMapScreen> createState() => _SafeZoneMapScreenState();
}

class _SafeZoneMapScreenState extends State<SafeZoneMapScreen> {
  static const int _pinCount = 4;
  static const _schoolCenter = LatLng(14.567960, 121.075473);
  static final _campusBounds = LatLngBounds(
    LatLng(_schoolCenter.latitude - 0.003, _schoolCenter.longitude - 0.003),
    LatLng(_schoolCenter.latitude + 0.003, _schoolCenter.longitude + 0.003),
  );

  static const List<Color> _pinColors = [
    Color(0xFFFF3B30), // iOS Red
    primaryRed, // iOS Blue
    Color(0xFFFF9500), // iOS Orange
    Color(0xFFAF52DE), // iOS Purple
  ];

  late final SafeZoneController _controller;
  bool _isDrawing = false;
  final List<LatLng> _pins = [];

  @override
  void initState() {
    super.initState();
    _controller = Get.put(SafeZoneController());
  }

  // ---------------------------------------------------------------------
  // Drawing mode & Math
  // ---------------------------------------------------------------------

  void _startDrawing() {
    setState(() {
      _isDrawing = true;
      _pins.clear();
    });
  }

  void _cancelDrawing() {
    setState(() {
      _isDrawing = false;
      _pins.clear();
    });
  }

  void _undoLastPin() {
    if (_pins.isEmpty) return;
    setState(() => _pins.removeLast());
  }

  void _resetPins() {
    setState(() => _pins.clear());
  }

  bool get _isComplete => _pins.length == _pinCount;

  String get _instructionText {
    if (_pins.isEmpty) return 'Tap the map to place pin 1 of $_pinCount.';
    if (_pins.length < _pinCount) {
      return 'Tap the map to place pin ${_pins.length + 1} of $_pinCount.';
    }
    return 'All $_pinCount pins placed. Ready to save.';
  }

  /// Calculates the visual center of the polygon to place the label marker
  LatLng _calculateCentroid(List<LatLng> points) {
    if (points.isEmpty) return const LatLng(0, 0);
    double latSum = 0;
    double lngSum = 0;
    for (final p in points) {
      latSum += p.latitude;
      lngSum += p.longitude;
    }
    return LatLng(latSum / points.length, lngSum / points.length);
  }

  void _handleMapTap(LatLng point) {
    if (_isDrawing) {
      setState(() {
        if (_pins.length >= _pinCount) {
          _pins
            ..clear()
            ..add(point);
        } else {
          _pins.add(point);
        }
      });
      return;
    }

    for (final zone in _controller.safeZones) {
      if (_pointInPolygon(point, zone.points)) {
        _showZoneDetails(zone);
        return;
      }
    }
  }

  static bool _pointInPolygon(LatLng point, List<LatLng> polygon) {
    var inside = false;
    for (int i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
      final xi = polygon[i].longitude, yi = polygon[i].latitude;
      final xj = polygon[j].longitude, yj = polygon[j].latitude;
      final intersects =
          ((yi > point.latitude) != (yj > point.latitude)) &&
              (point.longitude <
                  (xj - xi) * (point.latitude - yi) / (yj - yi) + xi);
      if (intersects) inside = !inside;
    }
    return inside;
  }

  Future<void> _saveZone() async {
    if (!_isComplete) return;

    final nameController = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Name Safe Zone'),
        content: TextField(
          controller: nameController,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'e.g. Main Quadrangle',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            filled: true,
            fillColor: Colors.grey.shade100,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(nameController.text.trim()),
            child: const Text(
              'Save',
              style: TextStyle(fontWeight: FontWeight.bold, color: primaryRed),
            ),
          ),
        ],
      ),
    );

    if (name == null || name.isEmpty) return;

    final success = await _controller.createSafeZone(
      name: name,
      points: List.of(_pins),
    );

    if (success && mounted) {
      setState(() {
        _isDrawing = false;
        _pins.clear();
      });
    }
  }

  // ---------------------------------------------------------------------
  // Bottom Sheets
  // ---------------------------------------------------------------------

  Widget _buildDragHandle() {
    return Center(
      child: Container(
        margin: const EdgeInsets.only(top: 12, bottom: 8),
        width: 40,
        height: 5,
        decoration: BoxDecoration(
          color: Colors.grey.shade300,
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  void _showZoneDetails(SafeZone zone) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDragHandle(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    zone.name,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${zone.points.length}-pin zone',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 15),
                  ),
                  const SizedBox(height: 24),
                  Obx(() {
                    var current = zone;
                    for (final z in _controller.safeZones) {
                      if (z.id == zone.id) current = z;
                    }
                    return Material(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(16),
                      clipBehavior: Clip.antiAlias,
                      child: SwitchListTile(
                        activeThumbColor: Colors.white,
                        activeTrackColor: const Color(0xFF34C759),
                        title: const Text(
                          'Active Zone',
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                        value: current.isActive,
                        onChanged: (_) => _controller.toggleActive(current),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        backgroundColor: const Color(
                          0xFFFF3B30,
                        ).withValues(alpha: 0.1),
                      ),
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        _confirmDelete(zone);
                      },
                      child: const Text(
                        'Delete Zone',
                        style: TextStyle(
                          color: Color(0xFFFF3B30),
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(SafeZone zone) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Zone?'),
        content: Text(
          'Are you sure you want to permanently remove "${zone.name}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _controller.deleteSafeZone(zone);
            },
            child: const Text(
              'Delete',
              style: TextStyle(
                color: Color(0xFFFF3B30),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openZoneList() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        builder: (context, scrollController) => Column(
          children: [
            _buildDragHandle(),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Safe Zones',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
            ),
            Expanded(
              child: Obx(() {
                if (_controller.safeZones.isEmpty) {
                  return const Center(
                    child: Text(
                      'No safe zones yet.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  );
                }
                return ListView.separated(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  itemCount: _controller.safeZones.length,
                  separatorBuilder: (context, index) =>
                  const Divider(height: 1, indent: 56),
                  itemBuilder: (context, index) {
                    final zone = _controller.safeZones[index];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      leading: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color:
                          (zone.isActive
                              ? const Color(0xFF34C759)
                              : Colors.grey)
                              .withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.shield_rounded,
                          color: zone.isActive
                              ? const Color(0xFF34C759)
                              : Colors.grey,
                        ),
                      ),
                      title: Text(
                        zone.name,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      subtitle: Text(
                        '${zone.points.length}-pin zone',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 13,
                        ),
                      ),
                      trailing: Switch(
                        activeThumbColor: Colors.white,
                        activeTrackColor: const Color(0xFF34C759),
                        value: zone.isActive,
                        onChanged: (_) => _controller.toggleActive(zone),
                      ),
                      onTap: () {
                        Navigator.pop(ctx);
                        _showZoneDetails(zone);
                      },
                    );
                  },
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // 1. Edge-to-edge Map
          Obx(() {
            if (_controller.isLoading.value && _controller.safeZones.isEmpty) {
              return const Center(child: CircularProgressIndicator.adaptive());
            }

            return FlutterMap(
              options: MapOptions(
                initialCenter: _schoolCenter,
                initialZoom: 18,
                minZoom: 16,
                maxZoom: 19,
                cameraConstraint: CameraConstraint.contain(
                  bounds: _campusBounds,
                ),
                onTap: (tapPosition, point) => _handleMapTap(point),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.asan_evac_app',
                ),
                PolygonLayer(
                  polygons: [
                    for (final zone in _controller.safeZones)
                      Polygon(
                        points: zone.points,
                        color:
                        (zone.isActive
                            ? const Color(0xFF34C759)
                            : Colors.grey)
                            .withValues(alpha: 0.2),
                        borderColor: zone.isActive
                            ? const Color(0xFF34C759)
                            : Colors.grey,
                        borderStrokeWidth: 2,
                      ),
                    if (_pins.length >= 3)
                      Polygon(
                        points: _pins,
                        color: primaryRed.withValues(alpha: 0.2),
                        borderColor: primaryRed,
                        borderStrokeWidth: 2,
                      ),
                  ],
                ),

                // Marker Layer for the Zone Names
                if (_controller.safeZones.isNotEmpty)
                  MarkerLayer(
                    markers: [
                      for (final zone in _controller.safeZones)
                        Marker(
                          point: _calculateCentroid(zone.points),
                          width: 140,
                          // Max width for the label box
                          height: 40,
                          alignment: Alignment.center,
                          child: GestureDetector(
                            onTap: () => _showZoneDetails(zone),
                            child: Center(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: BackdropFilter(
                                  filter: ImageFilter.blur(
                                    sigmaX: 8,
                                    sigmaY: 8,
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(
                                        alpha: 0.85,
                                      ),
                                      border: Border.all(
                                        color: Colors.white.withValues(
                                          alpha: 0.5,
                                        ),
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(
                                            alpha: 0.1,
                                          ),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Text(
                                      zone.name,
                                      style: TextStyle(
                                        color: zone.isActive
                                            ? const Color(0xFF15803D)
                                            : Colors.grey.shade800,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12,
                                        letterSpacing: -0.2,
                                      ),
                                      textAlign: TextAlign.center,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),

                if (_isDrawing && _pins.length == 2)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: _pins,
                        color: primaryRed,
                        strokeWidth: 3,
                      ),
                    ],
                  ),
                if (_isDrawing)
                  MarkerLayer(
                    markers: [
                      for (int i = 0; i < _pins.length; i++)
                        Marker(
                          point: _pins[i],
                          width: 40,
                          height: 40,
                          child: Container(
                            decoration: BoxDecoration(
                              color: _pinColors[i % _pinColors.length],
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 3),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.2),
                                  blurRadius: 6,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Text(
                                '${i + 1}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
              ],
            );
          }),

          // 2. Floating Top Header
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 16,
            right: 16,
            child: _buildGlassContainer(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: _isDrawing
                    ? Row(
                  children: [
                    Expanded(
                      child: Text(
                        _instructionText,
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_pins.isNotEmpty)
                          _buildGlassIconButton(
                            Icons.undo_rounded,
                            _undoLastPin,
                          ),
                        if (_pins.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: _buildGlassIconButton(
                              Icons.refresh_rounded,
                              _resetPins,
                            ),
                          ),
                        const SizedBox(width: 8),
                        _buildGlassIconButton(
                          Icons.close_rounded,
                          _cancelDrawing,
                          color: Colors.grey.shade800,
                        ),
                      ],
                    ),
                  ],
                )
                    : Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Safe Zones',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                    // Dynamic Refresh Button / Loading Indicator
                    Obx(() => _controller.isLoading.value
                        ? Container(
                      width: 36,
                      height: 36,
                      padding: const EdgeInsets.all(8),
                      child: const CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Colors.black87,
                        ),
                      ),
                    )
                        : _buildGlassIconButton(
                      Icons.refresh_rounded,
                          () {
                        // TODO: Update this call if your refresh method uses a different name
                        _controller.fetchSafeZones();
                      },
                    ),
                    ),
                    const SizedBox(width: 8),
                    _buildGlassIconButton(
                      Icons.format_list_bulleted_rounded,
                      _openZoneList,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),

      // 3. Floating Bottom Action Button
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 100.0),
        child: _isDrawing
            ? AnimatedOpacity(
          opacity: _isComplete ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 200),
          child: _isComplete
              ? Obx(
                () => FloatingActionButton.extended(
              backgroundColor: primaryRed,
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
              icon: _controller.isSaving.value
                  ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
                  : const Icon(
                Icons.check_rounded,
                color: Colors.white,
              ),
              label: const Text(
                'Save Zone',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              onPressed:
              _controller.isSaving.value ? null : _saveZone,
            ),
          )
              : const SizedBox.shrink(),
        )
            : FloatingActionButton.extended(
          backgroundColor: Colors.white,
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          icon: const Icon(
            Icons.add_location_alt_rounded,
            color: primaryRed,
          ),
          label: const Text(
            'New Safe Zone',
            style: TextStyle(
              color: primaryRed,
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
          onPressed: _startDrawing,
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Reusable UI Components
  // ---------------------------------------------------------------------

  Widget _buildGlassContainer({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.75),
            border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildGlassIconButton(
      IconData icon,
      VoidCallback onTap, {
        Color? color,
      }) {
    return Material(
      color: Colors.black.withValues(alpha: 0.05),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Icon(icon, size: 20, color: color ?? Colors.black87),
        ),
      ),
    );
  }
}