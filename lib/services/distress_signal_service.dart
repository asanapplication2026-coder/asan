import 'package:asan_evac_app/models/distress_signal_model.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:supabase_flutter/supabase_flutter.dart';


/// All Supabase access for `public.distress_signals` lives here — the
/// controller and the SMS/call listeners both go through this, so there's
/// one place that knows the table/column names.
class DistressSignalService {
  final _client = Supabase.instance.client;

  Future<List<DistressSignal>> fetchSignals(String drillEventId) async {
    debugPrint('[DistressSignalService] fetchSignals drillEventId=$drillEventId');
    final rows = await _client
        .from('distress_signals')
        .select()
        .eq('drill_event_id', drillEventId)
        .order('created_at', ascending: false);
    debugPrint('[DistressSignalService] fetchSignals -> ${(rows as List).length} rows');
    return rows
        .map((r) => DistressSignal.fromMap(r))
        .toList();
  }

  /// Used by the in-app SOS button (channel = app) and by the SMS/missed-call
  /// listeners once they've resolved a roster entry — or, failing that,
  /// with just the identifier the sender typed as [studentName].
  ///
  /// NOTE: the actual `distress_signals` table column is `roster_id`, not
  /// `student_id` — this was previously mismatched and would have failed
  /// on insert. `roster_id` is nullable; at least one of [rosterId] /
  /// [studentName] must be provided so a signal is never unattributable.
  Future<DistressSignal> createSignal({
    required String drillEventId,
    required DistressChannel channel,
    String? rosterId,
    String? studentName,
    double? latitude,
    double? longitude,
    String? building,
    String? floor,
    String? message,
  }) async {
    assert(
    rosterId != null || studentName != null,
    'createSignal needs either a rosterId or a studentName fallback',
    );
    final payload = {
      'drill_event_id': drillEventId,
      'channel': channel.value,
      'roster_id': ?rosterId,
      'student_name': ?studentName,
      'latitude': ?latitude,
      'longitude': ?longitude,
      'building': ?building,
      'floor': ?floor,
      'message': ?message,
    };
    debugPrint('[DistressSignalService] createSignal payload=$payload');
    try {
      final row = await _client.from('distress_signals').insert(payload).select().single();
      debugPrint('[DistressSignalService] createSignal OK id=${row['id']}');
      return DistressSignal.fromMap(row);
    } catch (e, st) {
      // This is the call that almost always explains a "row never appeared"
      // report: RLS rejecting the insert, a bad FK, a NOT NULL column we
      // didn't send, etc. Previously this exception propagated up to
      // _trySync's catch-all in the SMS service and was swallowed with no
      // trace at all.
      debugPrint('[DistressSignalService] createSignal FAILED: $e');
      debugPrint(st.toString());
      rethrow;
    }
  }

