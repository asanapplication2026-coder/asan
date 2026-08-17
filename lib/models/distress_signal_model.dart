/// Mirrors the `distress_channel` Postgres enum on `public.distress_signals`.
enum DistressChannel {
  app('app'),
  sms('sms'),
  missedCall('missed_call');

  const DistressChannel(this.value);
  final String value;

  static DistressChannel fromValue(String value) {
    return DistressChannel.values.firstWhere(
          (c) => c.value == value,
      orElse: () => DistressChannel.app,
    );
  }
}

/// A single row from `public.distress_signals`.
///
/// One signal = one distress event, regardless of how it arrived
/// (in-app SOS button, an SMS the device received, or a missed call).
class DistressSignal {
  DistressSignal({
    required this.id,
    required this.drillEventId,
    required this.channel,
    required this.createdAt,
    this.rosterId,
    this.studentName,
    this.latitude,
    this.longitude,
    this.building,
    this.floor,
    this.message,
  }) : assert(
  rosterId != null || studentName != null,
  'A signal needs either a resolved rosterId or a studentName fallback',
  );

  final String id;
  final String drillEventId;

  /// Null when the sender couldn't be resolved to a roster entry (unknown
  /// phone, and no identifier in the SMS matched — see
  /// DistressSignalService.resolveRosterId). [studentName] is the fallback
  /// for display in that case.
  final String? rosterId;

  /// Whatever identifier the student typed (school ID or name), stored
  /// verbatim as a fallback so an unresolved signal still shows *someone*
  /// on screen instead of being unfileable.
  final String? studentName;

  final DistressChannel channel;
  final double? latitude;
  final double? longitude;
  final String? building;
  final String? floor;
  final String? message;
  final DateTime createdAt;

  bool get hasCoordinates => latitude != null && longitude != null;
  bool get isResolved => rosterId != null;

  factory DistressSignal.fromMap(Map<String, dynamic> map) {
    return DistressSignal(
      id: map['id'] as String,
      drillEventId: map['drill_event_id'] as String,
      rosterId: map['roster_id'] as String?,
      studentName: map['student_name'] as String?,
      channel: DistressChannel.fromValue(map['channel'] as String),
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      building: map['building'] as String?,
      floor: map['floor'] as String?,
      message: map['message'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  /// Payload for `INSERT` — deliberately excludes `id` and `created_at`,
  /// which the database generates.
  Map<String, dynamic> toInsertMap() {
    return {
      'drill_event_id': drillEventId,
      'channel': channel.value,
      if (rosterId != null) 'roster_id': rosterId,
      if (studentName != null) 'student_name': studentName,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (building != null) 'building': building,
      if (floor != null) 'floor': floor,
      if (message != null) 'message': message,
    };
  }
}