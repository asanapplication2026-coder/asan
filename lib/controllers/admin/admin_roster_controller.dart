import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:file_selector/file_selector.dart';
import '../../services/section_service.dart';
import '../../models/section.dart';
import '../../models/parsed_roster_row.dart';

class AdminRosterController extends GetxController {
  final _sectionService = SectionService();

  final RxList<RosterEntry> roster = <RosterEntry>[].obs;
  final RxList<AppSection> sections = <AppSection>[].obs;
  final RxBool isLoading = false.obs;
  final RxnString errorMessage = RxnString();

  // Add-entry form state
  final schoolIdController = TextEditingController();
  final fullNameController = TextEditingController();
  final Rx<String> selectedRole = 'student'.obs;
  final Rxn<String> selectedSectionId = Rxn<String>();
  final RxBool isSaving = false.obs;
  final RxnString formError = RxnString();

  // Bulk Excel import state — separate flags so the two import
  // buttons can show independent loading states.
  final RxBool isImportingTeachers = false.obs;
  final RxBool isImportingStudents = false.obs;

  // Bulk Excel import — review-before-commit state. Picking a file now
  // only parses it into `stagedRows`; nothing hits Supabase until the
  // admin reviews the modal and calls confirmStagedImport().
  final RxList<ParsedRosterRow> stagedRows = <ParsedRosterRow>[].obs;
  final RxBool isParsingImport = false.obs;
  String? _pendingImportRole; // 'teacher' | 'student', set while staged

  static const roles = ['admin', 'teacher', 'student'];

  @override
  void onInit() {
    super.onInit();
    _loadAll();
  }

  Future<void> _loadAll() async {
    isLoading.value = true;
    errorMessage.value = null;
    try {
      final results = await Future.wait([
        _sectionService.fetchAllRosterEntries(),
        _sectionService.fetchAllSections(),
      ]);
      roster.assignAll(results[0] as List<RosterEntry>);
      sections.assignAll(results[1] as List<AppSection>);
    } catch (e) {
      errorMessage.value = 'Failed to load roster: $e';
    } finally {
      isLoading.value = false;
    }
  }

  @override
  Future<void> refresh() => _loadAll();

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
    if (selectedRole.value == 'student' && selectedSectionId.value == null) {
      formError.value = 'Select a section for this student.';
      return false;
    }

