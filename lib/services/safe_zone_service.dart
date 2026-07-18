import 'package:asan_evac_app/services/supabase_client.dart';
import 'package:latlong2/latlong.dart';
import '../models/safe_zone_model.dart';

class SafeZoneService {
  Future<List<SafeZone>> fetchSafeZones() async {
    final data = await supabase
        .from('safe_zones')
        .select()
        .order('created_at', ascending: true);

    return (data as List)
        .map((row) => SafeZone.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  /// [points] is the ordered list of vertices tapped on the map (3+ points).
  /// The bounding box (min/max lat/lng) is derived automatically and stored
  /// alongside — it's used server-side purely as a fast pre-filter before
  /// the exact point-in-polygon check.
  Future<SafeZone> createSafeZone({
    required String name,
    required List<LatLng> points,
  }) async {
    if (points.length < 3) {
      throw Exception('A safe zone needs at least 3 points.');
    }

    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('No authenticated user — cannot create safe zone.');
    }

    final lats = points.map((p) => p.latitude);
    final lngs = points.map((p) => p.longitude);

    final data = await supabase
        .from('safe_zones')
        .insert({
      'name': name,
      'points':
      points.map((p) => {'lat': p.latitude, 'lng': p.longitude}).toList(),
      'min_lat': lats.reduce((a, b) => a < b ? a : b),
      'max_lat': lats.reduce((a, b) => a > b ? a : b),
      'min_lng': lngs.reduce((a, b) => a < b ? a : b),
      'max_lng': lngs.reduce((a, b) => a > b ? a : b),
      'created_by': userId,
    })
        .select()
        .single();

    return SafeZone.fromJson(data);
  }

  Future<void> setActive(String zoneId, bool isActive) async {
    await supabase
        .from('safe_zones')
        .update({'is_active': isActive})
        .eq('id', zoneId);
  }

  Future<void> deleteSafeZone(String zoneId) async {
    await supabase.from('safe_zones').delete().eq('id', zoneId);
  }

  /// Calls the `check_point_in_safe_zone` RPC to see whether a point falls
  /// inside any active safe zone, and which one.
  Future<SafeZoneCheckResult> checkPointInSafeZone({
    required double lat,
    required double lng,
  }) async {
    final data = await supabase.rpc(
      'check_point_in_safe_zone',
      params: {'p_lat': lat, 'p_lng': lng},
    );

    final rows = data as List;
    if (rows.isEmpty) {
      return SafeZoneCheckResult(isInside: false);
    }
    return SafeZoneCheckResult.fromJson(rows.first as Map<String, dynamic>);
  }
}