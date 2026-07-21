import 'package:get/get.dart';
import '../../services/section_service.dart';
import '../../models/section.dart';
import '../auth/auth_controller.dart';

class StudentController extends GetxController {
  final _sectionService = SectionService();

  final Rxn<AppSection> section = Rxn<AppSection>();
  final RxList<RosterEntry> classmates = <RosterEntry>[].obs;
  final RxBool isLoading = false.obs;
  final RxnString errorMessage = RxnString();

  @override
  void onInit() {
    super.onInit();
    _load();
  }

  Future<void> _load() async {
    final sectionId = Get.find<AuthController>().profile.value?.sectionId;
    if (sectionId == null) {
      errorMessage.value = 'Your account isn\'t linked to a section yet — contact an admin.';
      return;
    }

    isLoading.value = true;
    errorMessage.value = null;
    try {
      final results = await Future.wait([
        _sectionService.fetchSectionById(sectionId),
        _sectionService.fetchRoster(sectionId),
      ]);
      section.value = results[0] as AppSection?;
      classmates.assignAll(results[1] as List<RosterEntry>);
    } catch (e) {
      errorMessage.value = 'Failed to load your section: $e';
    } finally {
      isLoading.value = false;
    }
  }

  @override
  Future<void> refresh() => _load();
}