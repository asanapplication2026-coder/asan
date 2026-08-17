import 'package:flutter/foundation.dart' show debugPrint;
import 'package:another_telephony/telephony.dart';
import 'package:asan_evac_app/services/distress_signal_service.dart';
import 'package:asan_evac_app/services/local_distress_signal_store.dart';

import '../models/distress_signal_model.dart';


/// Parsed shape of an incoming distress SMS, independent of how it was
/// formatted on the wire.
class ParsedDistressSms {
  ParsedDistressSms({
    this.identifier,
    this.latitude,
    this.longitude,
    this.building,
    this.floor,
    this.message,
  });

  /// The student's School ID number (preferred — unique, no typo/collision
  /// risk) or full name, as typed into the SMS. Used to resolve a roster
  /// entry when the sender's phone isn't a claimed profile — see
  /// DistressSignalService.resolveRosterId.
  final String? identifier;

  final double? latitude;
  final double? longitude;
  final String? building;
  final String? floor;
  final String? message;
}

/// Parses the text body of an SMS into distress fields.
///
/// Expected template (pipe-delimited, case-insensitive keyword):
///   SOS|<school ID or full name>|[lat,lng]|[building]|[floor]|[message]
///
/// Example:
///   SOS|21-00456|14.568488,121.076232|Building A|2nd Floor|Trapped near the stairwell, can't move
///
/// The identifier is the one field that isn't skippable in practice:
/// `roster` rows have no phone number, so unless the sender's number is a
/// claimed app account, the identifier is the only way to know who sent
/// the SOS. School ID number is preferred over full name — it's unique,
/// where two students can share a name — but either resolves (see
/// DistressSignalService.resolveRosterId). Everything after the
/// identifier stays optional; missing trailing fields just come back
/// null. Anything that doesn't start with the SOS keyword is NOT treated
/// as a distress signal (see [looksLikeDistress]), so a normal text won't
/// accidentally trigger one.
class DistressSmsTemplate {
  static const keyword = 'SOS';
  static const example =
      "SOS|21-00456|14.568488,121.076232|Building A|2nd Floor|Trapped near the stairwell, can't move";

  static bool looksLikeDistress(String body) {
    return body.trim().toUpperCase().startsWith(keyword);
  }

  static ParsedDistressSms parse(String body) {
    final stripped = body.trim().substring(keyword.length).trim();
    final withoutLeadingPipe = stripped.startsWith('|') ? stripped.substring(1) : stripped;

    if (withoutLeadingPipe.isEmpty) {
      // Bare "SOS" — no identifier at all. Can't be auto-resolved unless
      // the sender's phone happens to be a claimed profile; stays pending
      // for admin review otherwise.
      return ParsedDistressSms();
    }
    if (!withoutLeadingPipe.contains('|')) {
      // "SOS 21-00456" style, no further pipes — treat the whole
      // remainder as the identifier, since that's the field that actually
      // matters for filing the signal.
      return ParsedDistressSms(identifier: withoutLeadingPipe);
    }

    // Field order: identifier | [lat,lng] | [building] | [floor] | [message]
    // If the message itself contains '|', rejoin everything past index 4.
    final parts = withoutLeadingPipe.split('|').map((p) => p.trim()).toList();

    final identifier = parts.isNotEmpty && parts[0].isNotEmpty ? parts[0] : null;

    double? lat;
    double? lng;
    final coordsRaw = parts.length > 1 ? parts[1] : '';
    if (coordsRaw.contains(',')) {
      final coordParts = coordsRaw.split(',').map((s) => s.trim()).toList();
      if (coordParts.length == 2) {
        lat = double.tryParse(coordParts[0]);
        lng = double.tryParse(coordParts[1]);
      }
    }

    final building = parts.length > 2 && parts[2].isNotEmpty ? parts[2] : null;
    final floor = parts.length > 3 && parts[3].isNotEmpty ? parts[3] : null;
    final message = parts.length > 4 ? parts.sublist(4).join('|').trim() : null;

    return ParsedDistressSms(
      identifier: identifier,
      latitude: lat,
      longitude: lng,
      building: building,
      floor: floor,
      message: (message != null && message.isNotEmpty) ? message : null,
    );
  }
}

