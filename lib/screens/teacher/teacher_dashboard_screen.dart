import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/teacher_section_controller.dart';
import '../../controllers/auth_controller.dart';
import '../../services/drill_service.dart';
import '../../models/drill_event.dart';
import '../../models/section.dart';
import '../widgets/phone_registration_dialog.dart';
import 'drill_sectio_select_screen.dart';
import 'roster_screen.dart';
import 'teacher_roster_screen.dart';

/// ⚠️ ADJUST: this assumes AuthController exposes the signed-in
/// AppProfile as a reactive `Rxn<AppProfile> profile` (or similar —
/// anything with `.value` giving you an `AppProfile?`). Swap the
/// `authController.profile.value` references below for whatever your
/// AuthController actually calls it.
class TeacherDashboardScreen extends StatefulWidget {
  const TeacherDashboardScreen({super.key});

  @override
  State<TeacherDashboardScreen> createState() => _TeacherDashboardScreenState();
}

class _TeacherDashboardScreenState extends State<TeacherDashboardScreen> {
  late final TeacherSectionController controller;
  late final AuthController authController;
  final _drillService = DrillService();
  final Rxn<DrillEvent> activeDrill = Rxn<DrillEvent>();

  @override
  void initState() {
    super.initState();
    controller = Get.put(TeacherSectionController());
    authController = Get.find<AuthController>();

    // Check after the first frame so the dialog has a valid context and
    // doesn't compete with any initial-load spinner.
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkPhoneRegistration());
    _checkActiveDrill();
  }

  /// One-shot check on dashboard load. This is deliberately NOT the
  /// primary way a teacher finds out about a drill — that should still
  /// be the push notification (see firebaseMessagingBackgroundHandler /
  /// _handleNotificationTap in push_notification_service.dart, whose
  /// TODO can now call `DrillService().fetchDrillEventById(drillEventId)`
  /// and push DrillSectionSelectScreen the same way this banner does).
  /// This is just a fallback so the banner still appears if a teacher
  /// opens the app mid-drill without tapping a notification.
  Future<void> _checkActiveDrill() async {
    try {
      final drill = await _drillService.fetchActiveDrillEvent();
      if (mounted) activeDrill.value = drill;
    } catch (_) {
      // Non-fatal — the dashboard still works without the banner.
    }
  }

  void _checkPhoneRegistration() {
    final profile = authController.profile.value;
    if (profile == null) return; // still loading — nothing to gate yet
    if (profile.hasRegisteredPhone) return;

    showPhoneRegistrationDialog(
      context,
      profileId: profile.id,
      onSaved: () {
        // Reflect the save locally so the gate doesn't reopen and any
        // other screen reading authController.profile picks it up too.
        // ⚠️ ADJUST: this assumes `profile` is a settable Rxn — if
        // AuthController instead exposes a refresh method (e.g.
        // `authController.refreshProfile()`), call that here instead.
        authController.profile.value = profile.copyWithPhone(
          authController.profile.value?.registeredPhoneNumber ?? '',
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Sections'),
        actions: [
          IconButton(
            icon: const Icon(Icons.groups_outlined),
            tooltip: 'Manage Roster',
            onPressed: () => Get.to(() => const TeacherRosterScreen()),
          ),
          IconButton(icon: const Icon(Icons.logout), onPressed: () => authController.signOut()),
        ],
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }
        if (controller.errorMessage.value != null) {
          return Center(child: Text(controller.errorMessage.value!));
        }

        final drillBanner = activeDrill.value == null
            ? null
            : Container(
          margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Material(
            color: const Color(0xFF7B1113),
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => Get.to(() => DrillSectionSelectScreen(drillEvent: activeDrill.value!)),
              child: const Padding(
                padding: EdgeInsets.all(14),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.white),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Drill in progress — tap to select your section',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                      ),
                    ),
                    Icon(Icons.chevron_right, color: Colors.white),
                  ],
                ),
              ),
            ),
          ),
        );

        if (controller.mySections.isEmpty) {
          return Column(
            children: [
              if (drillBanner != null) drillBanner,
              const Expanded(
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'No sections assigned to you yet. An admin needs to create a section '
                          'and set you as adviser before you can roster it.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
            ],
          );
        }

        return RefreshIndicator(
          onRefresh: controller.fetchMySections,
          child: ListView.builder(
            itemCount: controller.mySections.length + (drillBanner != null ? 1 : 0),
            itemBuilder: (context, index) {
              if (drillBanner != null) {
                if (index == 0) return drillBanner;
                final section = controller.mySections[index - 1];
                return _SectionTile(section: section, controller: controller);
              }
              final section = controller.mySections[index];
              return _SectionTile(section: section, controller: controller);
            },
          ),
        );
      }),
    );
  }
}

class _SectionTile extends StatelessWidget {
  const _SectionTile({required this.section, required this.controller});

  final AppSection section;
  final TeacherSectionController controller;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        section.isRostered ? Icons.check_circle : Icons.hourglass_empty,
        color: section.isRostered ? Colors.green : Colors.orange,
      ),
      title: Text('${section.yearLevel ?? ''} — ${section.name}'.trim()),
      subtitle: Text(
        section.isRostered ? 'Rostered — tap to manage students' : 'Not yet rostered — tap to add students',
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () async {
        await Get.to(() => RosterScreen(section: section));
        controller.fetchMySections(); // status may have flipped to 'rostered'
      },
    );
  }
}