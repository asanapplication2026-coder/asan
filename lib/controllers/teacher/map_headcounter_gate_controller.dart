import 'dart:async';
import 'package:asan_evac_app/models/safe_zone_model.dart';
import 'package:asan_evac_app/services/location_service.dart';
import 'package:asan_evac_app/services/safe_zone_service.dart';
import 'package:get/get.dart';
import 'package:geolocator/geolocator.dart' hide LocationServiceDisabledException;
import 'package:latlong2/latlong.dart';
enum MapGateStatus { loading, tracking, locationError }

/// Live version of the safe-zone check — keeps a position stream open
/// so the map, distance, and polyline all update continuously as the
/// teacher walks toward a safe zone.
///
/// Talks to SafeZoneService (the same one the admin safe-zone screen
/// uses) instead of duplicating zone-fetching logic, and does its own
/// point-in-polygon test locally using the exact same ray-casting
/// algorithm as SafeZoneMapScreen._pointInPolygon, rather than assuming
/// SafeZone has a contains()/centroid method — didn't want to guess at
/// your model's API beyond what's directly evidenced elsewhere in your
/// code (points as List[LatLng], id, name, isActive).
///
/// ⚠️ Same fail-open default as before: zero active safe zones lets the
/// teacher through with a warning rather than blocking headcount
/// entirely. Flip `_allowThroughWhenNoZonesConfigured` to change that.
class MapHeadcountGateController extends GetxController {
  static const bool _allowThroughWhenNoZonesConfigured = true;

  final _safeZoneService = SafeZoneService();
  final _locationService = LocationService();
  StreamSubscription<Position>? _positionSub;

  final Rx<MapGateStatus> status = MapGateStatus.loading.obs;
  final RxnString errorMessage = RxnString();
  final RxList<SafeZone> zones = <SafeZone>[].obs;
  final Rxn<Position> currentPosition = Rxn<Position>();
  final Rxn<SafeZone> targetZone = Rxn<SafeZone>();
  final RxnInt distanceMeters = RxnInt();
  final RxBool isInsideZone = false.obs;
  final RxBool noZonesConfigured = false.obs;

  @override
  void onInit() {
    super.onInit();
    _start();
  }

  Future<void> _start() async {
    status.value = MapGateStatus.loading;
    errorMessage.value = null;
    noZonesConfigured.value = false;
    isInsideZone.value = false;

    try {
      // SafeZoneService.fetchSafeZones() returns every zone (the admin
      // screen needs inactive ones too, to re-enable them) — filter to
      // active-only here for gating purposes.
      final fetched = (await _safeZoneService.fetchSafeZones()).where((z) => z.isActive).toList();
      zones.assignAll(fetched);

      if (fetched.isEmpty) {
        noZonesConfigured.value = true;
        if (_allowThroughWhenNoZonesConfigured) {
          isInsideZone.value = true;
        }
      }

      // Get one position up front so typed permission/service errors
      // surface before committing to a long-lived stream subscription.
      final first = await _locationService.getCurrentPosition();
      _handlePosition(first);

      await _positionSub?.cancel();
      _positionSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 3),
      ).listen(
        _handlePosition,
        onError: (e) {
          status.value = MapGateStatus.locationError;
          errorMessage.value = 'Lost location updates: $e';
        },
      );

      status.value = MapGateStatus.tracking;
    } on LocationServiceDisabledException {
      status.value = MapGateStatus.locationError;
      errorMessage.value = 'Turn on location services to continue.';
    } on LocationPermissionDeniedException catch (e) {
      status.value = MapGateStatus.locationError;
      errorMessage.value = e.isPermanent
          ? 'Location permission is permanently denied. Enable it for this app in system settings.'
          : 'Location permission is required to start headcount.';
    } catch (e) {
      status.value = MapGateStatus.locationError;
      errorMessage.value = 'Could not get your location: $e';
    }
  }

  void _handlePosition(Position position) {
    currentPosition.value = position;
    if (zones.isEmpty) {
      return;
    }

    final point = LatLng(position.latitude, position.longitude);

    for (final zone in zones) {
      if (_pointInPolygon(point, zone.points)) {
        targetZone.value = zone;
        distanceMeters.value = 0;
        isInsideZone.value = true;
        return;
      }
    }

    isInsideZone.value = false;
    SafeZone? closest;
    double? closestDistance;
    for (final zone in zones) {
      final distance = _distanceMeters(point, _centroid(zone.points));
      if (closestDistance == null || distance < closestDistance) {
        closest = zone;
        closestDistance = distance;
      }
    }
    targetZone.value = closest;
    distanceMeters.value = closestDistance?.round();
  }

  Future<void> retry() => _start();

  @override
  void onClose() {
    _positionSub?.cancel();
    super.onClose();
  }
}

/// Same ray-casting algorithm as SafeZoneMapScreen._pointInPolygon,
/// duplicated here rather than shared since the admin screen's copy is
/// a private static method on that widget's State class. If you'd
/// rather have one shared implementation, move this (and
/// SafeZoneMapScreen's copy) onto the SafeZone model itself as a real
/// contains() method.
bool _pointInPolygon(LatLng point, List<LatLng> polygon) {
  var inside = false;
  for (var i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
    final xi = polygon[i].longitude, yi = polygon[i].latitude;
    final xj = polygon[j].longitude, yj = polygon[j].latitude;
    final intersects = ((yi > point.latitude) != (yj > point.latitude)) &&
        (point.longitude < (xj - xi) * (point.latitude - yi) / (yj - yi) + xi);
    if (intersects) inside = !inside;
  }
  return inside;
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

double _distanceMeters(LatLng a, LatLng b) {
  const distance = Distance();
  return distance.as(LengthUnit.Meter, a, b);
}