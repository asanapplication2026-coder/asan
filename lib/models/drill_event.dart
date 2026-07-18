/// Mirrors public.drill_events. Adjust the enum values below if your
/// Postgres `event_type` / `disaster_type` / `drill_status` enums use
/// different labels than what's assumed here — the .name values must
/// match the DB enum labels exactly since they're written straight in.
library;

enum DrillEventType { drill, emergency }

enum DisasterType { fire, earthquake, flood, intruder, typhoon, other }

enum DrillStatus { active, ended }

DrillEventType drillEventTypeFromString(String? value) {
  switch (value) {
    case 'emergency':
      return DrillEventType.emergency;
    case 'drill':
    default:
      return DrillEventType.drill;
  }
}

DisasterType? disasterTypeFromString(String? value) {
  if (value == null) return null;
  return DisasterType.values.firstWhere(
        (e) => e.name == value,
    orElse: () => DisasterType.other,
  );
}

DrillStatus drillStatusFromString(String? value) {
  switch (value) {
    case 'ended':
      return DrillStatus.ended;
    case 'active':
    default:
      return DrillStatus.active;
  }
}

class DrillEvent {
  final String id;
  final String name;
  final DrillEventType eventType;
  final DisasterType? disasterType;
  final DrillStatus status;
  final DateTime startedAt;
  final DateTime? endedAt;
  final String createdBy;

  DrillEvent({
    required this.id,
    required this.name,
    required this.eventType,
    required this.status,
    required this.startedAt,
    required this.createdBy,
    this.disasterType,
    this.endedAt,
  });

  factory DrillEvent.fromMap(Map<String, dynamic> map) {
    return DrillEvent(
      id: map['id'] as String,
      name: map['name'] as String,
      eventType: drillEventTypeFromString(map['event_type'] as String?),
      disasterType: disasterTypeFromString(map['disaster_type'] as String?),
      status: drillStatusFromString(map['status'] as String?),
      startedAt: DateTime.parse(map['started_at'] as String),
      endedAt: map['ended_at'] != null
          ? DateTime.parse(map['ended_at'] as String)
          : null,
      createdBy: map['created_by'] as String,
    );
  }

  bool get isActive => status == DrillStatus.active;
}