import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import '../controllers/auth_controller.dart';
import '../screens/teacher/drill_sectio_select_screen.dart';
import '../services/drill_service.dart';
import '../services/push_notification_service.dart';

/// Wires PushNotificationService.onDrillNotificationTap to real
/// navigation. Call [setup] once, after runApp (e.g. right after
/// GetMaterialApp is built, or at the end of main() — anywhere that
/// runs after `Get.key` exists).
///
/// Kept separate from PushNotificationService itself so that service
/// stays a plain FCM wrapper with zero GetX/screen imports.
class DrillNotificationRouter {
  DrillNotificationRouter._();

  static void setup() {
    PushNotificationService.onDrillNotificationTap = _handleTap;
  }

  static Future<void> _handleTap(String drillEventId) async {
    // A cold start (app opened directly by tapping the notification)
    // can call this before GetMaterialApp has finished mounting, so
    // Get.key.currentState is briefly null. Wait for it instead of
    // silently dropping the navigation.
    for (var attempt = 0; attempt < 25; attempt++) {
      if (Get.key.currentState != null) break;
      await Future.delayed(const Duration(milliseconds: 200));
    }
    if (Get.key.currentState == null) {
      if (kDebugMode) {
        debugPrint('DrillNotificationRouter: navigator never became ready, dropping navigation');
      }
      return;
    }

    try {
      final drillEvent = await DrillService().fetchDrillEventById(drillEventId);
      if (drillEvent == null) {
        if (kDebugMode) debugPrint('DrillNotificationRouter: drill $drillEventId not found');
        return;
      }

      final role = _currentUserRole();
      switch (role) {
        case 'teacher':
          Get.to(() => DrillSectionSelectScreen(drillEvent: drillEvent));
          break;
      // TODO: 'admin' -> an admin-facing live drill monitoring screen
      // TODO: 'student' -> a student-facing status/distress screen
        default:
          if (kDebugMode) {
            debugPrint('DrillNotificationRouter: no drill screen wired up for role "$role" yet');
          }
      }
    } catch (e, st) {
      debugPrint('DrillNotificationRouter: failed to open drill from notification: $e');
      debugPrint('$st');
    }
  }

  /// ⚠️ ADJUST: assumes AuthController exposes `Rxn<AppProfile> profile`
  /// the same way the rest of the teacher feature does.
  static String? _currentUserRole() {
    try {
      return Get.find<AuthController>().profile.value?.role;
    } catch (_) {
      return null;
    }
  }
}