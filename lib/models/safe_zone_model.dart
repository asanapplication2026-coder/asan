import 'package:latlong2/latlong.dart';

class SafeZone {
  final String id;
  final String name;

  /// Ordered polygon vertices as tapped on the map (in practice, 4 pins —
  /// but this supports any polygon with 3+ vertices). Not necessarily an
  /// axis-aligned rectangle; can be tilted or irregular.
  final List<LatLng> points;
  final bool isActive;
  final String createdBy;
  final DateTime createdAt;

  SafeZone({
    required this.id,
    required this.name,
    required this.points,
    required this.isActive,
    required this.createdBy,
    required this.createdAt,
  });

  factory SafeZone.fromJson(Map<String, dynamic> json) {
    final rawPoints = json['points'] as List;
    return SafeZone(
      id: json['id'] as String,
      name: json['name'] as String,
      points: rawPoints
          .map((p) => LatLng(
        (p['lat'] as num).toDouble(),
        (p['lng'] as num).toDouble(),
      ))
          .toList(),
      isActive: json['is_active'] as bool,
      createdBy: json['created_by'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  /// Points as jsonb for insert/update payloads.
  List<Map<String, double>> get pointsJson =>
      points.map((p) => {'lat': p.latitude, 'lng': p.longitude}).toList();

  /// Bounding box of the polygon — used as a fast pre-filter server-side,
  /// and handy client-side for map fitting.
  double get minLat => points.map((p) => p.latitude).reduce((a, b) => a < b ? a : b);
  double get maxLat => points.map((p) => p.latitude).reduce((a, b) => a > b ? a : b);
  double get minLng => points.map((p) => p.longitude).reduce((a, b) => a < b ? a : b);
  double get maxLng => points.map((p) => p.longitude).reduce((a, b) => a > b ? a : b);

  LatLng get center => LatLng(
    (minLat + maxLat) / 2,
    (minLng + maxLng) / 2,
  );

  SafeZone copyWith({bool? isActive}) {
    return SafeZone(
      id: id,
      name: name,
      points: points,
      isActive: isActive ?? this.isActive,
      createdBy: createdBy,
      createdAt: createdAt,
    );
  }
}

/// Result of the `check_point_in_safe_zone` RPC.
class SafeZoneCheckResult {
  final bool isInside;
  final String? zoneId;
  final String? zoneName;

  SafeZoneCheckResult({
    required this.isInside,
    this.zoneId,
    this.zoneName,
  });

  factory SafeZoneCheckResult.fromJson(Map<String, dynamic> json) {
    return SafeZoneCheckResult(
      isInside: json['is_inside'] as bool,
      zoneId: json['zone_id'] as String?,
      zoneName: json['zone_name'] as String?,
    );
  }
}