/// Listens for incoming SMS on the device itself — there's no SMS gateway
/// here, the phone the app is running on is the receiving line. Requires
/// the `telephony` package and RECEIVE_SMS / READ_SMS permissions declared
/// in AndroidManifest.xml. Android-only; iOS has no API for this.
///
/// Every matching SMS is written to the on-device sqlite store
/// ([LocalDistressSignalStore]) the moment it arrives — before we try to
/// resolve the sender or reach Supabase — so an SOS is never lost just
/// because the phone is offline or the sender isn't recognized yet. Call
/// [syncPending] (e.g. on app start, when connectivity returns, or on
/// pull-to-refresh) to retry filing anything still stuck locally.
///
/// ⚠️ `telephony` is unmaintained (last published version 0.2.0, no
/// updates as of 2026). If you hit build issues against a newer Android
/// Gradle Plugin, check pub.dev for a maintained fork (e.g.
/// `another_telephony`) before switching packages entirely — the
/// `listenIncomingSms` API used below is the part most likely to carry
/// over unchanged.
///
/// ⚠️ IMPORTANT — nothing in this file calls [startListening] or
/// [requestPermissions] on its own. If the screen never shows incoming
/// SMS at all (not even a "pending, unsynced" row locally), the most
/// common cause is that nothing in main()/app startup ever constructed
/// this class and called startListening() — check that before anything
/// else. Grep your project for `DistressSmsListenerService(` — if the
/// only hits are in this file and the background handler, it's never
/// wired up.
///
/// ⚠️ ADJUST before relying on this in production:
/// - `DistressSignalService.resolveRosterIdByPhone` assumes a
///   `profiles.phone_number` column in the sender's raw format. Normalize
///   both sides (e.g. strip to last 10 digits) if numbers don't match
///   as-is.
/// - `DistressSignalService.fetchActiveDrillEventId` assumes a `status`
///   column on `drill_events`. Point it at your real "is this drill live
///   right now" check.
/// - `onBackgroundMessage` must stay a top-level or static function per
///   the telephony plugin's requirement, and Supabase must already be
///   initialized before it can run (it will be, since `main()` calls
///   `Supabase.initialize` before `runApp`).
class DistressSmsListenerService {
  DistressSmsListenerService({
    DistressSignalService? service,
    LocalDistressSignalStore? localStore,
  })  : _service = service ?? DistressSignalService(),
        _localStore = localStore ?? LocalDistressSignalStore.instance;

  final Telephony _telephony = Telephony.instance;
  final DistressSignalService _service;
  final LocalDistressSignalStore _localStore;

  Future<bool> requestPermissions() async {
    final granted = await _telephony.requestPhoneAndSmsPermissions;
    debugPrint('[DistressSms] requestPermissions -> $granted');
    return granted ?? false;
  }

  /// Call once, early (e.g. in main() after Supabase.initialize, or when
  /// the teacher/admin enables SMS monitoring for a drill).
  void startListening() {
    debugPrint('[DistressSms] startListening() called — registering listenIncomingSms');
    _telephony.listenIncomingSms(
      onNewMessage: _handleIncomingSms,
      onBackgroundMessage: _backgroundMessageHandler,
      listenInBackground: true,
    );
  }

  Future<void> _handleIncomingSms(SmsMessage message) async {
    final body = message.body;
    final sender = message.address;
    debugPrint('[DistressSms] onNewMessage from=$sender body=$body');
    if (body == null || sender == null) {
      debugPrint('[DistressSms] ignored: null body or sender');
      return;
    }
    if (!DistressSmsTemplate.looksLikeDistress(body)) {
      debugPrint('[DistressSms] ignored: does not start with "${DistressSmsTemplate.keyword}"');
      return;
    }

    // Wrapped so a foreground failure (parse edge case, local store error,
    // sync error not otherwise caught) doesn't die silently — previously
    // an uncaught throw anywhere in this chain would just stop, with no
    // trace of why, which is exactly what was happening with
    // fetchActiveDrillEventId below.
    try {
      await _fileDistressFromSms(sender: sender, body: body);
    } catch (e, st) {
      debugPrint('[DistressSms] _handleIncomingSms: _fileDistressFromSms threw: $e');
      debugPrint(st.toString());
    }
  }

  Future<void> _fileDistressFromSms({required String sender, required String body}) async {
    final parsed = DistressSmsTemplate.parse(body);
    debugPrint('[DistressSms] parsed lat=${parsed.latitude} lng=${parsed.longitude} '
        'building=${parsed.building} floor=${parsed.floor} message=${parsed.message}');

    // 1) Save locally first. This guarantees the SOS is recorded on-device
    //    even if step 2 below fails (unknown sender, no active drill,
    //    device offline, Supabase error, etc).
    final localId = await _localStore.insertPending(
      sender: sender,
      rawBody: body,
      identifier: parsed.identifier,
      latitude: parsed.latitude,
      longitude: parsed.longitude,
      building: parsed.building,
      floor: parsed.floor,
      message: parsed.message ?? body,
    );
    debugPrint('[DistressSms] saved locally, localId=$localId'
        ' — if the screen shows nothing at all, but you see this line, the'
        ' listener IS firing and the bug is downstream (sync/Supabase side).'
        ' If you never see this line for a test text, the listener itself'
        ' isn\'t registered/permitted — see startListening()/requestPermissions().');

    // 2) Try to resolve + push to Supabase right away.
    await _trySync(localId);
  }

