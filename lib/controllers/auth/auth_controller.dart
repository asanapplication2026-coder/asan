import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/auth_service.dart';
import '../../services/push_notification_service.dart';
import '../../models/app_profile.dart';

class AuthController extends GetxController {
  final _authService = AuthService();

  final Rxn<User> currentUser = Rxn<User>();
  final Rxn<AppProfile> profile = Rxn<AppProfile>();
  final RxBool isLoadingProfile = false.obs;

  /// Set when completeSignupIfPending() fails — e.g. the roster row
  /// was claimed by someone else while email confirmation was
  /// pending. RootRouter/UI should route to a "contact admin" screen
  /// rather than looping the retry silently.
  final RxnString signupCompletionError = RxnString();

  bool _pushInitialized = false;

  @override
  void onInit() {
    super.onInit();
    currentUser.value = _authService.currentUser;
    _refreshProfile();

    _authService.authStateChanges.listen((_) {
      currentUser.value = _authService.currentUser;
      _refreshProfile();
    });
  }

  Future<void> _refreshProfile() async {
    if (currentUser.value == null) {
      profile.value = null;
      signupCompletionError.value = null;
      _pushInitialized = false;
      return;
    }
    isLoadingProfile.value = true;
    try {
      profile.value = await _authService.fetchCurrentProfile();

      if (profile.value == null) {
        // Authenticated but no profile row — likely first sign-in
        // right after confirming email. Try to finish the deferred
        // roster claim.
        try {
          final completed = await _authService.completeSignupIfPending();
          if (completed) {
            profile.value = await _authService.fetchCurrentProfile();
            signupCompletionError.value = null;
          }
          // If completed == false, there was genuinely nothing
          // pending (e.g. an admin-created account with no
          // school_id_number metadata) — leave profile null,
          // let RootRouter's existing "no profile" handling apply.
        } on SignupCompletionException catch (e) {
          profile.value = null;
          signupCompletionError.value = e.message;
        }
      }
    } finally {
      isLoadingProfile.value = false;
    }

    _initPushNotificationsOnce();
  }

  Future<void> _initPushNotificationsOnce() async {
    if (_pushInitialized) return;
    _pushInitialized = true;

    await PushNotificationService.instance.initialize();
    final status = await PushNotificationService.instance.getPermissionStatus();

    if (status == AuthorizationStatus.notDetermined) {
      await _showNotificationPermissionDialog();
    } else {
      await PushNotificationService.instance.requestPermissionAndSubscribe();
    }
  }

  Future<void> _showNotificationPermissionDialog() async {
    await Get.dialog(
      AlertDialog(
        title: const Text('Stay informed'),
        content: const Text(
          "Turn on notifications to get instant alerts when a drill "
              "or real emergency starts at your school.",
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('Not now')),
          FilledButton(
            onPressed: () async {
              Get.back();
              await PushNotificationService.instance.requestPermissionAndSubscribe();
            },
            child: const Text('Allow Notifications'),
          ),
        ],
      ),
      barrierDismissible: false,
    );
  }

  Future<void> refreshProfile() => _refreshProfile();

  Future<void> signOut() => _authService.signOut();

  bool isValidEmail(String email) => GetUtils.isEmail(email);
}