import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/teacher_roster_controller.dart';
import '../../models/parsed_roster_row.dart';

const _primaryRed = Color(0xFF7B1113);

/// Roster management for the sections the signed-in teacher advises.
/// Trimmed-down sibling of AdminRosterScreen: no role picker (students
/// only), no accounts tab, section dropdown limited to `mySections`.
class TeacherRosterScreen extends StatefulWidget {
  const TeacherRosterScreen({super.key});

  @override
  State<TeacherRosterScreen> createState() => _TeacherRosterScreenState();
}

class _TeacherRosterScreenState extends State<TeacherRosterScreen> {
  final controller = Get.put(TeacherRosterController());

  Future<void> _showAddDialog(BuildContext context) async {
    await showCupertinoDialog<void>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: SizedBox(
            width: 360,
            child: Obx(() => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Add Student',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: -0.5),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                CupertinoTextField(
                  controller: controller.schoolIdController,
                  placeholder: 'School ID Number',
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(height: 12),
                CupertinoTextField(
                  controller: controller.fullNameController,
                  placeholder: 'Full Name',
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: controller.selectedSectionId.value,
                      hint: const Text('Select Section'),
                      isExpanded: true,
                      icon: const Icon(CupertinoIcons.chevron_down, size: 16),
                      items: controller.mySections
                          .map((s) => DropdownMenuItem(
                        value: s.id,
                        child: Text('${s.yearLevel ?? ''} — ${s.name}'.trim()),
                      ))
                          .toList(),
                      onChanged: (v) => controller.selectedSectionId.value = v,
                    ),
                  ),
                ),
                if (controller.formError.value != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    controller.formError.value!,
                    style: const TextStyle(color: CupertinoColors.destructiveRed, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    CupertinoButton(
                      onPressed: () => Get.back(),
                      child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                    ),
                    CupertinoButton(
                      color: _primaryRed,
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      borderRadius: BorderRadius.circular(10),
                      onPressed: controller.isSaving.value
                          ? null
                          : () async {
                        final success = await controller.submitNewEntry();
                        if (success) {
                          Get.back();
                          Get.snackbar(
                            'Added',
                            'Student added to roster.',
                            duration: const Duration(seconds: 2),
                            backgroundColor: Colors.white,
                            colorText: Colors.black,
                            snackPosition: SnackPosition.TOP,
                          );
                        }
                      },
                      child: controller.isSaving.value
                          ? const CupertinoActivityIndicator(color: Colors.white)
                          : const Text('Add', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ],
            )),
          ),
        ),
      ),
    );
  }

  Future<void> _showImportPreviewModal(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.8,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Padding(
                padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
                child: Obx(() {
                  final rows = controller.stagedRows;
                  final activeRows = rows.where((r) => r.isValid).length;
                  final errorCount = rows.where((r) => !r.isValid).length;

                  return Column(
                    children: [
                      Center(
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 12),
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Review Import',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                            ),
                            Text(
                              '$activeRows ready'
                                  '${errorCount > 0 ? ' · $errorCount need fixing' : ''}',
                              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: ListView.builder(
                          controller: scrollController,
                          itemCount: rows.length,
                          itemBuilder: (context, index) {
                            final row = rows[index];
                            return _StagedStudentRow(
                              row: row,
                              onIdChanged: (v) => controller.updateStagedRow(index, schoolId: v),
                              onNameChanged: (v) => controller.updateStagedRow(index, fullName: v),
                              onDelete: () => controller.stagedRows.removeAt(index),
                            );
                          },
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () {
                                  controller.cancelStagedImport();
                                  Get.back();
                                },
                                child: const Text('Cancel'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: FilledButton(
                                style: FilledButton.styleFrom(backgroundColor: _primaryRed),
                                onPressed: (activeRows == 0 || controller.isImportingStudents.value)
                                    ? null
                                    : controller.confirmStagedImport,
                                child: controller.isImportingStudents.value
                                    ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                                    : Text('Import $activeRows Student${activeRows == 1 ? '' : 's'}'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                }),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Roster')),
      body: Obx(() {
        if (controller.mySections.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'You are not the adviser of any section yet, so there\'s nothing to roster.',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: controller.refresh,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (controller.isShowingCachedData.value)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.amber.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.cloud_off, size: 18, color: Colors.amber.shade800),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          controller.errorMessage.value ?? 'Showing your last saved roster.',
                          style: TextStyle(fontSize: 12.5, color: Colors.amber.shade900),
                        ),
                      ),
                    ],
                  ),
                ),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _showAddDialog(context),
                      icon: const Icon(Icons.person_add_alt_1, size: 18),
                      label: const Text('Add Student'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Obx(() => FilledButton.icon(
                      style: FilledButton.styleFrom(backgroundColor: _primaryRed),
                      onPressed: controller.isParsingImport.value
                          ? null
                          : () async {
                        await controller.pickAndParseRosterExcel();
                        if (controller.stagedRows.isNotEmpty && context.mounted) {
                          await _showImportPreviewModal(context);
                        }
                      },
                      icon: controller.isParsingImport.value
                          ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                          : const Icon(Icons.upload_file, size: 18),
                      label: const Text('Import Excel'),
                    )),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Text('Section', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey)),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: controller.selectedSectionId.value,
                    isExpanded: true,
                    items: controller.mySections
                        .map((s) => DropdownMenuItem(
                      value: s.id,
                      child: Text('${s.yearLevel ?? ''} — ${s.name}'.trim()),
                    ))
                        .toList(),
                    onChanged: (v) => controller.selectedSectionId.value = v,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text('Students', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey)),
              const SizedBox(height: 8),
              if (controller.isLoading.value)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: CircularProgressIndicator()),
                )
              else
                ...controller.roster
                    .where((r) => r.sectionId == controller.selectedSectionId.value)
                    .map(
                      (r) => Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      title: Text(r.fullName),
                      subtitle: Text(r.schoolIdNumber),
                      trailing: Icon(
                        r.claimed ? Icons.check_circle : Icons.hourglass_empty,
                        color: r.claimed ? Colors.green : Colors.orange,
                        size: 20,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      }),
    );
  }
}