  Future<void> _trySync(int localId) async {
    final pending = await _localStore.getById(localId);
    if (pending == null || pending.synced) return;

    String? rosterId;
    try {
      rosterId = await _service.resolveRosterIdByPhone(pending.sender);
    } catch (e) {
      // Don't let a phone-lookup failure (bad column, network blip) take
      // down the whole sync — the identifier fallback below can still
      // resolve it.
      debugPrint('[DistressSms] resolveRosterIdByPhone threw: $e');
    }

    try {
      rosterId ??= await _service.resolveRosterId(
        schoolIdNumber: pending.identifier,
        fullName: pending.identifier,
      );
    } catch (e, st) {
      // Same reasoning as resolveRosterIdByPhone above — a lookup failure
      // here shouldn't kill the sync outright. Falls through with
      // rosterId still null, which the studentName fallback below handles.
      debugPrint('[DistressSms] resolveRosterId threw: $e');
      debugPrint(st.toString());
    }

    // ⚠️ THIS WAS THE SILENT-DEATH POINT: previously unwrapped, so any
    // exception here (RLS rejection on drill_events, network error,
    // Postgrest error, session not yet restored in this isolate) would
    // propagate uncaught all the way up through _fileDistressFromSms and
    // _handleIncomingSms/_backgroundMessageHandler, killing the whole
    // chain with zero trace — exactly matching "log stops dead right
    // after the fetchActiveDrillEventId call line, no result, no error".
    String? drillEventId;
    try {
      drillEventId = await _service.fetchActiveDrillEventId();
    } catch (e, st) {
      debugPrint('[DistressSms] _trySync: fetchActiveDrillEventId THREW localId=$localId: $e');
      debugPrint(st.toString());
      return; // stays pending — syncPending() will retry later
    }

    if (drillEventId == null) {
      debugPrint('[DistressSms] _trySync STOP localId=$localId: no active drill_event');
      return; // no active drill — stays pending, nothing to file this against yet
    }

    // Roster resolution failing no longer blocks filing the signal — an
    // unresolved SOS showing up with just the typed name/ID is far more
    // useful to a teacher than one silently stuck in local storage.
    // roster_id is nullable on the table specifically for this case. If
    // there's no identifier either (a bare "SOS" with nothing else), fall
    // back to the raw sender number so it's still visible on screen.
    final studentName = rosterId == null ? (pending.identifier ?? pending.sender) : null;
    if (rosterId == null) {
      debugPrint('[DistressSms] _trySync: roster unresolved for sender=${pending.sender}, '
          'filing with student_name="$studentName" instead');
    }

    try {
      final row = await _service.createSignal(
        drillEventId: drillEventId,
        rosterId: rosterId,
        studentName: studentName,
        channel: DistressChannel.sms,
        latitude: pending.latitude,
        longitude: pending.longitude,
        building: pending.building,
        floor: pending.floor,
        message: pending.message,
      );
      await _localStore.markSynced(localId, row.id);
      debugPrint('[DistressSms] _trySync SUCCESS localId=$localId -> remoteId=${row.id}');
    } catch (e, st) {
      // Offline or insert failed for some other reason — leave pending,
      // syncPending() will retry later. createSignal() above now logs the
      // actual Supabase error before this catch, so check the console for
      // the real cause (RLS, FK violation, etc).
      debugPrint('[DistressSms] _trySync FAILED localId=$localId: $e');
      debugPrint(st.toString());
    }
  }

  /// Retries filing every locally-cached signal that hasn't reached
  /// Supabase yet. Safe to call repeatedly (e.g. on connectivity regained,
  /// app resume, or pull-to-refresh) — already-synced rows are skipped.
  Future<void> syncPending() async {
    final pending = await _localStore.getUnsynced();
    debugPrint('[DistressSms] syncPending: ${pending.length} unsynced rows');
    for (final p in pending) {
      await _trySync(p.localId);
    }
  }
}

/// Must be a top-level (or static) function — the telephony plugin invokes
/// this in a separate isolate when a message arrives while the app is
/// backgrounded or killed.
@pragma('vm:entry-point')
void _backgroundMessageHandler(SmsMessage message) async {
  final body = message.body;
  final sender = message.address;
  debugPrint('[DistressSms][background isolate] onBackgroundMessage from=$sender body=$body');
  if (body == null || sender == null) return;
  if (!DistressSmsTemplate.looksLikeDistress(body)) return;

  // Supabase must be re-initialized in this isolate — it doesn't share
  // state with the foreground one. Do that here before using the client,
  // e.g.:
  //   await Supabase.initialize(url: ..., anonKey: ...);
  // The local sqlite save below works regardless — sqflite has no such
  // isolate restriction — so the SOS is captured on-device even if
  // Supabase re-init or the network is unavailable at this moment; the
  // next syncPending() call picks it up.
  //
  // Wrapped in try/catch so a failure in this isolate (Supabase not
  // re-initialized, RLS rejection, network error) prints instead of
  // vanishing — a background isolate crash otherwise leaves zero trace
  // in the log beyond this first debugPrint line.
  try {
    await DistressSmsListenerService()._fileDistressFromSms(sender: sender, body: body);
  } catch (e, st) {
    debugPrint('[DistressSms][background isolate] _fileDistressFromSms threw: $e');
    debugPrint(st.toString());
  }
}