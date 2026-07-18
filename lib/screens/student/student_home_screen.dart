import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/student_controller.dart';
import '../../controllers/auth_controller.dart';

class StudentHomeScreen extends StatelessWidget {
  const StudentHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(StudentController());
    final authController = Get.find<AuthController>();
    final profile = authController.profile.value;

    return Scaffold(
      appBar: AppBar(
        title: Text(profile?.fullName ?? 'My Section'),
        actions: [
          IconButton(icon: const Icon(Icons.logout), onPressed: () => authController.signOut()),
        ],
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }
        if (controller.errorMessage.value != null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(controller.errorMessage.value!, textAlign: TextAlign.center),
            ),
          );
        }

        final section = controller.section.value;

        return RefreshIndicator(
          onRefresh: controller.refresh,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(Icons.school_outlined, size: 32),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              section != null
                                  ? '${section.yearLevel ?? ''} — ${section.name}'.trim()
                                  : 'No section assigned',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text('${controller.classmates.length} students in this section'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.4),
                child: const Padding(
                  padding: EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Drill and emergency check-in features aren\'t available yet in this version.',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text('Classmates', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              if (controller.classmates.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text('No classmates listed yet.'),
                )
              else
                ...controller.classmates.map(
                      (c) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const CircleAvatar(child: Icon(Icons.person_outline)),
                    title: Text(c.fullName),
                    trailing: c.schoolIdNumber == profile?.schoolIdNumber
                        ? const Chip(label: Text('You'))
                        : null,
                  ),
                ),
            ],
          ),
        );
      }),
    );
  }
}