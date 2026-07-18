import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/roster_controller.dart';
import '../../models/section.dart';

class RosterScreen extends StatelessWidget {
  final AppSection section;
  const RosterScreen({super.key, required this.section});

  Future<void> _showAddStudentDialog(BuildContext context, RosterController controller) async {
    final schoolIdController = TextEditingController();
    final nameController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Student'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: schoolIdController,
              decoration: const InputDecoration(labelText: 'School ID Number'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Full Name'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Add')),
        ],
      ),
    );

    if (confirmed != true) return;
    if (schoolIdController.text.trim().isEmpty || nameController.text.trim().isEmpty) return;

    final success = await controller.addStudent(
      schoolIdNumber: schoolIdController.text.trim(),
      fullName: nameController.text.trim(),
    );
    if (!success && context.mounted) {
      Get.snackbar('Error', controller.statusMessage.value ?? 'Failed to add student');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Tag by section id so navigating between different sections'
    // roster screens (without popping) doesn't share controller state.
    final controller = Get.put(RosterController(section), tag: section.id);

    return Scaffold(
      appBar: AppBar(title: Text(section.name)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.person_add),
                    label: const Text('Add Student'),
                    onPressed: () => _showAddStudentDialog(context, controller),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Obx(() => FilledButton.icon(
                    icon: controller.isImporting.value
                        ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.upload_file),
                    label: const Text('Import Excel'),
                    onPressed: controller.isImporting.value ? null : controller.importFromExcel,
                  )),
                ),
              ],
            ),
          ),
          Obx(() => controller.statusMessage.value == null
              ? const SizedBox.shrink()
              : Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(controller.statusMessage.value!),
          )),
          const Divider(height: 1),
          Expanded(
            child: Obx(() {
              if (controller.isLoading.value) {
                return const Center(child: CircularProgressIndicator());
              }
              if (controller.roster.isEmpty) {
                return const Center(child: Text('No students added yet.'));
              }

              return ListView.builder(
                itemCount: controller.roster.length,
                itemBuilder: (context, index) {
                  final entry = controller.roster[index];
                  return ListTile(
                    title: Text(entry.fullName),
                    subtitle: Text(entry.schoolIdNumber),
                    trailing: Chip(
                      label: Text(entry.claimed ? 'Claimed' : 'Pending'),
                      backgroundColor: entry.claimed
                          ? Colors.green.withValues(alpha: 0.15)
                          : Colors.orange.withValues(alpha: 0.15),
                    ),
                  );
                },
              );
            }),
          ),
        ],
      ),
    );
  }
}