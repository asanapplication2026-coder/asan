import 'package:asan_evac_app/screens/onboarding/onboading_screen.dart';
import 'package:asan_evac_app/screens/root_router.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../services/local_storage_service.dart';

/// Checked once at startup — not reactive, since "have I seen
/// onboarding" doesn't change while the app is running. Once
/// completeOnboarding() runs it navigates away via Get.offAll, so
/// this widget never needs to re-check itself.
class AppEntryPoint extends StatelessWidget {
  const AppEntryPoint({super.key});

  @override
  Widget build(BuildContext context) {
    final hasSeenOnboarding = Get.find<LocalStorageService>().hasSeenOnboarding;
    return hasSeenOnboarding ? const RootRouter() : const OnboardingScreen();
  }
}
