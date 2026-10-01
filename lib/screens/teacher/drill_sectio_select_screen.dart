import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/teacher/section_claim_controller.dart';
import '../../models/drill_event.dart';
import 'map_headcount_gate_screen.dart';

const _primaryRed = Color(0xFF7B1113);

/// Shown when a drill/emergency is active. Lists every section in the
/// school (not just ones this teacher advises — anyone can step in
/// during an emergency) and lets the teacher claim sections to run
/// headcount on.
///
/// Rules:
///  * A section can be handled by several teachers at once — other
///    teachers' claims are shown, not hidden, but don't block you.
///  * A teacher can claim at most
///    [SectionClaimController.maxClaimsPerTeacher] sections per drill.
///    Once at the limit, sections you haven't claimed are locked.
class DrillSectionSelectScreen extends StatelessWidget {
  const DrillSectionSelectScreen({super.key, required this.drillEvent});

  final DrillEvent drillEvent;

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(SectionClaimController(drillEvent));

    void openHeadcount(String sectionId, String sectionLabel) {
      Get.to(
        () => MapHeadcountGateScreen(
          drillEventId: drillEvent.id,
          sectionId: sectionId,
          sectionLabel: sectionLabel,
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: _primaryRed,
        foregroundColor: Colors.white,
        title: Text(drillEvent.name),
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }
        if (controller.errorMessage.value != null) {
          return Center(child: Text(controller.errorMessage.value!));
        }

        final max = SectionClaimController.maxClaimsPerTeacher;

        return RefreshIndicator(
          onRefresh: controller.refresh,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: _primaryRed.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: _primaryRed),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Select the section(s) you\'re handling right now, then start the headcount. '
                        'You can handle up to $max sections '
                        '(${controller.myClaimCount}/$max claimed).',
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              ...controller.allSections.map((section) {
                final label = '${section.yearLevel ?? ''} — ${section.name}'
                    .trim();
                final claimedByMe = controller.isClaimedByMe(section.id);
                final others = controller.othersFor(section.id);
                final othersText = others.map((c) => c.teacherName).join(', ');
                // At the limit and this isn't one of my sections -> locked.
                final blocked = !claimedByMe && !controller.canClaimMore;

                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  color: claimedByMe ? Colors.green.shade50 : Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: claimedByMe
                          ? Colors.green.shade200
                          : Colors.grey.shade200,
                    ),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    title: Text(
                      label,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: blocked ? Colors.grey.shade600 : null,
                      ),
                    ),
                    subtitle: Text(
                      claimedByMe
                          ? others.isNotEmpty
                                ? 'You\'re handling this with $othersText — tap to open headcount'
                                : 'You\'re handling this — tap to open headcount'
                          : blocked
                          ? others.isNotEmpty
                                ? 'Handled by $othersText · Limit reached ($max/$max)'
                                : 'Limit reached ($max/$max)'
                          : others.isNotEmpty
                          ? 'Also handled by $othersText — tap to join'
                          : 'Unclaimed',
                      style: TextStyle(
                        color: claimedByMe
                            ? Colors.green.shade700
                            : blocked
                            ? Colors.grey.shade600
                            : _primaryRed,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    trailing: claimedByMe
                        ? const Icon(Icons.chevron_right, color: Colors.green)
                        : blocked
                        ? const Icon(Icons.lock_outline, color: Colors.grey)
                        : Obx(
                            () => controller.isClaiming.value
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(
                                    Icons.chevron_right,
                                    color: _primaryRed,
                                  ),
                          ),
                    onTap: blocked
                        ? () => Get.snackbar(
                            'Limit reached',
                            'You can handle at most $max sections.',
                          )
                        : () async {
                            if (claimedByMe) {
                              openHeadcount(section.id, label);
                              return;
                            }
                            final result = await controller.claimSection(
                              section.id,
                            );
                            if (result != null) {
                              openHeadcount(section.id, label);
                            }
                          },
                  ),
                );
              }),
            ],
          ),
        );
      }),
    );
  }
}
