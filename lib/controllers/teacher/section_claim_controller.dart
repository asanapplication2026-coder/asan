import 'package:get/get.dart';
import '../../services/drill_service.dart';
import '../../services/section_service.dart';
import '../../models/drill_event.dart';
import '../../models/section.dart';
import '../../models/section_claim.dart';
import '../auth/auth_controller.dart';

/// Backs the "pick a section to handle during this drill" screen.
/// Loads EVERY section in the school (not just ones this teacher
/// advises — any teacher can step in during an emergency), plus the
/// current claims for this drill event, so the UI can show each
/// section as unclaimed / claimed-by-you / claimed-by-someone-else.
///
/// ⚠️ ADJUST: `_teacherId` assumes `AuthController.profile` the same
/// way TeacherRosterController does — line these up if that's wrong.
class SectionClaimController extends GetxController {
  SectionClaimController(this.drillEvent);

  final DrillEvent drillEvent;
  final _drillService = DrillService();
  final _sectionService = SectionService();

  final RxList<AppSection> allSections = <AppSection>[].obs;
  final RxList<SectionClaim> claims = <SectionClaim>[].obs;
  final RxBool isLoading = false.obs;
  final RxnString errorMessage = RxnString();
  final RxBool isClaiming = false.obs;

  String get _teacherId => Get.find<AuthController>().profile.value!.id;

  @override
  void onInit() {
    super.onInit();
    _load();
  }

  Future<void> _load() async {
    isLoading.value = true;
    errorMessage.value = null;
    try {
      final results = await Future.wait([
        _sectionService.fetchAllSections(),
        _drillService.fetchClaimsForDrill(drillEvent.id),
      ]);
      allSections.assignAll(results[0] as List<AppSection>);
      claims.assignAll(results[1] as List<SectionClaim>);
    } catch (e) {
      errorMessage.value = 'Failed to load sections: $e';
    } finally {
      isLoading.value = false;
    }
  }

  @override
  Future<void> refresh() => _load();

  SectionClaim? claimFor(String sectionId) {
    for (final c in claims) {
      if (c.sectionId == sectionId) return c;
    }
    return null;
  }

  bool isClaimedByMe(String sectionId) => claimFor(sectionId)?.teacherId == _teacherId;

  /// Returns the claim on success, or null if claiming failed (a
  /// snackbar has already been shown either way — nothing more to do
  /// on the caller's end for the failure path).
  Future<SectionClaim?> claimSection(String sectionId) async {
    isClaiming.value = true;
    try {
      final claim = await _drillService.claimSection(
        drillEventId: drillEvent.id,
        sectionId: sectionId,
        teacherId: _teacherId,
      );
      claims.add(claim);
      return claim;
    } on SectionAlreadyClaimedException catch (e) {
      // Someone else claimed it in the gap between our list load and
      // this tap — refresh so the UI reflects reality.
      await refresh();
      Get.snackbar('Already Claimed', 'This section is now handled by ${e.claim.teacherName}.');
      return null;
    } catch (e) {
      Get.snackbar('Error', 'Could not claim section: $e');
      return null;
    } finally {
      isClaiming.value = false;
    }
  }
}