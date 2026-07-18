import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:file_selector/file_selector.dart';
import '../services/section_service.dart';
import '../services/local_roster_cache.dart';
import '../models/section.dart';
import '../models/parsed_roster_row.dart';
import 'teacher_section_controller.dart';
import 'auth_controller.dart';

/// Roster management scoped to sections the signed-in teacher advises.
///
/// Mirrors AdminRosterController's add / bulk-import / review-before-commit
/// flow, but with two hard restrictions baked in:
///   - `role` is always 'student' — advisors only ever roster their own
///     students, never teachers or admins.
///   - the section picker only ever lists sections from
///     `TeacherSectionController.mySections` (i.e. sections where
///     `adviser_id` = this teacher), never the full school.
///
/// ⚠️ SECURITY NOTE: the scoping above is a client-side convenience for
/// a good UI, not a security boundary. It calls the same
/// `fetchAllRosterEntries()` the admin screen uses and filters the
/// result down to this teacher's sections in Dart. The real restriction
/// needs to live in a Supabase RLS policy on `roster` (and ideally
/// `sections`) — e.g. SELECT/INSERT/UPDATE only where
/// `sections.adviser_id = auth.uid()` for non-admin roles. Please add
/// that policy if it isn't already in place; otherwise a modified
/// client could still read or write other sections' rosters.
///
/// ⚠️ ADJUST: `_teacherId` and the cache's toJson/fromJson below assume
/// field names inferred from admin_roster_controller.dart and the SQL
/// schema. Line these up with your actual AuthController / RosterEntry
/// if they differ.
class TeacherRosterController extends GetxController {
  final _sectionService = SectionService();

  late final LocalRosterCache<RosterEntry> _cache = LocalRosterCache<RosterEntry>(
    toJson: (r) => {
      'id': r.id,
      'schoolIdNumber': r.schoolIdNumber,
      'fullName': r.fullName,
      'role': r.role,
      'sectionId': r.sectionId,
      'claimed': r.claimed,
    },
    fromJson: (m) => RosterEntry(
      id: m['id'] as String,
      schoolIdNumber: m['schoolIdNumber'] as String,
      fullName: m['fullName'] as String,
      role: m['role'] as String,
      sectionId: m['sectionId'] as String?,
      claimed: m['claimed'] as bool? ?? false,
    ),
  );

  final RxList<RosterEntry> roster = <RosterEntry>[].obs;
  final RxBool isLoading = false.obs;
  final RxnString errorMessage = RxnString();
  final RxBool isShowingCachedData = false.obs;

  // Add-entry form state (no role field — always 'student')
  final schoolIdController = TextEditingController();
  final fullNameController = TextEditingController();
  final Rxn<String> selectedSectionId = Rxn<String>();
  final RxBool isSaving = false.obs;
  final RxnString formError = RxnString();

  // Bulk Excel import — same staged-review pattern as admin
  final RxBool isImportingStudents = false.obs;
  final RxList<ParsedRosterRow> stagedRows = <ParsedRosterRow>[].obs;
  final RxBool isParsingImport = false.obs;

  // ⚠️ ADJUST to however AuthController exposes the signed-in profile.
  String get _teacherId => Get.find<AuthController>().profile.value!.id;

  /// Sections this teacher advises. Sourced from TeacherSectionController
  /// (already loaded by the dashboard) rather than re-fetched here, so
  /// there's exactly one place "my sections" comes from.
  List<AppSection> get mySections => Get.find<TeacherSectionController>().mySections;

  @override
  void onInit() {
    super.onInit();
    if (mySections.isNotEmpty) selectedSectionId.value = mySections.first.id;
    _loadRoster();
  }

