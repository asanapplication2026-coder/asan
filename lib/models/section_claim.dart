class SectionClaim {
  final String id;
  final String drillEventId;
  final String sectionId;
  final String teacherId;
  final String teacherName;
  final DateTime claimedAt;

  SectionClaim({
    required this.id,
    required this.drillEventId,
    required this.sectionId,
    required this.teacherId,
    required this.teacherName,
    required this.claimedAt,
  });

  /// Expects the row to come from a query that embeds the teacher's
  /// name, e.g. `.select('*, teacher:teacher_id(full_name)')`.
  factory SectionClaim.fromMap(Map<String, dynamic> map) {
    final teacher = map['teacher'] as Map<String, dynamic>?;
    return SectionClaim(
      id: map['id'] as String,
      drillEventId: map['drill_event_id'] as String,
      sectionId: map['section_id'] as String,
      teacherId: map['teacher_id'] as String,
      teacherName: teacher?['full_name'] as String? ?? 'Unknown teacher',
      claimedAt: DateTime.parse(map['claimed_at'] as String),
    );
  }
}

/// Thrown by DrillService.claimSection when the section is already
/// taken by someone else — callers should catch this specifically and
/// treat it as "lost the race", not as a generic failure.
class SectionAlreadyClaimedException implements Exception {
  final SectionClaim claim;
  SectionAlreadyClaimedException(this.claim);

  @override
  String toString() => 'Already claimed by ${claim.teacherName}';
}