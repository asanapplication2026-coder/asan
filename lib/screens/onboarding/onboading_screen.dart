import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:asan_evac_app/generated/assets.dart';
import '../../controllers/onboarding/onboarding_controller.dart';
import '../admin/admin_dashboard_screen.dart'; // Retained for primaryRed

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  late final OnboardingController controller;
  Timer? _autoSlideTimer;

  // Premium "Lux Gold" Gradient (Vibrant yellow to warm amber)
  static const goldGradient = LinearGradient(
    colors: [Color(0xFFFFDF00), Color(0xFFF1A80A)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  @override
  void initState() {
    super.initState();
    controller = Get.put(OnboardingController());
    _startAutoSlide();
  }

  // Starts the auto-sliding routine
  void _startAutoSlide() {
    _autoSlideTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (controller.pageController.hasClients) {
        int nextPage = controller.currentPage.value + 1;
        if (nextPage >= controller.pages.length) {
          nextPage = 0; // Loop seamlessly back to the first slide
        }
        controller.pageController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  // Intercepts manual swipes to reset the timer for smooth UX
  void _handlePageChanged(int index) {
    controller.onPageChanged(index);
    _autoSlideTimer?.cancel();
    _startAutoSlide();
  }

  @override
  void dispose() {
    _autoSlideTimer?.cancel(); // Eradicates background memory leaks
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Dynamic iOS System Colors
    final backgroundColor = CupertinoColors.systemBackground.resolveFrom(
      context,
    );
    CupertinoColors.systemGrey5.resolveFrom(context);

    return CupertinoPageScaffold(
      backgroundColor: backgroundColor,
      child: Stack(
        children: [
          // 1. Premium Ambient Background Layer
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    primaryRed.withValues(alpha: 0.06), // Soft brand glow
                    backgroundColor,
                    backgroundColor,
                  ],
                ),
              ),
            ),
          ),

          // 2. Elegant Background Watermark Logo
          Positioned(
            right: -40,
            top: 60,
            child: Opacity(
              opacity: 0.05,
              child: SizedBox(
                width: 260,
                height: 260,
                child: Assets.asanLogo.image(fit: BoxFit.contain),
              ),
            ),
          ),

          // 3. Dynamic Interactive UI Layer
          Positioned.fill(
            child: Material(
              color: Colors.transparent,
              child: SafeArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Premium Skip Button (iOS Style)
                    Align(
                      alignment: Alignment.topRight,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 8.0, right: 16.0),
                        child: CupertinoButton(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          onPressed: controller.completeOnboarding,
                          child: Text(
                            'Skip',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Onboarding Pages with Left-Aligned Premium Editorial Styling
                    Expanded(
                      child: PageView.builder(
                        controller: controller.pageController,
                        onPageChanged: _handlePageChanged,
                        itemCount: controller.pages.length,
                        itemBuilder: (context, index) {
                          final page = controller.pages[index];
                          return Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 28.0,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Glowing Icon Container (Matches the App Logo styling)
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: CupertinoColors
                                        .secondarySystemBackground
                                        .resolveFrom(context),
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: primaryRed.withValues(
                                          alpha: 0.12,
                                        ),
                                        blurRadius: 20,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    page.icon,
                                    size: 48,
                                    color: primaryRed,
                                  ),
                                ),
                                const SizedBox(height: 36),

                                // Tier 1: Eyebrow
                                Text(
                                  'STEP ${index + 1} OF ${controller.pages.length}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                                const SizedBox(height: 4),

                                // Tier 2: Hero Brand Title (Red Gradient)
                                ShaderMask(
                                  blendMode: BlendMode.srcIn,
                                  shaderCallback: (bounds) =>
                                      LinearGradient(
                                        colors: [
                                          primaryRed,
                                          Color.lerp(
                                                primaryRed,
                                                Colors.white,
                                                0.28,
                                              ) ??
                                              primaryRed,
                                        ],
                                        begin: Alignment.centerLeft,
                                        end: Alignment.centerRight,
                                      ).createShader(
                                        Rect.fromLTWH(
                                          0,
                                          0,
                                          bounds.width,
                                          bounds.height,
                                        ),
                                      ),
                                  child: Text(
                                    page.title,
                                    style: const TextStyle(
                                      fontSize: 40,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -1.6,
                                      height: 1.1,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),

                                // Tier 3: Subtitle/Description (Premium Yellow Gradient)
                                ShaderMask(
                                  blendMode: BlendMode.srcIn,
                                  shaderCallback: (bounds) =>
                                      goldGradient.createShader(
                                        Rect.fromLTWH(
                                          0,
                                          0,
                                          bounds.width,
                                          bounds.height,
                                        ),
                                      ),
                                  child: Text(
                                    page.description,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      // Fallback color for shader mapping
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: -0.2,
                                      height: 1.3,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),

                    // Modern Page Indicators
                    Obx(
                      () => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 28.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: List.generate(controller.pages.length, (
                            index,
                          ) {
                            final isActive =
                                controller.currentPage.value == index;
                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              height: 6,
                              width: isActive ? 20 : 6,
                              decoration: BoxDecoration(
                                gradient: isActive ? goldGradient : null,
                                color: isActive
                                    ? null
                                    : CupertinoColors.systemGrey5.resolveFrom(
                                        context,
                                      ),
                                borderRadius: BorderRadius.circular(3),
                              ),
                            );
                          }),
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Action Button Block (Matches the custom Jewel Button from Login)
                    Padding(
                      padding: const EdgeInsets.only(
                        left: 28.0,
                        right: 28.0,
                        bottom: 32.0,
                      ),
                      child: SizedBox(
                        height: 52,
                        width: double.infinity,
                        child: Obx(
                          () => Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              gradient: LinearGradient(
                                colors: [
                                  primaryRed,
                                  Color.lerp(primaryRed, Colors.black, 0.12) ??
                                      primaryRed,
                                ],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: primaryRed.withValues(alpha: 0.25),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: CupertinoButton(
                              padding: EdgeInsets.zero,
                              onPressed: controller.nextOrFinish,
                              child: Text(
                                controller.isLastPage ? 'Get Started' : 'Next',
                                style: const TextStyle(
                                  color: CupertinoColors.white,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: -0.4,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
