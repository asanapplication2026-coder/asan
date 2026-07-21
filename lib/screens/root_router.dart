import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/auth/auth_controller.dart';
import 'admin/admin_dashboard_screen.dart';
import 'admin/admin_root_screen.dart';
import 'auth/login_screen.dart';
import 'teacher/teacher_dashboard_screen.dart';
import 'student/student_home_screen.dart';

/// Single reactive router — Obx rebuilds this whenever currentUser or
/// profile changes on AuthController, so no manual navigation calls
/// are needed after sign in/out anywhere else in the app.
class RootRouter extends StatelessWidget {
  const RootRouter({super.key});

  @override
  Widget build(BuildContext context) {
    final authController = Get.find<AuthController>();

    return Obx(() {
      if (authController.currentUser.value == null) {
        return LoginScreen();
      }

      // Styled loading state to use your brand's primaryRed
      if (authController.isLoadingProfile.value) {
        return const Scaffold(
          body: Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(primaryRed),
            ),
          ),
        );
      }

      final profile = authController.profile.value;

      // RESOLVED TODO: Changed buttons, icons, and text actions to primaryRed
      if (profile == null) {
        return Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.account_circle_outlined,
                    size: 64,
                    color: primaryRed, // Premium brand indicator
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No profile found for this account. Contact an admin.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: primaryRed,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () => authController.signOut(),
                    child: const Text('Sign Out'),
                  ),
                ],
              ),
            ),
          ),
        );
      }

      // Styled waiting state using your brand's primaryRed
      if (!profile.isApproved) {
        return Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.hourglass_empty_rounded,
                    size: 64,
                    color: primaryRed, // Warm, branded pending accent
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Hi ${profile.fullName}, your account is waiting on admin approval.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: primaryRed,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () => authController.signOut(),
                    child: const Text('Sign Out'),
                  ),
                ],
              ),
            ),
          ),
        );
      }

      // Inside RootRouter build method
      if (profile.isAdmin) return const AdminRootScreen();
      if (profile.isTeacher) return const TeacherDashboardScreen();
      if (profile.isStudent) return const StudentHomeScreen();

      // Any role outside admin/teacher/student falls through here —
      // shouldn't happen given the app's three defined roles, but
      // fail visibly rather than silently looping.
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  size: 64,
                  color: primaryRed,
                ),
                const SizedBox(height: 16),
                Text(
                  'Unrecognized role for ${profile.fullName}.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: primaryRed,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => authController.signOut(),
                  child: const Text('Sign Out'),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }
}