  /// Best-effort live feed, same pattern as HeadcountController's
  /// `_subscribeRealtime` — wrapped so a subscription failure (e.g.
  /// Realtime not yet enabled on this table) can never crash the screen.
  RealtimeChannel subscribeToSignals({
    required String drillEventId,
    required void Function(DistressSignal signal) onInsert,
  }) {
    debugPrint('[DistressSignalService] subscribing to distress_signals_drill_$drillEventId');
    final channel = _client
        .channel('distress_signals_drill_$drillEventId')
        .onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'distress_signals',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'drill_event_id',
        value: drillEventId,
      ),
      callback: (payload) {
        debugPrint('[DistressSignalService] realtime INSERT received: ${payload.newRecord}');
        onInsert(DistressSignal.fromMap(payload.newRecord));
      },
    )
        .subscribe((status, [error]) {
      // This is the piece that was missing: the previous version called
      // .subscribe() with no status callback, so a failed/errored/timed-out
      // subscription (bad RLS, Realtime not enabled on the table, auth
      // issue) failed completely silently. Now it prints exactly which.
      debugPrint('[DistressSignalService] realtime status=$status error=$error');
    });
    return channel;
  }

  // ── Lookups used by the SMS / missed-call listeners ──────────────────
  //
  // ⚠️ ADJUST: both of these guess at column/table names that aren't in
  // the `distress_signals` schema you shared. Point them at whatever your
  // actual roster/profiles and `drill_events` tables use before relying
  // on this in production.

  /// Resolves an incoming SMS/call's sender phone number to a
  /// `distress_signals.roster_id`.
  ///
  /// `roster` itself has no phone number column — a student's roster row
  /// only becomes phone-reachable once someone "claims" it with an app
  /// account. So this goes through `profiles` (which does have a phone
  /// number, in `registered_phone_number` — NOT `phone_number`, that
  /// column doesn't exist and will 42703) and bridges to `roster` via the
  /// `school_id_number` both tables share.
  ///
  /// Returns null whenever the sender's number isn't a claimed account, or
  /// that account's `school_id_number` doesn't match any roster row — both
  /// are expected for unclaimed roster entries. [resolveRosterId] below is
  /// the fallback for that case.
  Future<String?> resolveRosterIdByPhone(String phoneNumber) async {
    debugPrint('[DistressSignalService] resolveRosterIdByPhone phone=$phoneNumber');
    final profile = await _client
        .from('profiles')
        .select('school_id_number')
        .eq('registered_phone_number', phoneNumber)
        .maybeSingle();
    if (profile == null) {
      debugPrint('[DistressSignalService] resolveRosterIdByPhone -> no profiles row for that number');
      return null;
    }
    final schoolIdNumber = profile['school_id_number'] as String?;
    if (schoolIdNumber == null || schoolIdNumber.isEmpty) {
      debugPrint('[DistressSignalService] resolveRosterIdByPhone -> profile matched but has no school_id_number');
      return null;
    }
    final rosterRow = await _client
        .from('roster')
        .select('id')
        .eq('school_id_number', schoolIdNumber)
        .maybeSingle();
    debugPrint('[DistressSignalService] resolveRosterIdByPhone -> ${rosterRow?['id']}'
        '${rosterRow == null ? '  (profile school_id_number=$schoolIdNumber has no matching roster row)' : ''}');
    return rosterRow?['id'] as String?;
  }

  /// Fallback for roster rows with no claimed phone: resolves whatever
  /// identifier the student typed into the SMS body directly against
  /// `roster`. Tries an exact `school_id_number` match first (unique,
  /// typo-resistant — prefer training students to text this), then falls
  /// back to a `full_name` match. A name match that hits more than one
  /// roster row is treated as unresolved rather than guessing, since
  /// misfiling someone else's emergency is worse than leaving it pending
  /// for manual review (see LocalDistressSignalStore.getAll()).
  Future<String?> resolveRosterId({String? schoolIdNumber, String? fullName}) async {
    if (schoolIdNumber != null && schoolIdNumber.trim().isNotEmpty) {
      final row = await _client
          .from('roster')
          .select('id')
          .eq('school_id_number', schoolIdNumber.trim())
          .maybeSingle();
      debugPrint('[DistressSignalService] resolveRosterId by school_id_number="$schoolIdNumber" -> ${row?['id']}');
      if (row != null) return row['id'] as String?;
    }

    if (fullName != null && fullName.trim().isNotEmpty) {
      final rows = await _client
          .from('roster')
          .select('id, full_name')
          .ilike('full_name', fullName.trim())
          .limit(5);
      debugPrint('[DistressSignalService] resolveRosterId by full_name="$fullName" -> ${(rows as List).length} match(es)');
      if (rows.length == 1) return rows.first['id'] as String?;
      if (rows.length > 1) {
        debugPrint('[DistressSignalService] resolveRosterId: AMBIGUOUS name match for "$fullName": '
            '${rows.map((r) => r['full_name']).join(', ')} — leaving unresolved.');
      }
    }

    return null;
  }

  /// Finds the currently-running drill event, so an SMS/missed call (which
  /// carries no drill_event_id of its own) can still be filed against one.
  /// Assumes a `status` column on `drill_events` with an `'in_progress'`
  /// value — adjust to match your actual drill lifecycle column.
  Future<String?> fetchActiveDrillEventId() async {
    debugPrint('[DistressSignalService] fetchActiveDrillEventId');
    final row = await _client
        .from('drill_events')
        .select('id')
        .eq('status', 'active')   // was 'in_progress'
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
    debugPrint('[DistressSignalService] fetchActiveDrillEventId -> ${row?['id']}'
        '${row == null ? '  (no drill_events row with status=active — is a drill actually running?)' : ''}');
    return row?['id'] as String?;
  }
}