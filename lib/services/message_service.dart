import 'supabase_client.dart';
import '../models/message.dart';

/// All Supabase access for the messages table lives here. Controllers
/// never call `supabase.from(...)` directly — they go through this,
/// same separation your AuthService already establishes for auth/profile.
class MessageService {
  /// Live stream of a section's messages, oldest first. RLS on the
  /// `messages` table determines which rows actually come through —
  /// this method doesn't need to know or enforce that itself.
  Stream<List<Message>> streamSectionMessages(String sectionId) {
    return supabase
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('section_id', sectionId)
    // IMPORTANT: on the realtime stream builder, order() defaults to
    // ascending: false (unlike the plain query builder, which defaults
    // to true). Without this explicit flag, rows come back newest
    // first, which breaks the reversed ListView in chat_screen.dart.
        .order('created_at', ascending: true)
        .map((rows) => rows.map(Message.fromMap).toList());
  }

  Future<void> sendMessage({
    required String sectionId,
    required String senderId,
    required String content,
    String? drillEventId,
    String messageType = 'text',
  }) async {
    await supabase.from('messages').insert({
      'section_id': sectionId,
      if (drillEventId != null) 'drill_event_id': drillEventId,
      'sender_id': senderId,
      'content': content,
      'message_type': messageType,
    });
  }

  /// Looks up full_name for a set of profile IDs. `.stream()` can't
  /// join to profiles, so the controller calls this once per batch of
  /// unseen sender IDs and caches the result locally instead of
  /// re-querying per message.
  Future<Map<String, String>> fetchSenderNames(List<String> ids) async {
    if (ids.isEmpty) return {};
    final rows = await supabase
        .from('profiles')
        .select('id, full_name')
        .inFilter('id', ids);

    return {
      for (final row in rows) row['id'] as String: row['full_name'] as String,
    };
  }
}