import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/distress_signal_model.dart';

/// Thrown when a distress signal operation fails. Kept distinct from
/// PostgrestException so the Controller layer can show a friendly
/// message without depending on Supabase types.
class DistressSignalException implements Exception {
  DistressSignalException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Service layer for `public.distress_signals`.
///
/// IMPORTANT — how the 3 channels reach this table:
///   • channel = 'app'         -> written directly by this app (SOS button)
///     via [sendAppDistressSignal].
///   • channel = 'sms'         -> written by a backend integration
///     (e.g. a Supabase Edge Function / Twilio webhook) that parses
///     an inbound SMS and inserts a row with channel='sms'.
///   • channel = 'missed_call' -> written the same way, by a backend
///     integration that receives the missed-call/IVR webhook.
///
/// The Flutter app does NOT need to talk to Twilio/SMS gateways
/// directly — it only needs to read+subscribe to this table, which is
/// why [fetchForDrillEvent] and [streamForDrillEvent] return rows
/// regardless of channel. Only the 'app' channel is ever inserted
/// from this client.
class DistressSignalService {
  DistressSignalService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;
  static const String _table = 'distress_signals';

  /// One-time fetch of all distress signals for a drill/event, most
  /// recent first.
  Future<List<DistressSignalModel>> fetchForDrillEvent(
      String drillEventId,
      ) async {
    try {
      final rows = await _client
          .from(_table)
          .select()
          .eq('drill_event_id', drillEventId)
          .order('created_at', ascending: false);

      return (rows as List)
          .map((row) => DistressSignalModel.fromJson(row as Map<String, dynamic>))
          .toList();
    } on PostgrestException catch (e) {
      throw DistressSignalException('Failed to load distress signals: ${e.message}');
    } catch (e) {
      throw DistressSignalException('Failed to load distress signals: $e');
    }
  }

  /// Realtime stream of every distress signal for a drill/event. Fires
  /// again whenever a new row is inserted (app SOS, SMS, or missed
  /// call), so the UI stays live without polling.
  Stream<List<DistressSignalModel>> streamForDrillEvent(String drillEventId) {
    return _client
        .from(_table)
        .stream(primaryKey: ['id'])
        .eq('drill_event_id', drillEventId)
        .order('created_at', ascending: false)
        .map(
          (rows) => rows
          .map((row) => DistressSignalModel.fromJson(row))
          .toList(),
    );
  }

  /// Inserts an in-app SOS signal (channel is always forced to 'app'
  /// here — SMS/missed_call rows are never created from the client).
  Future<DistressSignalModel> sendAppDistressSignal({
    required String drillEventId,
    required String studentId,
    double? latitude,
    double? longitude,
    String? building,
    String? floor,
    String? message,
  }) async {
    final payload = DistressSignalModel(
      id: '',
      drillEventId: drillEventId,
      studentId: studentId,
      channel: DistressChannel.app,
      latitude: latitude,
      longitude: longitude,
      building: building,
      floor: floor,
      message: message,
      createdAt: DateTime.now(),
    ).toInsertJson();

    try {
      final inserted = await _client
          .from(_table)
          .insert(payload)
          .select()
          .single();
      return DistressSignalModel.fromJson(inserted);
    } on PostgrestException catch (e) {
      throw DistressSignalException('Failed to send SOS: ${e.message}');
    } catch (e) {
      throw DistressSignalException('Failed to send SOS: $e');
    }
  }

  /// Optional: lets a teacher/admin mark a signal resolved/deleted
  /// once the student is confirmed safe.
  Future<void> deleteSignal(String id) async {
    try {
      await _client.from(_table).delete().eq('id', id);
    } on PostgrestException catch (e) {
      throw DistressSignalException('Failed to clear signal: ${e.message}');
    }
  }
}