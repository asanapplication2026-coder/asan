import 'package:asan_evac_app/controllers/auth/auth_controller.dart';
import 'package:asan_evac_app/models/head_count_status.dart';
import 'package:asan_evac_app/services/drill_service.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';


/// Backs the headcount screen for one section during one drill event.
/// Tracks every roster entry for the section — registered or not —
/// writing to the dedicated `headcount_entries` table, kept separate
/// from status_updates/current_status so student self-report there is
/// completely unaffected.
///
/// ⚠️ ADJUST: `_teacherId` assumes `AuthController.profile` the same
/// way TeacherRosterController does.
class HeadcountController extends GetxController {
  HeadcountController({required this.drillEventId, required this.sectionId});

  final String drillEventId;
  final String sectionId;
  final _drillService = DrillService();

  final RxList<HeadcountStudent> students = <HeadcountStudent>[].obs;
  final RxBool isLoading = false.obs;
  final RxnString errorMessage = RxnString();
  final RxSet<String> _savingIds = <String>{}.obs;

  /// Roster IDs that just saved successfully — shown as a brief
  /// checkmark before fading back to the normal status badge. Cleared
  /// automatically a couple seconds after being set, not on next load.
  final RxSet<String> _recentlySavedIds = <String>{}.obs;

  /// Search box text — matches against full name or school ID number.
  final RxString searchQuery = ''.obs;

  /// Which bottom tab is active: 0 = Students, 1 = Overview.
  final RxInt selectedTab = 0.obs;

  /// Selected filter chip: 'All', or one of the HeadcountStatus values.
  /// Plain string (not nullable) — the screen assigns directly via
  /// `controller.selectedFilter.value = filter`, no setter needed.
  final RxString selectedFilter = 'All'.obs;

  RealtimeChannel? _channel;

  // `.value` on AuthController.profile is nullable (Rxn<AppProfile>) —
  // the `!` here is intentional, not an oversight. If this ever throws,
  // it means this controller got constructed before AuthController
  // finished loading the profile, which is a real bug to fix at the
  // call site, not something to silently null-check around here.
  String get _teacherId => Get.find<AuthController>().profile.value!.id;

  bool isSaving(String rosterId) => _savingIds.contains(rosterId);
  bool wasRecentlySaved(String rosterId) => _recentlySavedIds.contains(rosterId);

  /// Absent students are deliberately excluded from both sides of the
  /// ratio — "counted" only tracks students actually expected to be
  /// physically present.
  int get absentCount => students.where((s) => s.status == HeadcountStatus.absent).length;
  int get totalCount => students.length;
  int get totalExpectedCount => totalCount - absentCount;
  int get countedCount =>
      students.where((s) => s.status != null && s.status != HeadcountStatus.absent).length;

  /// `students` filtered by the current search text and selected chip.
  /// Search takes precedence: if there's search text, it searches the
  /// whole roster regardless of which filter chip is selected — it
  /// does NOT narrow further by status. The filter chip only applies
  /// when the search box is empty.
  List<HeadcountStudent> get filteredStudents {
    final query = searchQuery.value.trim().toLowerCase();

    if (query.isNotEmpty) {
      return students
          .where((s) =>
      s.fullName.toLowerCase().contains(query) ||
          s.schoolIdNumber.toLowerCase().contains(query))
          .toList();
    }

    final filter = selectedFilter.value;
    if (filter == 'All') return students.toList();
    return students.where((s) => s.status == filter).toList();
  }

  /// KPI data for the Overview tab. The "Injured" card maps to the
  /// `trap` status constant — your HeadcountStatus enum never had a
  /// separate `injured` value, "Injured" is just the display text this
  /// KPI card happens to use (independent of HeadcountStatus.label()).
  HeadcountKpiData get realtimeKpiData {
    return HeadcountKpiData(
      totalExpected: totalExpectedCount,
      totalCounted: countedCount,
      safeCount: students.where((s) => s.status == HeadcountStatus.safe).length,
      injuredCount: students.where((s) => s.status == HeadcountStatus.trap).length,
      missingCount: students.where((s) => s.status == HeadcountStatus.missing).length,
      absentCount: absentCount,
    );
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

  /// Best-effort live updates. If Realtime isn't enabled yet on
  /// `headcount_entries`, this subscription just never fires — the
  /// screen still works fine via manual pull-to-refresh. Wrapped so a
  /// subscription failure can never crash the screen.
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
      // Realtime not available for this table yet — non-fatal.
    }
  }

  Future<void> setStatus(String rosterId, String status) async {
    final index = students.indexWhere((s) => s.rosterId == rosterId);
    if (index == -1) return;

    final previous = students[index].status;
    _savingIds.add(rosterId);
    students[index].status = status; // optimistic
    students.refresh();

    try {
      await _drillService.recordHeadcountStatus(
        drillEventId: drillEventId,
        sectionId: sectionId,
        rosterId: rosterId,
        status: status,
        updatedBy: _teacherId,
      );
      _recentlySavedIds.add(rosterId);
      Future.delayed(const Duration(seconds: 2), () => _recentlySavedIds.remove(rosterId));
    } catch (e) {
      students[index].status = previous; // revert on failure
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

/// Aggregated counts for the Overview tab's KPI cards.
class HeadcountKpiData {
  final int totalExpected;
  final int totalCounted;
  final int safeCount;
  final int injuredCount;
  final int missingCount;
  final int absentCount;

  HeadcountKpiData({
    required this.totalExpected,
    required this.totalCounted,
    required this.safeCount,
    required this.injuredCount,
    required this.missingCount,
    required this.absentCount,
  });
}