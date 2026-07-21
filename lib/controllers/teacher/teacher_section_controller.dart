import 'package:get/get.dart';
import '../../services/section_service.dart';
import '../../models/section.dart';

class TeacherSectionController extends GetxController {
  final _sectionService = SectionService();

  final RxList<AppSection> mySections = <AppSection>[].obs;
  final RxBool isLoading = false.obs;
  final RxnString errorMessage = RxnString();

  @override
  void onInit() {
    super.onInit();
    fetchMySections();
  }

  Future<void> fetchMySections() async {
    isLoading.value = true;
    errorMessage.value = null;
    try {
      final result = await _sectionService.fetchMySections();
      mySections.assignAll(result);
    } catch (e) {
      errorMessage.value = 'Failed to load sections: $e';
    } finally {
      isLoading.value = false;
    }
  }
}