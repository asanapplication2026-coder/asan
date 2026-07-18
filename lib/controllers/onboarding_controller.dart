import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../services/local_storage_service.dart';
import '../screens/root_router.dart';

class OnboardingPageData {
  final IconData icon;
  final String title;
  final String description;
  const OnboardingPageData({required this.icon, required this.title, required this.description});
}

class OnboardingController extends GetxController {
  final RxInt currentPage = 0.obs;
  final PageController pageController = PageController();

  final List<OnboardingPageData> pages = const [
    OnboardingPageData(
      icon: Icons.shield_outlined,
      title: 'Stay Safe, Stay Informed',
      description: 'Quick headcount and status updates during school drills and emergencies.',
    ),
    OnboardingPageData(
      icon: Icons.groups_outlined,
      title: 'Built for Admins, Teachers, and Students',
      description: 'Each role sees exactly what they need — nothing more, nothing confusing.',
    ),
    OnboardingPageData(
      icon: Icons.check_circle_outline,
      title: 'One Tap Confirms You\'re Safe',
      description: 'Fast and simple, with fallback options in mind for weak signal.',
    ),
  ];

  bool get isLastPage => currentPage.value == pages.length - 1;

  void onPageChanged(int index) => currentPage.value = index;

  void nextOrFinish() {
    if (isLastPage) {
      completeOnboarding();
    } else {
      pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    }
  }

  Future<void> completeOnboarding() async {
    await Get.find<LocalStorageService>().setOnboardingSeen();
    Get.offAll(() => const RootRouter());
  }

  @override
  void onClose() {
    pageController.dispose();
    super.onClose();
  }
}