import 'dart:async';
import 'package:get/get.dart';
import '../../services/admin_approval_service.dart';
import '../../models/app_profile.dart';

class AdminApprovalController extends GetxController {
  final _approvalService = AdminApprovalService();

  /// Kept as the name existing screens reference — holds whatever the
  /// *currently selected filter* returned from the DB, e.g. only pending
  /// rows while viewing the Pending tab, only approved while viewing
  /// Approved, etc. This is a real server-side filter, not a client-side
  /// one — switching tabs issues a fresh request.
  final RxList<AppProfile> pending = <AppProfile>[].obs;
  final RxBool isLoading = false.obs;
  final RxnString errorMessage = RxnString();
  // Tracks which specific row is mid-approval/-rejection, so only that
  // row's button shows a spinner rather than the whole list.
  final RxnString approvingId = RxnString();

  // UI label -> DB column value.
  static const Map<String, String> _statusByLabel = {
    'Pending': 'pending',
    'Approved': 'approved',
    'Rejected': 'rejected',
  };

  final RxString currentFilter = 'Pending'.obs;

  /// Total pending count, independent of which tab is currently being
  /// viewed — used for the notification badge on the "Accounts" segment.
  final RxInt pendingCount = 0.obs;

  @override
  void onInit() {
    super.onInit();
    fetchPending();
    refreshPendingCount();
  }

  /// Fetches accounts for [filterLabel] ('Pending', 'Approved', 'Rejected')
  /// straight from the DB. Pass nothing to re-fetch the current filter.
  Future<void> fetchPending([String? filterLabel]) async {
    final label = filterLabel ?? currentFilter.value;
    currentFilter.value = label;

    isLoading.value = true;
    errorMessage.value = null;
    try {
      final result = await _approvalService.fetchProfiles(
        status: _statusByLabel[label],
      );
      pending.assignAll(result);
    } catch (e) {
      errorMessage.value = 'Failed to load accounts: $e';
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> approve(String profileId) async {
    approvingId.value = profileId;
    try {
      await _approvalService.approveProfile(profileId);
      // This account no longer belongs in the tab being viewed (Pending) —
      // drop it locally instead of a full re-fetch.
      pending.removeWhere((p) => p.id == profileId);
      unawaited(refreshPendingCount());
    } catch (e) {
      Get.snackbar('Error', 'Failed to approve: $e');
    } finally {
      approvingId.value = null;
    }
  }

  Future<void> reject(String profileId) async {
    approvingId.value = profileId;
    try {
      await _approvalService.rejectProfile(profileId);
      pending.removeWhere((p) => p.id == profileId);
      unawaited(refreshPendingCount());
    } catch (e) {
      Get.snackbar('Error', 'Failed to reject: $e');
    } finally {
      approvingId.value = null;
    }
  }

  Future<void> refreshPendingCount() async {
    try {
      pendingCount.value = await _approvalService.countPending();
    } catch (_) {
      // Non-critical — badge just won't update this cycle.
    }
  }
}