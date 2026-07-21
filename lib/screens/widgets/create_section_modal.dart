import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/admin/admin_section_controller.dart';

class CreateSectionModal extends StatelessWidget {
  const CreateSectionModal({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(CreateSectionController()); //[cite: 2]

    return Scaffold(
      backgroundColor: Colors.transparent,
      // The magic bullet: Resizes the canvas dynamically when the keyboard appears
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          // Dismisses the modal safely if the user taps the background blur area
          GestureDetector(
            onTap: () => Get.back(),
            child: Container(color: Colors.transparent),
          ),
          Center(
            child: SingleChildScrollView(
              // Handles internal padding gracefully when squished by the keyboard
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 400),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28), // Premium iOS rounded look
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 30,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: Form(
                  key: controller.formKey, //[cite: 2]
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header with iOS-style Close Button
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'New Section',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.5,
                              color: Colors.black,
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              CupertinoIcons.clear_circled,
                              color: Colors.grey.shade400,
                              size: 26,
                            ),
                            onPressed: () => Get.back(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // 1. Year Level Dropdown
                      Obx(() => DropdownButtonFormField<String>(
                        initialValue: controller.selectedYearLevel.value, //[cite: 2]
                        decoration: _buildInputDecoration('Year Level', CupertinoIcons.layers_alt_fill),
                        dropdownColor: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        items: CreateSectionController.yearLevels //[cite: 2]
                            .map((y) => DropdownMenuItem(value: y, child: Text(y)))
                            .toList(),
                        onChanged: (v) => controller.selectedYearLevel.value = v, //[cite: 2]
                      )),
                      const SizedBox(height: 14),

                      // 2. Section Name Input
                      TextFormField(
                        controller: controller.nameController, //[cite: 2]
                        decoration: _buildInputDecoration('Section Name', CupertinoIcons.tag_fill, hint: 'e.g. Rizal'),
                      ),
                      const SizedBox(height: 14),

                      // 3. Expected Students Input
                      TextFormField(
                        controller: controller.countController, //[cite: 2]
                        keyboardType: TextInputType.number,
                        decoration: _buildInputDecoration(
                          'Expected Students',
                          CupertinoIcons.person_3_fill,
                          helper: 'Used to flag incomplete rosters later',
                        ),
                      ),
                      const SizedBox(height: 14),

                      // 4. Adviser Dropdown
                      Obx(() {
                        if (controller.isLoadingTeachers.value) { //[cite: 2]
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8.0),
                            child: Center(child: CupertinoActivityIndicator()),
                          );
                        }
                        if (controller.teachers.isEmpty) { //[cite: 2]
                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'No approved teachers yet.',
                              style: TextStyle(color: Colors.orange, fontSize: 13, fontWeight: FontWeight.w500),
                            ),
                          );
                        }
                        return DropdownButtonFormField<String>(
                          initialValue: controller.selectedAdviserId.value, //[cite: 2]
                          decoration: _buildInputDecoration('Assigned Adviser', CupertinoIcons.person_crop_circle_fill),
                          dropdownColor: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          items: controller.teachers //[cite: 2]
                              .map((t) => DropdownMenuItem(value: t.id, child: Text(t.fullName)))
                              .toList(),
                          onChanged: (v) => controller.selectedAdviserId.value = v, //[cite: 2]
                        );
                      }),

                      // Error Feedback
                      Obx(() => controller.errorMessage.value == null //[cite: 2]
                          ? const SizedBox.shrink()
                          : Padding(
                        padding: const EdgeInsets.only(top: 14),
                        child: Text(
                          controller.errorMessage.value!, //[cite: 2]
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: CupertinoColors.destructiveRed, fontSize: 13),
                        ),
                      )),
                      const SizedBox(height: 24),

                      // iOS-Style Primary Action Button
                      Obx(() => CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: controller.isSaving.value //[cite: 2]
                            ? null
                            : () async {
                          final success = await controller.submit(); //[cite: 2]
                          if (success) Get.back(result: true); //[cite: 2]
                        },
                        child: Container(
                          height: 52,
                          decoration: BoxDecoration(
                            color: const Color(0xFF751018), // primaryRed
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Center(
                            child: controller.isSaving.value //[cite: 2]
                                ? const CupertinoActivityIndicator(color: Colors.white)
                                : const Text(
                              'Create Section',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                letterSpacing: -0.3,
                              ),
                            ),
                          ),
                        ),
                      )),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // iOS-style soft input decoration
  InputDecoration _buildInputDecoration(String label, IconData icon, {String? hint, String? helper}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      helperText: helper,
      helperMaxLines: 2,
      prefixIcon: Icon(icon, size: 18, color: Colors.grey.shade500),
      labelStyle: TextStyle(color: Colors.grey.shade600, fontSize: 14),
      floatingLabelStyle: const TextStyle(color: Color(0xFF751018), fontWeight: FontWeight.w600),
      filled: true,
      fillColor: const Color(0xFFF2F2F7), // iOS System Gray 6
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF751018), width: 1.5),
      ),
    );
  }
}