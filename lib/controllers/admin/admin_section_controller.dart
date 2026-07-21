import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../services/section_service.dart';
import '../../models/app_profile.dart';
import '../../models/section.dart';

class AdminSectionController extends GetxController {
  final _sectionService = SectionService();

  final RxList<AppSection> sections = <AppSection>[].obs;
  final RxBool isLoading = false.obs;
  final RxnString errorMessage = RxnString();

  @override
  void onInit() {
    super.onInit();
    fetchSections();
  }

  Future<void> fetchSections() async {
    isLoading.value = true;
    errorMessage.value = null;
    try {
      final result = await _sectionService.fetchAllSections();
      sections.assignAll(result);
    } catch (e) {
      errorMessage.value = 'Failed to load sections: $e';
    } finally {
      isLoading.value = false;
    }
  }
}

/// Separate controller for the create-section form — kept apart from
/// AdminSectionController so the form's transient state (validation,
/// saving) doesn't live alongside the dashboard's list state.
class CreateSectionController extends GetxController {
  final _sectionService = SectionService();

  final formKey = GlobalKey<FormState>();
  final nameController = TextEditingController();
  final countController = TextEditingController();
  final Rxn<String> selectedYearLevel = Rxn<String>();
  final Rxn<String> selectedAdviserId = Rxn<String>();

  final RxList<AppProfile> teachers = <AppProfile>[].obs;
  final RxBool isLoadingTeachers = false.obs;
  final RxBool isSaving = false.obs;
  final RxnString errorMessage = RxnString();

  static const yearLevels = [
    'Grade 7', 'Grade 8', 'Grade 9', 'Grade 10', 'Grade 11', 'Grade 12',
  ];

  @override
  void onInit() {
    super.onInit();
    _loadTeachers();
  }

  Future<void> _loadTeachers() async {
    isLoadingTeachers.value = true;
    try {
      final result = await _sectionService.fetchApprovedTeachers();
      teachers.assignAll(result);
    } finally {
      isLoadingTeachers.value = false;
    }
  }

  /// Returns true on success. Screen is responsible for popping/showing
  /// the error — this keeps the controller UI-framework-agnostic aside
  /// from the TextEditingControllers it already owns.
  Future<bool> submit() async {
    errorMessage.value = null;

    if (nameController.text.trim().isEmpty) {
      errorMessage.value = 'Section name is required.';
      return false;
    }
    final count = int.tryParse(countController.text.trim());
    if (count == null || count < 0) {
      errorMessage.value = 'Enter a valid number of students.';
      return false;
    }
    if (selectedYearLevel.value == null) {
      errorMessage.value = 'Select a year level.';
      return false;
    }
    if (selectedAdviserId.value == null) {
      errorMessage.value = 'Select an adviser.';
      return false;
    }

    isSaving.value = true;
    try {
      await _sectionService.createSection(
        name: nameController.text.trim(),
        yearLevel: selectedYearLevel.value!,
        numberOfStudents: count,
        adviserId: selectedAdviserId.value!,
      );
      return true;
    } catch (e) {
      errorMessage.value = 'Failed to create section: $e';
      return false;
    } finally {
      isSaving.value = false;
    }
  }

  @override
  void onClose() {
    nameController.dispose();
    countController.dispose();
    super.onClose();
  }
}