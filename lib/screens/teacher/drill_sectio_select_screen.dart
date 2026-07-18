import 'package:asan_evac_app/screens/teacher/head_count_screen.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/section_claim_controller.dart';
import '../../models/drill_event.dart';

const _primaryRed = Color(0xFF7B1113);
const _iosBackground = Color(0xFFF2F2F7);

class DrillSectionSelectScreen extends StatelessWidget {
  const DrillSectionSelectScreen({super.key, required this.drillEvent});

  final DrillEvent drillEvent;

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(SectionClaimController(drillEvent));

    return Scaffold(
      backgroundColor: _iosBackground,
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CupertinoActivityIndicator(radius: 14));
        }
        if (controller.errorMessage.value != null) {
          return Center(child: Text(controller.errorMessage.value!));
        }

        return RefreshIndicator(
          onRefresh: controller.refresh,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
            slivers: [
              SliverAppBar.large(
                backgroundColor: _iosBackground,
                surfaceTintColor: Colors.transparent,
                stretch: true,
                title: Text(
                  drillEvent.name,
                  style: const TextStyle(fontWeight: FontWeight.w700, letterSpacing: -0.5),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _primaryRed.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          CupertinoIcons.exclamationmark_triangle_fill,
                          color: _primaryRed,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Select the section you\'re handling right now, then start the headcount.',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: _primaryRed,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.only(top: 8, bottom: 40),
                sliver: _buildSectionsList(controller),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildSectionsList(SectionClaimController controller) {
    if (controller.allSections.isEmpty) {
      return const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: Center(
            child: Text(
              'No sections found.',
              style: TextStyle(color: CupertinoColors.secondaryLabel, fontSize: 16),
            ),
          ),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
            (context, index) {
          final section = controller.allSections[index];
          final claim = controller.claimFor(section.id);
          final claimedByMe = controller.isClaimedByMe(section.id);
          final claimedByOther = claim != null && !claimedByMe;
          final isLast = index == controller.allSections.length - 1;

          final sectionLabel = '${section.yearLevel ?? ''} — ${section.name}'.trim();

          return _SectionRow(
            sectionName: sectionLabel,
            teacherName: claim?.teacherName,
            claimedByMe: claimedByMe,
            claimedByOther: claimedByOther,
            isClaiming: controller.isClaiming.value,
            isLast: isLast,
            onTap: claimedByOther
                ? () => Get.snackbar('Already Claimed', 'Handled by ${claim!.teacherName}.')
                : () async {
              if (claimedByMe) {
                Get.to(() => HeadcountScreen(
                  drillEventId: drillEvent.id,
                  sectionId: section.id,
                  sectionLabel: sectionLabel,
                ));
                return;
              }
              final result = await controller.claimSection(section.id);
              if (result != null) {
                Get.to(() => HeadcountScreen(
                  drillEventId: drillEvent.id,
                  sectionId: section.id,
                  sectionLabel: sectionLabel,
                ));
              }
            },
          );
        },
        childCount: controller.allSections.length,
      ),
    );
  }
}

class _SectionRow extends StatelessWidget {
  const _SectionRow({
    required this.sectionName,
    this.teacherName,
    required this.claimedByMe,
    required this.claimedByOther,
    required this.isClaiming,
    required this.isLast,
    required this.onTap,
  });

  final String sectionName;
  final String? teacherName;
  final bool claimedByMe;
  final bool claimedByOther;
  final bool isClaiming;
  final bool isLast;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Soft highlight for sections the current user is handling
    final bgColor = claimedByMe
        ? CupertinoColors.systemGreen.withValues(alpha: 0.08)
        : Colors.white;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        color: bgColor,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  // iOS Settings-style leading icon avatar
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: claimedByMe
                        ? CupertinoColors.systemGreen.withValues(alpha: 0.2)
                        : claimedByOther
                        ? CupertinoColors.systemFill
                        : _primaryRed.withValues(alpha: 0.1),
                    child: Icon(
                      claimedByMe
                          ? CupertinoIcons.checkmark_alt
                          : claimedByOther
                          ? CupertinoIcons.lock_fill
                          : CupertinoIcons.person_2_fill,
                      size: 20,
                      color: claimedByMe
                          ? CupertinoColors.systemGreen
                          : claimedByOther
                          ? CupertinoColors.secondaryLabel
                          : _primaryRed,
                    ),
                  ),
                  const SizedBox(width: 14),

                  // Section Title & Status Subtitle
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          sectionName,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                            letterSpacing: -0.3,
                            color: claimedByOther ? CupertinoColors.secondaryLabel : CupertinoColors.label,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          claimedByMe
                              ? 'You\'re handling this'
                              : claimedByOther
                              ? 'Claimed by $teacherName'
                              : 'Unclaimed',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: claimedByMe
                                ? CupertinoColors.systemGreen
                                : claimedByOther
                                ? CupertinoColors.secondaryLabel
                                : _primaryRed,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Trailing Indicators
                  if (isClaiming && !claimedByMe && !claimedByOther)
                    const CupertinoActivityIndicator()
                  else if (claimedByMe)
                    const Icon(CupertinoIcons.chevron_forward, color: CupertinoColors.systemGreen, size: 20)
                  else if (claimedByOther)
                      const Icon(CupertinoIcons.lock, color: CupertinoColors.secondaryLabel, size: 20)
                    else
                      const Icon(CupertinoIcons.chevron_forward, color: _primaryRed, size: 20),
                ],
              ),
            ),

            // Edge-to-edge subtle divider (hidden on the last item)
            if (!isLast)
              const Padding(
                padding: EdgeInsets.only(left: 66), // Aligns perfectly with the text start
                child: Divider(height: 1, thickness: 0.5, color: CupertinoColors.separator),
              ),
          ],
        ),
      ),
    );
  }
}