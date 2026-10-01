import 'package:flutter/foundation.dart';

import 'supabase_client.dart';
import '../models/drill_event.dart';
import '../models/section_claim.dart';
import '../models/head_count_status.dart';

class DrillService {
  /// Mirrors the limit enforced by the `trg_max_two_claims` DB trigger.
  static const int maxClaimsPerTeacher = 2;

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
    await supabase
        .from('drill_events')
        .update({
          'status': 'ended',
          'ended_at': DateTime.now().toIso8601String(),
        })
        .eq('id', drillEventId);
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
  // Headcount writes to its own `headcount_entries` table rather than
  // status_updates/current_status — those two power student self-report
  // and have RLS policies built around that, which a roster-based
  // student can't satisfy. Keeping headcount separate avoids touching
  // any of that.
  //
  // NOTE: safe-zone fetching used to live here too (fetchActiveSafeZones)
  // but that duplicated SafeZoneService, which the admin safe-zone
  // screen already owns — removed in favor of calling SafeZoneService
  // directly from MapHeadcountGateController instead of from here.
  //
  // Claim rules (enforced in the database, not just here):
  //  * A section CAN be claimed by several teachers in the same drill.
  //  * A teacher can claim at most [maxClaimsPerTeacher] sections per
  //    drill. The `trg_max_two_claims` trigger on
  //    event_section_assignments raises 'MAX_CLAIMS_REACHED: ...' when
  //    a third claim is attempted.
  //  * UNIQUE (drill_event_id, section_id, teacher_id) stops the same
  //    teacher claiming the same section twice (Postgres code 23505).
  // Do NOT add UNIQUE (drill_event_id, section_id) — that would block
  // co-handling of a section.
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
    final row = await supabase
        .from('drill_events')
        .select()
        .eq('id', id)
        .maybeSingle();
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

  /// Claims a section for [teacherId] in this drill. Other teachers may
  /// already have claimed the same section — that's allowed.
  ///
  /// Throws a `PostgrestException` when the database rejects the claim:
  ///  * message contains 'MAX_CLAIMS_REACHED' — teacher already has the
  ///    maximum number of sections for this drill
  ///  * code '23505' — this teacher already claimed this section
  /// Callers should catch it (see SectionClaimController.claimSection).
  Future<SectionClaim> claimSection({
    required String drillEventId,
    required String sectionId,
    required String teacherId,
  }) async {
    final row = await supabase
        .from('event_section_assignments')
        .insert({
          'drill_event_id': drillEventId,
          'section_id': sectionId,
          'teacher_id': teacherId,
        })
        .select('*, teacher:teacher_id(full_name)')
        .single();

    // Seed every roster student as 'missing' now that the section is
    // owned. Best-effort: the claim has already succeeded, so a seeding
    // failure must not make it look like the claim failed.
    // HeadcountController re-seeds anything missing when the screen loads.
    try {
      final roster = await fetchStudentsForHeadcount(sectionId);
      await seedHeadcountMissing(
        drillEventId: drillEventId,
        sectionId: sectionId,
        rosterIds: roster.map((s) => s.rosterId).toList(),
        updatedBy: teacherId,
      );
    } catch (e) {
      debugPrint('Headcount seed on claim failed: $e');
    }

    return SectionClaim.fromMap(row);
  }

  /// Every student on the roster for this section — registered or not.
  /// Headcount tracks `roster.id` directly, so a student who hasn't
  /// signed up for the app yet is included the same as one who has.
  /// `isRegistered` is display-only.
  Future<List<HeadcountStudent>> fetchStudentsForHeadcount(
    String sectionId,
  ) async {
    final rows = await supabase
        .from('roster')
        .select()
        .eq('section_id', sectionId)
        .eq('role', 'student')
        .order('full_name');
    return (rows as List)
        .map(
          (r) => HeadcountStudent(
            rosterId: r['id'] as String,
            fullName: r['full_name'] as String,
            schoolIdNumber: r['school_id_number'] as String,
            isRegistered: r['claimed'] as bool? ?? false,
          ),
        )
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
    return {
      for (final r in (rows as List))
        r['roster_id'] as String: r as Map<String, dynamic>,
    };
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
    await supabase.from('headcount_entries').upsert({
      'drill_event_id': drillEventId,
      'section_id': sectionId,
      'roster_id': rosterId,
      'status': status,
      'updated_by': updatedBy,
      'updated_at': DateTime.now().toIso8601String(),
    }, onConflict: 'drill_event_id,roster_id');
  }

  /// Inserts a 'missing' row for each roster id that has no entry yet
  /// for this drill. Existing rows are never overwritten
  /// (`ignoreDuplicates` → INSERT ... ON CONFLICT DO NOTHING), so this
  /// is safe to call repeatedly and safe against two teachers racing.
  Future<void> seedHeadcountMissing({
    required String drillEventId,
    required String sectionId,
    required List<String> rosterIds,
    required String updatedBy,
  }) async {
    if (rosterIds.isEmpty) return;

    final now = DateTime.now().toIso8601String();
    await supabase
        .from('headcount_entries')
        .upsert(
          [
            for (final id in rosterIds)
              {
                'drill_event_id': drillEventId,
                'section_id': sectionId,
                'roster_id': id,
                'status': HeadcountStatus.missing,
                'updated_by': updatedBy,
                'updated_at': now,
              },
          ],
          onConflict: 'drill_event_id,roster_id',
          ignoreDuplicates: true,
        );
  }
}
