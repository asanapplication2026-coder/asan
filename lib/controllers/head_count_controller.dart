import 'package:asan_evac_app/models/head_count_status.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../controllers/auth_controller.dart';
import '../../services/drill_service.dart';

class HeadcountController extends GetxController {
  HeadcountController({required this.drillEventId, required this.sectionId});

  final String drillEventId;
  final String sectionId;
  final _drillService = DrillService();

  final RxList<HeadcountStudent> students = <HeadcountStudent>[].obs;
  final RxBool isLoading = false.obs;
  final RxnString errorMessage = RxnString();
  final RxSet<String> _savingIds = <String>{}.obs;

  // --- UI State ---
  final RxInt selectedTab = 0.obs;
  // Updated filter state to default to 'All'
  final RxString selectedFilter = 'All'.obs;

  // --- Derived Real-time KPI Data ---
  KpiDataModel get realtimeKpiData => KpiDataModel(
    totalExpected: students.length,
    totalCounted: students.where((s) => s.status != null).length,
    safeCount: students.where((s) => s.status == 'safe').length,
    injuredCount: students.where((s) => s.status == 'injured').length,
    missingCount: students.where((s) => s.status == 'missing').length,
    absentCount: students.where((s) => s.status == 'absent').length,
  );

  final RxString searchQuery = ''.obs;

  RealtimeChannel? _channel;

  String get _teacherId => Get.find<AuthController>().profile.value!.id;

  bool isSaving(String rosterId) => _savingIds.contains(rosterId);

  // Updated filtering logic to support 'All' and dynamic status matching
  List<HeadcountStudent> get filteredStudents {
    final query = searchQuery.value.trim().toLowerCase();
    final filter = selectedFilter.value;

    return students.where((s) {
      final matchesQuery = query.isEmpty ||
          s.fullName.toLowerCase().contains(query) ||
          s.schoolIdNumber.toLowerCase().contains(query);
      if (!matchesQuery) return false;

      if (filter == 'All') return true;
      return s.status == filter;
    }).toList();
  }

  void setSearchQuery(String value) => searchQuery.value = value;

  @override
  void onInit() {
    super.onInit();
    _load();
    _subscribeRealtime();
  }

  Future<void> _load() async {
    isLoading.value = true;
    errorMessage.value = null;
    try {
      final roster = await _drillService.fetchStudentsForHeadcount(sectionId);
      final statuses = await _drillService.fetchHeadcountStatuses(
        drillEventId: drillEventId,
        rosterIds: roster.map((s) => s.rosterId).toList(),
      );
      for (final s in roster) {
        final row = statuses[s.rosterId];
        if (row != null) {
          s.status = row['status'] as String?;
          final updatedAtRaw = row['updated_at'] as String?;
          s.updatedAt = updatedAtRaw == null ? null : DateTime.tryParse(updatedAtRaw);
        }
      }
      students.assignAll(roster);
    } catch (e) {
      errorMessage.value = 'Failed to load roster: $e';
    } finally {
      isLoading.value = false;
    }
  }

  @override
  Future<void> refresh() => _load();

  void _subscribeRealtime() {
    try {
      _channel = Supabase.instance.client
          .channel('headcount_entries_drill_$drillEventId')
          .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'headcount_entries',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'drill_event_id',
          value: drillEventId,
        ),
        callback: (payload) {
          final row = payload.newRecord;
          final rosterId = row['roster_id'] as String?;
          if (rosterId == null) return;
          final index = students.indexWhere((s) => s.rosterId == rosterId);
          if (index == -1) return;
          students[index].status = row['status'] as String?;
          final updatedAtRaw = row['updated_at'] as String?;
          students[index].updatedAt = updatedAtRaw == null ? null : DateTime.tryParse(updatedAtRaw);
          students.refresh();
        },
      )
          .subscribe();
    } catch (_) {
    }
  }

  Future<void> setStatus(String rosterId, String status) async {
    final index = students.indexWhere((s) => s.rosterId == rosterId);
    if (index == -1) return;

    final previous = students[index].status;
    _savingIds.add(rosterId);
    students[index].status = status;
    students.refresh();

    try {
      await _drillService.recordHeadcountStatus(
        drillEventId: drillEventId,
        sectionId: sectionId,
        rosterId: rosterId,
        status: status,
        updatedBy: _teacherId,
      );
    } catch (e) {
      students[index].status = previous;
      students.refresh();
      Get.snackbar('Error', 'Could not save status: $e');
    } finally {
      _savingIds.remove(rosterId);
    }
  }

  @override
  void onClose() {
    _channel?.unsubscribe();
    super.onClose();
  }
}