  Future<void> _loadRoster() async {
    isLoading.value = true;
    errorMessage.value = null;
    isShowingCachedData.value = false;
    final sectionIds = mySections.map((s) => s.id).toSet();

    try {
      final all = await _sectionService.fetchAllRosterEntries();
      final scoped = all.where((r) => sectionIds.contains(r.sectionId)).toList();
      roster.assignAll(scoped);
      await _cache.save(_teacherId, scoped);
    } catch (e) {
      final cached = await _cache.load(_teacherId);
      roster.assignAll(cached);
      isShowingCachedData.value = cached.isNotEmpty;
      errorMessage.value = cached.isEmpty
          ? 'Failed to load roster: $e'
          : 'Could not refresh — showing your last saved roster.';
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> refresh() => _loadRoster();

  bool _sectionIsMine(String? sectionId) =>
      sectionId != null && mySections.any((s) => s.id == sectionId);

  Future<bool> submitNewEntry() async {
    formError.value = null;
    final schoolId = schoolIdController.text.trim();
    final fullName = fullNameController.text.trim();

    if (schoolId.isEmpty) {
      formError.value = 'School ID number is required.';
      return false;
    }
    if (fullName.isEmpty) {
      formError.value = 'Full name is required.';
      return false;
    }
    if (!_sectionIsMine(selectedSectionId.value)) {
      formError.value = 'Select one of your own sections.';
      return false;
    }

    isSaving.value = true;
    try {
      await _sectionService.addRosterEntry(
        schoolIdNumber: schoolId,
        fullName: fullName,
        role: 'student',
        sectionId: selectedSectionId.value,
      );
      schoolIdController.clear();
      fullNameController.clear();
      await refresh();
      return true;
    } catch (e) {
      formError.value = 'Failed to add: $e';
      return false;
    } finally {
      isSaving.value = false;
    }
  }

  Future<void> pickAndParseRosterExcel() async {
    if (!_sectionIsMine(selectedSectionId.value)) {
      Get.snackbar('Select a section', 'Choose one of your sections before importing.');
      return;
    }

    const excelGroup = XTypeGroup(label: 'Excel Files', extensions: <String>['xlsx']);
    final file = await openFile(acceptedTypeGroups: <XTypeGroup>[excelGroup]);
    final path = file?.path;
    if (path == null) return;

    isParsingImport.value = true;
    formError.value = null;
    try {
      final rows = await _sectionService.parseRosterExcel(filePath: path);
      final existingIds = roster.map((r) => r.schoolIdNumber).toSet();
      for (var i = 0; i < rows.length; i++) {
        final row = rows[i];
        if (row.error == null && existingIds.contains(row.schoolId)) {
          rows[i] = ParsedRosterRow(
            rowIndex: row.rowIndex,
            schoolId: row.schoolId,
            fullName: row.fullName,
            error: "School ID already exists in this section's roster",
          );
        }
      }
      stagedRows.assignAll(rows);
    } catch (e) {
      Get.snackbar('Error', 'Could not read file: $e');
    } finally {
      isParsingImport.value = false;
    }
  }

  Future<void> confirmStagedImport() async {
    if (!_sectionIsMine(selectedSectionId.value)) return;
    final kept = stagedRows.where((r) => r.include && r.isValid).toList();
    if (kept.isEmpty) return;

    isImportingStudents.value = true;
    try {
      final count = await _sectionService.commitRosterImport(
        role: 'student',
        sectionId: selectedSectionId.value,
        rows: kept,
      );
      Get.back();
      Get.snackbar(
        'Imported',
        '$count student${count == 1 ? '' : 's'} added.',
        duration: const Duration(seconds: 2),
      );
      cancelStagedImport();
      await refresh();
    } catch (e) {
      Get.snackbar('Error', 'Import failed: $e');
    } finally {
      isImportingStudents.value = false;
    }
  }

  void cancelStagedImport() {
    stagedRows.clear();
  }

  void updateStagedRow(int index, {String? schoolId, String? fullName}) {
    if (index < 0 || index >= stagedRows.length) return;
    final current = stagedRows[index];
    stagedRows[index] = current.copyWith(
      schoolId: schoolId ?? current.schoolId,
      fullName: fullName ?? current.fullName,
    );
    _revalidateStagedRows();
  }

  void _revalidateStagedRows() {
    final existingIds = roster.map((r) => r.schoolIdNumber).toSet();
    final idCounts = <String, int>{};
    for (final r in stagedRows) {
      final id = r.schoolId.trim();
      if (id.isEmpty) continue;
      idCounts[id] = (idCounts[id] ?? 0) + 1;
    }
    for (var i = 0; i < stagedRows.length; i++) {
      final r = stagedRows[i];
      final id = r.schoolId.trim();
      final name = r.fullName.trim();
      String? error;
      if (id.isEmpty && name.isEmpty) {
        error = 'Empty row';
      } else if (id.isEmpty) {
        error = 'Missing school ID';
      } else if (name.isEmpty) {
        error = 'Missing full name';
      } else if ((idCounts[id] ?? 0) > 1) {
        error = 'Duplicate school ID within this file';
      } else if (existingIds.contains(id)) {
        error = "School ID already exists in this section's roster";
      }
      if (error != r.error) {
        stagedRows[i] = r.copyWith(error: error, clearError: error == null);
      }
    }
  }

  @override
  void onClose() {
    schoolIdController.dispose();
    fullNameController.dispose();
    super.onClose();
  }
}