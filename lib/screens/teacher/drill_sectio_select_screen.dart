import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/teacher/section_claim_controller.dart';
import '../../models/drill_event.dart';
import 'map_headcount_gate_screen.dart';

const _primaryRed = Color(0xFF7B1113);

/// Shown when a drill/emergency is active. Lists every section in the
/// school (not just ones this teacher advises — anyone can step in
/// during an emergency) and lets the teacher claim one to run headcount
/// on. Already-claimed sections are shown, not hidden, so a teacher can
/// see who's covering what at a glance.
class DrillSectionSelectScreen extends StatelessWidget {
  const DrillSectionSelectScreen({super.key, required this.drillEvent});

  final DrillEvent drillEvent;

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(SectionClaimController(drillEvent));

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

        return RefreshIndicator(
          onRefresh: controller.refresh,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: _primaryRed.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: _primaryRed),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Select the section you\'re handling right now, then start the headcount.',
                        style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
              ...controller.allSections.map((section) {
                final claim = controller.claimFor(section.id);
                final claimedByMe = controller.isClaimedByMe(section.id);
                final claimedByOther = claim != null && !claimedByMe;

                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  color: claimedByMe ? Colors.green.shade50 : Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: claimedByMe ? Colors.green.shade200 : Colors.grey.shade200,
                    ),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    title: Text(
                      '${section.yearLevel ?? ''} — ${section.name}'.trim(),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      claimedByMe
                          ? 'You\'re handling this — tap to open headcount'
                          : claimedByOther
                          ? 'Claimed by ${claim.teacherName}'
                          : 'Unclaimed',
                      style: TextStyle(
                        color: claimedByMe
                            ? Colors.green.shade700
                            : claimedByOther
                            ? Colors.grey.shade600
                            : _primaryRed,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    trailing: claimedByMe
                        ? const Icon(Icons.chevron_right, color: Colors.green)
                        : claimedByOther
                        ? const Icon(Icons.lock_outline, color: Colors.grey)
                        : Obx(() => controller.isClaiming.value
                        ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                        : const Icon(Icons.chevron_right, color: _primaryRed)),
                    onTap: claimedByOther
                        ? () => Get.snackbar('Already Claimed', 'Handled by ${claim.teacherName}.')
                        : () async {
                      if (claimedByMe) {
                        Get.to(() => MapHeadcountGateScreen(
                          drillEventId: drillEvent.id,
                          sectionId: section.id,
                          sectionLabel: '${section.yearLevel ?? ''} — ${section.name}'.trim(),
                        ));
                        return;
                      }
                      final result = await controller.claimSection(section.id);
                      if (result != null) {
                        Get.to(() => MapHeadcountGateScreen(
                          drillEventId: drillEvent.id,
                          sectionId: section.id,
                          sectionLabel: '${section.yearLevel ?? ''} — ${section.name}'.trim(),
                        ));
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