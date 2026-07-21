import 'package:latlong2/latlong.dart';

/// Canonical safe-zone model — used by both the admin zone-management
/// screens and the teacher-side headcount location gate.
///
/// `points` is stored in Postgres as jsonb: `[{"lat": ..., "lng": ...}, ...]`.
class SafeZone {
  final String id;
  final String name;
  final List<LatLng> points;
  final double minLat;
  final double minLng;
  final double maxLat;
  final double maxLng;
  final bool isActive;
  final String createdBy;
  final DateTime createdAt;

  SafeZone({
    required this.id,
    required this.name,
    required this.points,
    required this.minLat,
    required this.minLng,
    required this.maxLat,
    required this.maxLng,
    required this.isActive,
    required this.createdBy,
    required this.createdAt,
  });

  factory SafeZone.fromJson(Map<String, dynamic> json) {
    final rawPoints = json['points'] as List<dynamic>? ?? const [];
    return SafeZone(
      id: json['id'] as String,
      name: json['name'] as String,
      points: rawPoints
          .map((p) => LatLng(
        ((p as Map<String, dynamic>)['lat'] as num).toDouble(),
        (p['lng'] as num).toDouble(),
      ))
          .toList(),
      minLat: (json['min_lat'] as num).toDouble(),
      minLng: (json['min_lng'] as num).toDouble(),
      maxLat: (json['max_lat'] as num).toDouble(),
      maxLng: (json['max_lng'] as num).toDouble(),
      isActive: json['is_active'] as bool? ?? true,
      createdBy: json['created_by'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'points': points.map((p) => {'lat': p.latitude, 'lng': p.longitude}).toList(),
    'min_lat': minLat,
    'min_lng': minLng,
    'max_lat': maxLat,
    'max_lng': maxLng,
    'is_active': isActive,
    'created_by': createdBy,
    'created_at': createdAt.toIso8601String(),
  };

  SafeZone copyWith({
    String? id,
    String? name,
    List<LatLng>? points,
    double? minLat,
    double? minLng,
    double? maxLat,
    double? maxLng,
    bool? isActive,
    String? createdBy,
    DateTime? createdAt,
  }) {
    return SafeZone(
      id: id ?? this.id,
      name: name ?? this.name,
      points: points ?? this.points,
      minLat: minLat ?? this.minLat,
      minLng: minLng ?? this.minLng,
      maxLat: maxLat ?? this.maxLat,
      maxLng: maxLng ?? this.maxLng,
      isActive: isActive ?? this.isActive,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

/// Result of the `check_point_in_safe_zone` RPC.
///
/// ⚠️ UNVERIFIED — I have never seen this RPC's actual return columns.
/// `fromJson` guesses at common names (`zone_id`/`id`, `zone_name`/`name`).
/// If the "check a point" test screen shows a wrong zone name, run
/// `select pg_get_functiondef('check_point_in_safe_zone'::regproc);`
/// and adjust the field names below to match.
class SafeZoneCheckResult {
  final bool isInside;
  final String? zoneId;
  final String? zoneName;

  SafeZoneCheckResult({required this.isInside, this.zoneId, this.zoneName});

  factory SafeZoneCheckResult.fromJson(Map<String, dynamic> json) {
    return SafeZoneCheckResult(
      // fromJson is only ever called when the RPC returned a row at
      // all (see SafeZoneService.checkPointInSafeZone), so a matched
      // row implies "inside" unless the RPC itself says otherwise.
      isInside: json['is_inside'] as bool? ?? true,
      zoneId: json['zone_id'] as String? ?? json['id'] as String?,
      zoneName: json['zone_name'] as String? ?? json['name'] as String?,
    );
  }
}