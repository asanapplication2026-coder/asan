import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;
import '../../services/drill_service.dart';
import '../../services/section_service.dart';
import '../../models/drill_event.dart';
import '../../models/section.dart';
import '../../models/section_claim.dart';
import '../auth/auth_controller.dart';

/// Backs the "pick a section to handle during this drill" screen.
/// Loads EVERY section in the school (not just ones this teacher
/// advises — any teacher can step in during an emergency), plus the
/// current claims for this drill event.
///
/// Rules:
///  * A section can be claimed by several teachers at once.
///  * A teacher can claim at most [maxClaimsPerTeacher] sections per
///    drill. The limit is enforced by a DB trigger; the client-side
///    check here only gives instant feedback.
///
/// ⚠️ ADJUST: `_teacherId` assumes `AuthController.profile` the same
/// way TeacherRosterController does — line these up if that's wrong.
class SectionClaimController extends GetxController {
  SectionClaimController(this.drillEvent);

  static const int maxClaimsPerTeacher = DrillService.maxClaimsPerTeacher;

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

  /// All claims this teacher currently holds in this drill.
  List<SectionClaim> get myClaims =>
      claims.where((c) => c.teacherId == _teacherId).toList();

  int get myClaimCount => myClaims.length;

  bool get canClaimMore => myClaimCount < maxClaimsPerTeacher;

  bool isClaimedByMe(String sectionId) =>
      claims.any((c) => c.sectionId == sectionId && c.teacherId == _teacherId);

  /// Claims on [sectionId] held by teachers other than me.
  List<SectionClaim> othersFor(String sectionId) => claims
      .where((c) => c.sectionId == sectionId && c.teacherId != _teacherId)
      .toList();

  void _showLimitSnackbar() => Get.snackbar(
    'Limit reached',
    'You can handle at most $maxClaimsPerTeacher sections.',
  );

  /// Returns the claim on success, or null if claiming failed (a
  /// snackbar has already been shown either way — nothing more to do
  /// on the caller's end for the failure path).
  Future<SectionClaim?> claimSection(String sectionId) async {
    if (!canClaimMore) {
      _showLimitSnackbar();
      return null;
    }

    isClaiming.value = true;
    try {
      final claim = await _drillService.claimSection(
        drillEventId: drillEvent.id,
        sectionId: sectionId,
        teacherId: _teacherId,
      );
      claims.add(claim);
      return claim;
    } on PostgrestException catch (e) {
      // Resync with the database so the UI reflects reality, whatever
      // the reason for the rejection was.
      await refresh();
      if (e.message.contains('MAX_CLAIMS_REACHED')) {
        // Local state was stale (e.g. claimed from another device).
        _showLimitSnackbar();
      } else if (e.code == '23505' &&
          e.message.contains('esa_unique_teacher_section')) {
        Get.snackbar('Already claimed', 'You already claimed this section.');
      } else {
        // Includes any OTHER unique violation (e.g. a leftover
        // one-claim-per-teacher constraint) — the message names it.
        Get.snackbar('Error', 'Could not claim section: ${e.message}');
      }
      return null;
    } catch (e) {
      Get.snackbar('Error', 'Could not claim section: $e');
      return null;
    } finally {
      isClaiming.value = false;
    }
  }
}
