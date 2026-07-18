import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/admin_section_controller.dart';

class CreateSectionScreen extends StatelessWidget {
  const CreateSectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(CreateSectionController());

    // todo change change this to a modals and user 
    return Scaffold(
      appBar: AppBar(title: const Text('Create Section')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: controller.formKey,
          child: ListView(
            children: [
              Obx(() => DropdownButtonFormField<String>(
                initialValue: controller.selectedYearLevel.value,
                decoration: const InputDecoration(labelText: 'Year Level', border: OutlineInputBorder()),
                items: CreateSectionController.yearLevels
                    .map((y) => DropdownMenuItem(value: y, child: Text(y)))
                    .toList(),
                onChanged: (v) => controller.selectedYearLevel.value = v,
              )),
              const SizedBox(height: 16),
              TextFormField(
                controller: controller.nameController,
                decoration: const InputDecoration(
                  labelText: 'Section Name',
                  hintText: 'e.g. Rizal',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: controller.countController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Number of Students',
                  helperText: 'Expected count, used to flag incomplete rosters later',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              Obx(() {
                if (controller.isLoadingTeachers.value) {
                  return const LinearProgressIndicator();
                }
                if (controller.teachers.isEmpty) {
                  return const Text(
                    'No approved teachers yet — approve at least one teacher account before creating a section.',
                    style: TextStyle(color: Colors.orange),
                  );
                }
                return DropdownButtonFormField<String>(
                  initialValue: controller.selectedAdviserId.value,
                  decoration: const InputDecoration(labelText: 'Adviser', border: OutlineInputBorder()),
                  items: controller.teachers
                      .map((t) => DropdownMenuItem(value: t.id, child: Text(t.fullName)))
                      .toList(),
                  onChanged: (v) => controller.selectedAdviserId.value = v,
                );
              }),
              Obx(() => controller.errorMessage.value == null
                  ? const SizedBox.shrink()
                  : Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(controller.errorMessage.value!, style: const TextStyle(color: Colors.red)),
              )),
              const SizedBox(height: 24),
              Obx(() => FilledButton(
                onPressed: controller.isSaving.value
                    ? null
                    : () async {
                  final success = await controller.submit();
                  if (success) Get.back(result: true);
                },
                child: controller.isSaving.value
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Create Section'),
              )),
            ],
          ),
        ),
      ),
    );
  }
}