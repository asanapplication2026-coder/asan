import 'dart:io';
import 'package:excel/excel.dart' as xls;
import 'supabase_client.dart';
import '../models/app_profile.dart';
import '../models/section.dart';
import '../models/parsed_roster_row.dart';

class SectionService {
  // -------------------------------------------------------------------
  // ADMIN — section shell creation
  // -------------------------------------------------------------------

  /// Admin creates a section shell. Roster is empty at this point —
  /// status starts as 'unrostered' (DB default) and flips to 'rostered'
  /// automatically via trigger once the adviser adds the first student.
  Future<AppSection> createSection({
    required String name,
    required String yearLevel,
    required int numberOfStudents,
    required String adviserId,
  }) async {
    final currentAdminId = supabase.auth.currentUser?.id;
    if (currentAdminId == null) {
      throw Exception('Not signed in.');
    }

    final row = await supabase
        .from('sections')
        .insert({
      'name': name,
      'year_level': yearLevel,
      'number_of_students': numberOfStudents,
      'adviser_id': adviserId,
      'created_by': currentAdminId,
    })
        .select()
        .single();

    return AppSection.fromMap(row);
  }

  /// For the adviser dropdown on the create-section screen — only
  /// approved teachers should be selectable.
  Future<List<AppProfile>> fetchApprovedTeachers() async {
    final rows = await supabase
        .from('profiles')
        .select()
        .eq('role', 'teacher')
        .eq('approval_status', 'approved')
        .order('full_name');

    return (rows as List).map((r) => AppProfile.fromMap(r)).toList();
  }

  /// Admin overview — every section, rostered or not, so gaps are
  /// visible before a drill ever happens.
  Future<List<AppSection>> fetchAllSections() async {
    final rows = await supabase.from('sections').select().order('year_level');
    return (rows as List).map((r) => AppSection.fromMap(r)).toList();
  }

  /// Used by the student screen to show their own section's details.
  /// Relies on the student_read_own_section RLS policy — a student
  /// can only successfully fetch their own section_id, not any other.
  Future<AppSection?> fetchSectionById(String sectionId) async {
    final row = await supabase.from('sections').select().eq('id', sectionId).maybeSingle();
    if (row == null) return null;
    return AppSection.fromMap(row);
  }

  // -------------------------------------------------------------------
  // ADMIN — roster management (pre-loading who's allowed to sign up)
  // -------------------------------------------------------------------

  /// Admin pre-loads a person into the roster before they can sign up.
  /// This is the "vouching" step — signup fails without a matching,
  /// unclaimed row here (see AuthService.signUp).
  Future<void> addRosterEntry({
    required String schoolIdNumber,
    required String fullName,
    required String role, // 'admin' | 'teacher' | 'student'
    String? sectionId,
  }) async {
    await supabase.from('roster').insert({
      'school_id_number': schoolIdNumber,
      'full_name': fullName,
      'role': role,
      'section_id': sectionId,
    });
  }

  /// Admin-wide roster view — every person added, any role, any
  /// section, claimed or not. Relies on the admin_all_roster RLS
  /// policy (FOR ALL, no filter) to return everything.
  Future<List<RosterEntry>> fetchAllRosterEntries() async {
    final rows = await supabase.from('roster').select().order('full_name');
    return (rows as List).map((r) => RosterEntry.fromMap(r)).toList();
  }

  /// Generic admin bulk import — used for BOTH teacher-only and
  /// student-only imports, distinguished by [role] and [sectionId].
  /// Teachers: pass sectionId: null (roster.section_id stays null).
  /// Students: pass the target section — every row in the file goes
  /// into that one section, matching the same single-target pattern
  /// as the teacher-side importStudentsFromExcel below.
  /// Same two-column expectation: school ID number, then full name,
  /// with a header row skipped.
  /// Step 1 of the admin bulk import flow: reads the file and validates
  /// each row, but writes nothing to Supabase. Used to populate the
  /// review modal so an admin can catch bad rows before anything is
  /// committed. Same two-column expectation as before: school ID
  /// number, then full name, with the header row skipped.
  Future<List<ParsedRosterRow>> parseRosterExcel({
    required String filePath,
  }) async {
    final bytes = File(filePath).readAsBytesSync();
    final workbook = xls.Excel.decodeBytes(bytes);
    final sheet = workbook.tables[workbook.tables.keys.first];
    if (sheet == null) return [];

    final results = <ParsedRosterRow>[];
    final seenIds = <String>{}; // catch duplicates within the file itself

    final dataRows = sheet.rows.skip(1).toList(); // skip header row
    for (var i = 0; i < dataRows.length; i++) {
      final row = dataRows[i];
      // Excel row number for the admin's reference: +1 for 1-based,
      // +1 again since we skipped the header row.
      final excelRowNumber = i + 2;

      // Wrapped defensively, same as the original import: a single
      // malformed/merged/unexpected cell can throw inside the excel
      // package's own parsing before our null checks even run. One
      // bad row is flagged, not allowed to abort the whole parse.
      try {
        final schoolId = row.elementAtOrNull(0)?.value?.toString().trim() ?? '';
        final fullName = row.elementAtOrNull(1)?.value?.toString().trim() ?? '';

        String? error;
        if (schoolId.isEmpty && fullName.isEmpty) {
          error = 'Empty row';
        } else if (schoolId.isEmpty) {
          error = 'Missing school ID';
        } else if (fullName.isEmpty) {
          error = 'Missing full name';
        } else if (seenIds.contains(schoolId)) {
          error = 'Duplicate school ID within this file';
        }
        seenIds.add(schoolId);

        results.add(ParsedRosterRow(
          rowIndex: excelRowNumber,
          schoolId: schoolId,
          fullName: fullName,
          error: error,
        ));
      } catch (_) {
        results.add(ParsedRosterRow(
          rowIndex: excelRowNumber,
          schoolId: '',
          fullName: '',
          error: 'Could not read this row',
        ));
      }
    }

    return results;
  }

