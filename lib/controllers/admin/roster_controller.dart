import 'package:file_selector/file_selector.dart';
import 'package:get/get.dart';
import '../../services/section_service.dart';
import '../../models/section.dart';

/// One instance per section — put with `tag: section.id` so navigating
/// to different sections' roster screens doesn't share state.
class RosterController extends GetxController {
  final AppSection section;
  RosterController(this.section);

  final _sectionService = SectionService();

  final RxList<RosterEntry> roster = <RosterEntry>[].obs;
  final RxBool isLoading = false.obs;
  final RxBool isImporting = false.obs;
  final RxnString statusMessage = RxnString();

  @override
  void onInit() {
    super.onInit();
    fetchRoster();
  }

  Future<void> fetchRoster() async {
    isLoading.value = true;
    try {
      final result = await _sectionService.fetchRoster(section.id);
      roster.assignAll(result);
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> addStudent({required String schoolIdNumber, required String fullName}) async {
    try {
      await _sectionService.addStudentManual(
        sectionId: section.id,
        schoolIdNumber: schoolIdNumber,
        fullName: fullName,
      );
      await fetchRoster();
      return true;
    } catch (e) {
      statusMessage.value = 'Failed to add student: $e';
      return false;
    }
  }

  Future<void> importFromExcel() async {
    // Replaced file_picker with file_selector XTypeGroup
    const XTypeGroup excelGroup = XTypeGroup(
      label: 'Excel Files',
      extensions: <String>['xlsx'],
    );

    final XFile? file = await openFile(
      acceptedTypeGroups: <XTypeGroup>[excelGroup],
    );

    final path = file?.path;
    if (path == null) return;

    isImporting.value = true;
    statusMessage.value = null;
    try {
      final count = await _sectionService.importStudentsFromExcel(
        sectionId: section.id,
        filePath: path,
      );
      statusMessage.value = 'Imported $count student${count == 1 ? '' : 's'}.';
      await fetchRoster();
    } catch (e) {
      statusMessage.value = 'Import failed: $e';
    } finally {
      isImporting.value = false;
    }
  }
}