/// Standalone row widget so its TextEditingControllers survive Obx
/// rebuilds — same pattern as AdminRosterScreen's _StagedRowCard.
class _StagedStudentRow extends StatefulWidget {
  final ParsedRosterRow row;
  final ValueChanged<String> onNameChanged;
  final ValueChanged<String> onIdChanged;
  final VoidCallback onDelete;

  const _StagedStudentRow({
    required this.row,
    required this.onNameChanged,
    required this.onIdChanged,
    required this.onDelete,
  });

  @override
  State<_StagedStudentRow> createState() => _StagedStudentRowState();
}

class _StagedStudentRowState extends State<_StagedStudentRow> {
  late TextEditingController _nameController;
  late TextEditingController _idController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.row.fullName);
    _idController = TextEditingController(text: widget.row.schoolId);
  }

  @override
  void didUpdateWidget(covariant _StagedStudentRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.row.fullName != _nameController.text) {
      _nameController.text = widget.row.fullName;
    }
    if (widget.row.schoolId != _idController.text) {
      _idController.text = widget.row.schoolId;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _idController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blueGrey.shade50,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.blueGrey.shade100),
                ),
                child: Text(
                  'ROW ${widget.row.rowIndex}',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blueGrey.shade600),
                ),
              ),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: Icon(Icons.delete_outline, color: Colors.red.shade400, size: 20),
                onPressed: widget.onDelete,
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(isDense: true, prefixText: 'Name:  ', border: InputBorder.none),
            onChanged: widget.onNameChanged,
          ),
          Divider(height: 12, color: Colors.grey.shade100),
          TextField(
            controller: _idController,
            decoration: const InputDecoration(isDense: true, prefixText: 'ID:      ', border: InputBorder.none),
            onChanged: widget.onIdChanged,
          ),
          if (!widget.row.isValid && widget.row.error != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.shade100),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, size: 16, color: Colors.amber.shade800),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.row.error!,
                      style: TextStyle(fontSize: 12.5, color: Colors.amber.shade900, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}