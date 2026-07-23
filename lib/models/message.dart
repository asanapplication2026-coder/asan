/// Maps to public.messages. Kept intentionally dumb — no Supabase or
/// GetX imports here, so it can be used from service, controller, and
/// view layers without pulling in unrelated dependencies.
class Message {
  final String id;
  final String sectionId;
  final String? drillEventId;
  final String senderId;
  final String messageType; // 'text' by default — matches message_type enum
  final String content;
  final DateTime createdAt;

  const Message({
    required this.id,
    required this.sectionId,
    required this.senderId,
    required this.messageType,
    required this.content,
    required this.createdAt,
    this.drillEventId,
  });

  factory Message.fromMap(Map<String, dynamic> map) {
    return Message(
      id: map['id'] as String,
      sectionId: map['section_id'] as String,
      drillEventId: map['drill_event_id'] as String?,
      senderId: map['sender_id'] as String,
      messageType: map['message_type'] as String? ?? 'text',
      content: map['content'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  /// Fields needed for an insert — id/created_at are DB-generated.
  Map<String, dynamic> toInsertMap() => {
    'section_id': sectionId,
    if (drillEventId != null) 'drill_event_id': drillEventId,
    'sender_id': senderId,
    'message_type': messageType,
    'content': content,
  };
}