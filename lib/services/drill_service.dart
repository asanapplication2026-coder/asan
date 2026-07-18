import '../models/head_count_status.dart';
import 'supabase_client.dart';
import '../models/drill_event.dart';
import '../models/section_claim.dart';

class DrillService {
  /// Admin/teacher starts a drill or a real emergency.
  ///
  /// This single insert is the entire trigger chain:
  ///   drill_events INSERT
  ///     -> Supabase DB Webhook (configured in the dashboard / migration)
  ///     -> "notify-drill" Edge Function
  ///     -> FCM topic 'all_users'
  ///     -> every subscribed device gets the alert
  ///
  /// Nothing else needs to be called from the client — nobody in Flutter
  /// ever touches an FCM key or sends the push directly.
  Future<DrillEvent> startDrill({
    required String name,
    required DrillEventType eventType,
    DisasterType? disasterType,
  }) async {
    final currentUserId = supabase.auth.currentUser?.id;
    if (currentUserId == null) {
      throw Exception('Not signed in.');
    }

    final row = await supabase
        .from('drill_events')
        .insert({
      'name': name,
      'event_type': eventType.name,
      if (disasterType != null) 'disaster_type': disasterType.name,
      'created_by': currentUserId,
      // status defaults to 'active' in the DB, started_at defaults to now()
    })
        .select()
        .single();

    return DrillEvent.fromMap(row);
  }

  /// Ends an active drill/emergency.
  ///
  /// Note: the webhook below only fires on INSERT, so ending a drill is
  /// silent by design — no "all clear" push goes out. If you want one,
  /// add a second webhook/trigger on UPDATE where status changes to
  /// 'ended' and have the edge function branch on payload.type.
  Future<void> endDrill(String drillEventId) async {
    await supabase.from('drill_events').update({
      'status': 'ended',
      'ended_at': DateTime.now().toIso8601String(),
    }).eq('id', drillEventId);
  }

  Future<List<DrillEvent>> fetchActiveDrills() async {
    final rows = await supabase
        .from('drill_events')
        .select()
        .eq('status', 'active')
        .order('started_at', ascending: false);
    return (rows as List).map((r) => DrillEvent.fromMap(r)).toList();
  }

  Future<List<DrillEvent>> fetchAllDrills() async {
    final rows = await supabase
        .from('drill_events')
        .select()
        .order('started_at', ascending: false);
    return (rows as List).map((r) => DrillEvent.fromMap(r)).toList();
  }

  // ---------------------------------------------------------------------
  // Below this line: additions for the "claim a section, then run
  // headcount" flow. Nothing above was changed — existing callers of
  // startDrill/endDrill/fetchActiveDrills/fetchAllDrills are unaffected.
  //
  // Headcount writes to its own `headcount_entries` table (see the
  // 2026_07_headcount_entries migration) rather than
  // status_updates/current_status — those two power student
  // self-report (student_id = auth.uid()) and have RLS policies built
  // around that, which a roster-based student can't satisfy. Keeping
  // headcount separate avoids touching any of that.
  //
  // ⚠️ Worth doing at the database level that this client code cannot
  // guarantee on its own: add a UNIQUE constraint on
  // event_section_assignments(drill_event_id, section_id) — that's
  // what actually prevents two teachers claiming the same section in
  // a race; the pre-check in claimSection below is a UX nicety, not a
  // real lock, without it.
  // ---------------------------------------------------------------------

  /// Convenience wrapper around [fetchActiveDrills] for callers (like the
  /// dashboard banner) that only care about "is *a* drill active right
  /// now", not the full list. Returns the most recently started one if
  /// more than one is somehow active.
  Future<DrillEvent?> fetchActiveDrillEvent() async {
    final active = await fetchActiveDrills();
    return active.isEmpty ? null : active.first;
  }

  Future<DrillEvent?> fetchDrillEventById(String id) async {
    final row = await supabase.from('drill_events').select().eq('id', id).maybeSingle();
    if (row == null) return null;
    return DrillEvent.fromMap(row);
  }

  Future<List<SectionClaim>> fetchClaimsForDrill(String drillEventId) async {
    final rows = await supabase
        .from('event_section_assignments')
        .select('*, teacher:teacher_id(full_name)')
        .eq('drill_event_id', drillEventId);
    return (rows as List).map((r) => SectionClaim.fromMap(r)).toList();
  }

  /// Throws [SectionAlreadyClaimedException] if the section is already
  /// taken. Callers should pre-load [fetchClaimsForDrill] to disable
  /// already-claimed sections in the UI, but should still handle this
  /// exception for the race where two teachers tap at the same time.
  Future<SectionClaim> claimSection({
    required String drillEventId,
    required String sectionId,
    required String teacherId,
  }) async {
    final existing = await supabase
        .from('event_section_assignments')
        .select('*, teacher:teacher_id(full_name)')
        .eq('drill_event_id', drillEventId)
        .eq('section_id', sectionId)
        .maybeSingle();

    if (existing != null) {
      throw SectionAlreadyClaimedException(SectionClaim.fromMap(existing));
    }

    final row = await supabase
        .from('event_section_assignments')
        .insert({
      'drill_event_id': drillEventId,
      'section_id': sectionId,
      'teacher_id': teacherId,
    })
        .select('*, teacher:teacher_id(full_name)')
        .single();
    return SectionClaim.fromMap(row);
  }

  /// Every student on the roster for this section — registered or not.
  /// Headcount now tracks `roster.id` directly (see the 2026_07
  /// migration), so a student who hasn't signed up for the app yet is
  /// included the same as one who has. `isRegistered` is display-only.
  Future<List<HeadcountStudent>> fetchStudentsForHeadcount(String sectionId) async {
    final rows = await supabase
        .from('roster')
        .select()
        .eq('section_id', sectionId)
        .eq('role', 'student')
        .order('full_name');
    return (rows as List)
        .map((r) => HeadcountStudent(
      rosterId: r['id'] as String,
      fullName: r['full_name'] as String,
      schoolIdNumber: r['school_id_number'] as String,
      isRegistered: r['claimed'] as bool? ?? false,
    ))
        .toList();
  }

  Future<Map<String, Map<String, dynamic>>> fetchHeadcountStatuses({
    required String drillEventId,
    required List<String> rosterIds,
  }) async {
    if (rosterIds.isEmpty) return {};
    final rows = await supabase
        .from('headcount_entries')
        .select()
        .eq('drill_event_id', drillEventId)
        .inFilter('roster_id', rosterIds);
    return {for (final r in (rows as List)) r['roster_id'] as String: r as Map<String, dynamic>};
  }

  /// Single upsert into `headcount_entries` — this table is a snapshot
  /// only (unlike status_updates/current_status, there's no separate
  /// append-only log to also write here).
  Future<void> recordHeadcountStatus({
    required String drillEventId,
    required String sectionId,
    required String rosterId,
    required String status,
    required String updatedBy,
  }) async {
    await supabase.from('headcount_entries').upsert(
      {
        'drill_event_id': drillEventId,
        'section_id': sectionId,
        'roster_id': rosterId,
        'status': status,
        'updated_by': updatedBy,
        'updated_at': DateTime.now().toIso8601String(),
      },
      onConflict: 'drill_event_id,roster_id',
    );
  }
}