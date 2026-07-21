import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/admin/drill_controller.dart';
import '../../models/drill_event.dart';
import '../admin/admin_dashboard_screen.dart'; // Assuming primaryRed / accentYellow are here

class EmergencyFloatingActionButton extends StatelessWidget {
  const EmergencyFloatingActionButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      width: 64,
      margin: const EdgeInsets.only(top: 30),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [primaryRed, accentYellow],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: primaryRed.withValues(alpha: 0.4),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: FloatingActionButton(
        backgroundColor: Colors.transparent,
        elevation: 0,
        highlightElevation: 0,
        child: const Icon(CupertinoIcons.exclamationmark_triangle_fill, color: Colors.white, size: 32),
        onPressed: () => _showInitialChoice(context),
      ),
    );
  }

  void _showInitialChoice(BuildContext context) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('Initiate Evacuation'),
        message: const Text('Please select the type of evacuation procedure to initiate across the campus.'),
        actions: [
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(context);
              _showFloatingDetailsWindow(context, DrillEventType.emergency);
            },
            child: const Text('Start REAL Emergency'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              _showFloatingDetailsWindow(context, DrillEventType.drill);
            },
            child: const Text('Start Evacuation DRILL', style: TextStyle(color: accentYellow)),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: primaryRed)),
        ),
      ),
    );
  }

  void _showFloatingDetailsWindow(BuildContext context, DrillEventType type) {
    final controller = Get.put(DrillController());

    // Reset state every time the modal is opened so previous data isn't preserved
    controller.nameController.clear();
    controller.selectedDisasterType.value = null;
    controller.errorMessage.value = null;
    controller.selectedEventType.value = type;

    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(type == DrillEventType.emergency ? 'Emergency Details' : 'Drill Details'),
        content: Material(
          color: Colors.transparent,
          // Wrap in Obx so changes to the Disaster Type or Error Message trigger a visual rebuild
          child: Obx(() => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              CupertinoTextField(
                controller: controller.nameController,
                placeholder: 'Enter name (e.g. Fire Drill 2024)',
                onChanged: (_) => controller.errorMessage.value = null, // Clear error on typing
              ),
              if (type == DrillEventType.emergency) ...[
                const SizedBox(height: 15),
                const Align(alignment: Alignment.centerLeft, child: Text('Disaster Type')),
                Wrap(
                  spacing: 8,
                  children: DisasterType.values.map((t) => ChoiceChip(
                    label: Text(t.name),
                    selected: controller.selectedDisasterType.value == t,
                    onSelected: (selected) {
                      // Toggle selection
                      controller.selectedDisasterType.value = selected ? t : null;
                      controller.errorMessage.value = null; // Clear error on selection
                    },
                    selectedColor: primaryRed.withValues(alpha: 0.2),
                    checkmarkColor: primaryRed,
                  )).toList(),
                ),
              ],
              // Dynamically display validation errors from the DrillController
              if (controller.errorMessage.value != null) ...[
                const SizedBox(height: 10),
                Text(
                  controller.errorMessage.value!,
                  style: const TextStyle(color: CupertinoColors.destructiveRed, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ]
            ],
          )),
        ),
        actions: [
          CupertinoDialogAction(
              onPressed: () => Get.back(),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey))
          ),
          // Wrap Action in Obx to handle loading state
          Obx(() => CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: controller.isSaving.value
                ? null // Disable clicking while processing
                : () async {
              if (await controller.startDrill()) {
                Get.back();
                Get.snackbar(
                  type == DrillEventType.emergency ? 'Emergency Activated' : 'Drill Activated',
                  'Evacuation protocol successfully triggered.',
                  backgroundColor: type == DrillEventType.emergency ? primaryRed : accentYellow,
                  colorText: type == DrillEventType.emergency ? Colors.white : Colors.black,
                );
              }
            },
            child: controller.isSaving.value
                ? const CupertinoActivityIndicator()
                : const Text('Confirm', style: TextStyle(color: primaryRed, fontWeight: FontWeight.bold)),
          )),
        ],
      ),
    );
  }
}