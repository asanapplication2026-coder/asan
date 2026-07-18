class AppSection {
  final String id;
  final String name;
  final String? yearLevel;
  final int? numberOfStudents;
  final String? adviserId;
  final String status; // 'unrostered' | 'rostered'

  AppSection({
    required this.id,
    required this.name,
    this.yearLevel,
    this.numberOfStudents,
    this.adviserId,
    required this.status,
  });

  factory AppSection.fromMap(Map<String, dynamic> map) {
    return AppSection(
      id: map['id'] as String,
      name: map['name'] as String,
      yearLevel: map['year_level'] as String?,
      numberOfStudents: map['number_of_students'] as int?,
      adviserId: map['adviser_id'] as String?,
      status: map['status'] as String? ?? 'unrostered',
    );
  }

  bool get isRostered => status == 'rostered';
}

class RosterEntry {
  final String id;
  final String schoolIdNumber;
  final String fullName;
  final String role;
  final String? sectionId;
  final bool claimed;

  RosterEntry({
    required this.id,
    required this.schoolIdNumber,
    required this.fullName,
    required this.role,
    this.sectionId,
    required this.claimed,
  });

  factory RosterEntry.fromMap(Map<String, dynamic> map) {
    return RosterEntry(
      id: map['id'] as String,
      schoolIdNumber: map['school_id_number'] as String,
      fullName: map['full_name'] as String,
      role: map['role'] as String,
      sectionId: map['section_id'] as String?,
      claimed: map['claimed'] as bool? ?? false,
    );
  }
}