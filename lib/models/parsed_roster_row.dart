/// A single row extracted from an uploaded roster Excel file, before it is
/// committed to Supabase. Produced by `SectionService.parseRosterExcel`
/// and displayed in the import review modal so an admin can catch bad
/// rows (blank names, duplicate IDs, wrong column order) before anything
/// is written to the database.
class ParsedRosterRow {
  /// 1-based row number in the source file (header row excluded), used to
  /// point the admin at the exact spot in Excel if something looks wrong.
  final int rowIndex;

  final String schoolId;
  final String fullName;

  /// Null when the row is valid. Otherwise a short, human-readable reason
  /// it was flagged, e.g. "Missing full name" or "Duplicate school ID
  /// (also row 14)".
  final String? error;

  /// Whether this row is checked for inclusion in the final import.
  /// Defaults to true for valid rows; invalid rows start unchecked and
  /// their checkbox is disabled until the underlying issue is fixed
  /// upstream (i.e. the admin re-uploads a corrected file).
  bool include;

  ParsedRosterRow({
    required this.rowIndex,
    required this.schoolId,
    required this.fullName,
    this.error,
    bool? include,
  }) : include = include ?? (error == null);

  bool get isValid => error == null;

  ParsedRosterRow copyWith({
    String? error,
    bool? include,
    String? fullName,
    String? schoolId,
    bool clearError = false,
  }) {
    return ParsedRosterRow(
      rowIndex: rowIndex,
      schoolId: schoolId ?? this.schoolId,
      fullName: fullName ?? this.fullName,
      error: clearError ? null : error,
      include: include ?? this.include,
    );
  }
}
