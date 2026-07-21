import 'package:get/get.dart';
import 'package:latlong2/latlong.dart';
import '../../models/safe_zone_model.dart';
import '../../services/safe_zone_service.dart';

class SafeZoneController extends GetxController {
  final SafeZoneService _service = SafeZoneService();

  final RxList<SafeZone> safeZones = <SafeZone>[].obs;
  final RxBool isLoading = false.obs;
  final RxBool isSaving = false.obs;
  final Rxn<String> errorMessage = Rxn<String>();

  // State for the "check a point" test screen.
  final Rxn<LatLng> lastCheckedPoint = Rxn<LatLng>();
  final Rxn<SafeZoneCheckResult> lastCheckResult = Rxn<SafeZoneCheckResult>();
  final RxBool isChecking = false.obs;

  @override
  void onInit() {
    super.onInit();
    fetchSafeZones();
  }

  Future<void> fetchSafeZones() async {
    try {
      isLoading.value = true;
      errorMessage.value = null;
      final zones = await _service.fetchSafeZones();
      safeZones.assignAll(zones);
    } catch (e) {
      errorMessage.value = 'Failed to load safe zones: $e';
    } finally {
      isLoading.value = false;
    }
  }

  /// Creates a safe zone from an ordered list of tapped pins (in practice,
  /// 4 — but any 3+ point polygon works). Can be tilted/irregular, not
  /// just an axis-aligned rectangle.
  Future<bool> createSafeZone({
    required String name,
    required List<LatLng> points,
  }) async {
    try {
      isSaving.value = true;
      final zone = await _service.createSafeZone(name: name, points: points);
      safeZones.add(zone);
      return true;
    } catch (e) {
      Get.snackbar('Error', 'Failed to create safe zone: $e');
      return false;
    } finally {
      isSaving.value = false;
    }
  }

  Future<void> toggleActive(SafeZone zone) async {
    final newValue = !zone.isActive;
    try {
      await _service.setActive(zone.id, newValue);
      final index = safeZones.indexWhere((z) => z.id == zone.id);
      if (index != -1) {
        safeZones[index] = zone.copyWith(isActive: newValue);
      }
    } catch (e) {
      Get.snackbar('Error', 'Failed to update safe zone: $e');
    }
  }

  Future<void> deleteSafeZone(SafeZone zone) async {
    try {
      await _service.deleteSafeZone(zone.id);
      safeZones.removeWhere((z) => z.id == zone.id);
    } catch (e) {
      Get.snackbar('Error', 'Failed to delete safe zone: $e');
    }
  }

  /// Calls the check_point_in_safe_zone RPC for the given point and stores
  /// the result — used by the "check a point" test screen.
  Future<void> checkPoint(LatLng point) async {
    try {
      isChecking.value = true;
      lastCheckedPoint.value = point;
      final result = await _service.checkPointInSafeZone(
        lat: point.latitude,
        lng: point.longitude,
      );
      lastCheckResult.value = result;
    } catch (e) {
      Get.snackbar('Error', 'Failed to check location: $e');
    } finally {
      isChecking.value = false;
    }
  }
}