    isSaving.value = true;
    try {
      await _sectionService.addRosterEntry(
        schoolIdNumber: schoolId,
        fullName: fullName,
        role: selectedRole.value,
        sectionId: selectedSectionId.value,
      );
      // Reset form for the next entry rather than closing — admins
      // typically add several people in a row (e.g. a whole class list).
      schoolIdController.clear();
      fullNameController.clear();
      selectedSectionId.value = null;
      await refresh();
      return true;
    } catch (e) {
      formError.value = 'Failed to add: $e';
      return false;
    } finally {
      isSaving.value = false;
    }
  }

  @override
  void onClose() {
    schoolIdController.dispose();
    fullNameController.dispose();
    super.onClose();
  }

  // -----------------------------------------------------------------
  // BULK EXCEL IMPORT — teacher-only and student-only, both funnel
  // into SectionService.importRosterFromExcel with different args.
  // Uses file_selector's openFile()/XTypeGroup, matching the same
  // pattern as RosterController.importFromExcel().
  // -----------------------------------------------------------------

  /// Step 1 of the import flow: pick a file and parse it into
  /// [stagedRows] for review. Nothing is written to Supabase here —
  /// call [confirmStagedImport] after the admin reviews the modal.
  ///
  /// [role] is 'teacher' or 'student'. Students require a target
  /// section to already be selected, same as before.
  Future<void> pickAndParseRosterExcel(String role) async {
    if (role == 'student' && selectedSectionId.value == null) {
      Get.snackbar('Select a section', 'Choose a target section before importing students.');
      return;
    }

    const XTypeGroup excelGroup = XTypeGroup(
      label: 'Excel Files',
      extensions: <String>['xlsx'],
    );

    final XFile? file = await openFile(acceptedTypeGroups: <XTypeGroup>[excelGroup]);
    final path = file?.path;
    if (path == null) return;

    isParsingImport.value = true;
    formError.value = null;
    try {
      final rows = await _sectionService.parseRosterExcel(filePath: path);
      // Flag duplicates against school IDs already present in the
      // currently-loaded roster, in addition to whatever row-level
      // validation parseRosterExcel already did (blank fields etc).
      final existingIds = roster.map((r) => r.schoolIdNumber).toSet();
      for (var i = 0; i < rows.length; i++) {
        final row = rows[i];
        if (row.error == null && existingIds.contains(row.schoolId)) {
          rows[i] = ParsedRosterRow(
            rowIndex: row.rowIndex,
            schoolId: row.schoolId,
            fullName: row.fullName,
            error: 'School ID already exists in roster',
          );
        }
      }
      stagedRows.assignAll(rows);
      _pendingImportRole = role;
    } catch (e) {
      Get.snackbar('Error', 'Could not read file: $e');
    } finally {
      isParsingImport.value = false;
    }
  }

  /// Step 2: commit whichever staged rows are still checked and valid.
  /// Called by the review modal's "Import" button.
  Future<void> confirmStagedImport() async {
    final role = _pendingImportRole;
    if (role == null) return;

    final kept = stagedRows.where((r) => r.include && r.isValid).toList();
    if (kept.isEmpty) return;

    final isTeacher = role == 'teacher';
    isTeacher ? isImportingTeachers.value = true : isImportingStudents.value = true;
    try {
      final count = await _sectionService.commitRosterImport(
        role: role,
        sectionId: isTeacher ? null : selectedSectionId.value,
        rows: kept,
      );
      Get.back(); // close the review modal
      Get.snackbar('Imported', '$count ${isTeacher ? 'teacher' : 'student'}${count == 1 ? '' : 's'} added.',
          duration: const Duration(seconds: 2));
      cancelStagedImport();
      await refresh();
    } catch (e) {
      Get.snackbar('Error', '${isTeacher ? 'Teacher' : 'Student'} import failed: $e');
    } finally {
      isTeacher ? isImportingTeachers.value = false : isImportingStudents.value = false;
    }
  }

  /// Discards the staged rows without writing anything — called from the
  /// review modal's "Cancel" button, and after a successful commit.
  void cancelStagedImport() {
    stagedRows.clear();
    _pendingImportRole = null;
  }

  /// Called from the review modal whenever the admin edits a staged
  /// row's school ID or full name in place.
  ///
  /// The screen used to clear a row's error itself, guessing based on
  /// whether the old error message happened to contain the word "ID"
  /// or "name". That's not real validation — e.g. both "School ID
  /// already exists in roster" and "Duplicate school ID within this
  /// file" contain "ID", so editing the ID field to literally anything
  /// non-empty wiped either error, even if the new value was still a
  /// duplicate. This replaces that guesswork with a real re-check
  /// against the live roster and the rest of the staged list, run
  /// after every edit so no row's error can go stale.
  void updateStagedRow(int rowIndexInList, {String? schoolId, String? fullName}) {
    if (rowIndexInList < 0 || rowIndexInList >= stagedRows.length) return;

    final current = stagedRows[rowIndexInList];
    stagedRows[rowIndexInList] = current.copyWith(
      schoolId: schoolId ?? current.schoolId,
      fullName: fullName ?? current.fullName,
    );

    _revalidateAllStagedRows();
  }

  /// Re-derives every staged row's `error` from scratch against the
  /// live roster and the rest of the staged list. This mirrors the
  /// same rules [pickAndParseRosterExcel] applies at parse time, just
  /// re-run on demand after an in-modal edit instead of only once.
  void _revalidateAllStagedRows() {
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
        error = 'School ID already exists in roster';
      }

      if (error != r.error) {
        stagedRows[i] = r.copyWith(error: error, clearError: error == null);
      }
    }
  }
}