  /// Step 2: inserts only the rows the admin kept checked in the review
  /// modal. This is the same insert logic the old importRosterFromExcel
  /// used, just fed pre-reviewed rows instead of re-parsing the file.
  Future<int> commitRosterImport({
    required String role, // 'teacher' | 'student'
    String? sectionId,
    required List<ParsedRosterRow> rows,
  }) async {
    if (rows.isEmpty) return 0;

    final rowsToInsert = rows
        .map((r) => {
      'school_id_number': r.schoolId,
      'full_name': r.fullName,
      'role': role,
      'section_id': sectionId,
    })
        .toList();

    await supabase.from('roster').insert(rowsToInsert);
    return rowsToInsert.length;
  }

  /// Reconciliation check — flags sections whose roster count hasn't
  /// caught up to the expected number_of_students yet.
  Future<int> countRosterForSection(String sectionId) async {
    final rows = await supabase.from('roster').select('id').eq('section_id', sectionId);
    return (rows as List).length;
  }

  // -------------------------------------------------------------------
  // TEACHER — rostering a section already created by admin
  // -------------------------------------------------------------------

  /// Sections where the current teacher is the assigned adviser.
  /// (Subject-teacher assignments via section_teachers are a separate
  /// follow-up, not included in this pass.)
  Future<List<AppSection>> fetchMySections() async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return [];

    final rows = await supabase.from('sections').select().eq('adviser_id', uid).order('name');
    return (rows as List).map((r) => AppSection.fromMap(r)).toList();
  }

  Future<List<RosterEntry>> fetchRoster(String sectionId) async {
    final rows = await supabase
        .from('roster')
        .select()
        .eq('section_id', sectionId)
        .order('full_name');

    return (rows as List).map((r) => RosterEntry.fromMap(r)).toList();
  }

  Future<void> addStudentManual({
    required String sectionId,
    required String schoolIdNumber,
    required String fullName,
  }) async {
    await supabase.from('roster').insert({
      'school_id_number': schoolIdNumber,
      'full_name': fullName,
      'role': 'student',
      'section_id': sectionId,
    });
  }

  /// Parses an .xlsx file entirely on-device (no upload) and expects
  /// two columns per row: school ID number, full name. Adjust the
  /// column indices below if your school's template differs.
  Future<int> importStudentsFromExcel({
    required String sectionId,
    required String filePath,
  }) async {
    final bytes = File(filePath).readAsBytesSync();
    final workbook = xls.Excel.decodeBytes(bytes);
    final sheet = workbook.tables[workbook.tables.keys.first];
    if (sheet == null) return 0;

    final rowsToInsert = <Map<String, dynamic>>[];

    for (final row in sheet.rows.skip(1)) { // skip header row
      try {
        final schoolId = row.elementAtOrNull(0)?.value?.toString().trim();
        final fullName = row.elementAtOrNull(1)?.value?.toString().trim();
        if (schoolId == null || schoolId.isEmpty || fullName == null || fullName.isEmpty) {
          continue; // skip blank/malformed rows rather than failing the whole import
        }
        rowsToInsert.add({
          'school_id_number': schoolId,
          'full_name': fullName,
          'role': 'student',
          'section_id': sectionId,
        });
      } catch (_) {
        continue; // skip this row, keep processing the rest of the file
      }
    }

    if (rowsToInsert.isEmpty) return 0;

    await supabase.from('roster').insert(rowsToInsert);
    return rowsToInsert.length;
  }
}