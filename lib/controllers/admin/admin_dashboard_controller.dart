import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Minimal model for a drill / emergency event.
class DrillEvent {
  final String id;
  final String? title;
  final String status;
  final DateTime? startedAt;

  DrillEvent({
    required this.id,
    this.title,
    required this.status,
    this.startedAt,
  });

  factory DrillEvent.fromMap(Map<String, dynamic> map) {
    return DrillEvent(
      id: map['id'] as String,
      title: map['title'] as String?,
      status: map['status'] as String? ?? 'active',
      startedAt: map['started_at'] != null
          ? DateTime.tryParse(map['started_at'].toString())
          : null,
    );
  }
}

/// Tracks whether a drill/emergency is currently active and exposes the
/// live headcount analytics derived from `headcount_entries` (one row per
/// student per drill, with `section_id` on the row). Also subscribes to
/// `drill_events` directly so the dashboard reacts live when a drill
/// starts or is marked completed.
class AdminDashboardController extends GetxController {
  final SupabaseClient _client = Supabase.instance.client;

  final Rxn<DrillEvent> activeDrill = Rxn<DrillEvent>();
  final RxBool isDrillLoading = true.obs;
  final RxBool isAnalyticsLoading = false.obs;

  /// Head count per status category, e.g. {safe: 12, injured: 1, ...}
  final RxMap<String, int> statusHeadCounts = <String, int>{}.obs;

  /// Head count per section, keyed by section name.
  final RxMap<String, int> sectionHeadCounts = <String, int>{}.obs;

  RealtimeChannel? _statusChannel;
  RealtimeChannel? _drillEventsChannel;

  static const List<String> statusCategories = [
    'safe',
    'injured',
    'missing',
    'searching',
    'absent',
  ];

  @override
  void onInit() {
    super.onInit();
    fetchActiveDrill();
    _subscribeToDrillEvents();
  }

  @override
  void onClose() {
    _statusChannel?.unsubscribe();
    _drillEventsChannel?.unsubscribe();
    super.onClose();
  }

  void _subscribeToDrillEvents() {
    _drillEventsChannel = _client
        .channel('drill_events_watch')
        .onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'drill_events',
      callback: (payload) => fetchActiveDrill(),
    )
        .subscribe();
  }

  /// Checks whether a drill is currently active and, if so, loads analytics
  /// and subscribes to live updates.
  Future<void> fetchActiveDrill() async {
    try {
      isDrillLoading.value = true;
      final data = await _client
          .from('drill_events')
          .select()
          .eq('status', 'active')
          .order('started_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (data != null) {
        activeDrill.value = DrillEvent.fromMap(data);
        await _fetchAnalytics(activeDrill.value!.id);
        _subscribeToStatusUpdates(activeDrill.value!.id);
      } else {
        activeDrill.value = null;
        statusHeadCounts.clear();
        sectionHeadCounts.clear();
        _statusChannel?.unsubscribe();
      }
    } catch (e, st) {
      // TEMP DEBUG: print the real error instead of failing silently.
      // Remove this once we've confirmed the query works.
      debugPrint('AdminDashboardController.fetchActiveDrill error: $e');
      debugPrint('$st');
      activeDrill.value = null;
    } finally {
      isDrillLoading.value = false;
    }
  }

  Future<void> _fetchAnalytics(String drillEventId) async {
    try {
      isAnalyticsLoading.value = true;

      final rows = await _client
          .from('headcount_entries')
          .select('status, section_id, sections(name)')
          .eq('drill_event_id', drillEventId);

      final Map<String, int> byStatus = {
        for (final s in statusCategories) s: 0,
      };
      final Map<String, int> bySection = {};

      for (final row in (rows as List)) {
        final status = row['status'] as String? ?? 'unknown';
        byStatus[status] = (byStatus[status] ?? 0) + 1;

        final sectionName = row['sections']?['name'] as String?;
        if (sectionName != null) {
          bySection[sectionName] = (bySection[sectionName] ?? 0) + 1;
        }
      }

      statusHeadCounts.assignAll(byStatus);
      sectionHeadCounts.assignAll(bySection);
    } catch (e, st) {
      // TEMP DEBUG: print the real error instead of failing silently.
      // Remove this once we've confirmed the query works.
      debugPrint('AdminDashboardController._fetchAnalytics error: $e');
      debugPrint('$st');
    } finally {
      isAnalyticsLoading.value = false;
    }
  }

  void _subscribeToStatusUpdates(String drillEventId) {
    _statusChannel?.unsubscribe();
    _statusChannel = _client
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
      callback: (payload) => _fetchAnalytics(drillEventId),
    )
        .subscribe();
  }

  /// Marks the active drill/emergency as completed.
  Future<bool> completeActiveDrill() async {
    final drill = activeDrill.value;
    if (drill == null) return false;

    try {
      await _client.from('drill_events').update({
        'status': 'completed',
        'ended_at': DateTime.now().toIso8601String(),
      }).eq('id', drill.id);

      _statusChannel?.unsubscribe();
      activeDrill.value = null;
      statusHeadCounts.clear();
      sectionHeadCounts.clear();
      return true;
    } catch (e, st) {
      debugPrint('AdminDashboardController.completeActiveDrill error: $e');
      debugPrint('$st');
      Get.snackbar('Error', 'Could not complete the drill. Please try again.');
      return false;
    }
  }
}