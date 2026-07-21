import 'package:asan_evac_app/models/drill_event.dart';
import 'package:asan_evac_app/services/drill_service.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // Added to access PostgrestException and AuthException

class DrillController extends GetxController {
  final _drillService = DrillService();

  final nameController = TextEditingController();
  final Rx<DrillEventType> selectedEventType = DrillEventType.drill.obs;
  final Rxn<DisasterType> selectedDisasterType = Rxn<DisasterType>();

  final RxBool isSaving = false.obs;
  final RxnString errorMessage = RxnString();

  final RxList<DrillEvent> activeDrills = <DrillEvent>[].obs;
  final RxBool isLoadingActive = false.obs;

  @override
  void onInit() {
    super.onInit();
    fetchActiveDrills();
  }

  Future<void> fetchActiveDrills() async {
    isLoadingActive.value = true;
    try {
      final result = await _drillService.fetchActiveDrills();
      activeDrills.assignAll(result);
    } finally {
      isLoadingActive.value = false;
    }
  }

  /// Inserts the drill_events row. That insert alone is what fires the
  /// DB webhook -> Edge Function -> FCM broadcast to 'all_users'.
  /// Returns true on success so the screen can pop / show confirmation.
  Future<bool> startDrill() async {
    errorMessage.value = null;

    if (nameController.text.trim().isEmpty) {
      errorMessage.value = 'Give this drill a name.';
      return false;
    }
    if (selectedEventType.value == DrillEventType.emergency &&
        selectedDisasterType.value == null) {
      errorMessage.value = 'Select a disaster type for a real emergency.';
      return false;
    }

    isSaving.value = true;
    try {
      await _drillService.startDrill(
        name: nameController.text.trim(),
        eventType: selectedEventType.value,
        disasterType: selectedDisasterType.value,
      );
      await fetchActiveDrills();
      return true;
    } on PostgrestException catch (e) {
      // Handles Supabase Database errors cleanly
      errorMessage.value = e.message;
      return false;
    } on AuthException catch (e) {
      // Handles Supabase Authentication errors cleanly
      errorMessage.value = e.message;
      return false;
    } catch (e) {
      // Fallback for your manual Exception('Not signed in.') or other unexpected errors
      errorMessage.value = e.toString().replaceFirst('Exception: ', '');
      return false;
    } finally {
      isSaving.value = false;
    }
  }

  Future<void> endDrill(String drillEventId) async {
    await _drillService.endDrill(drillEventId);
    await fetchActiveDrills();
  }

  @override
  void onClose() {
    nameController.dispose();
    super.onClose();
  }
}
