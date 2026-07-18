import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

// Controllers
import '../../controllers/admin_roster_controller.dart';
import '../../controllers/admin_approval_controller.dart';
import '../../models/parsed_roster_row.dart';

// Shared widgets
import '../widgets/glassmorphic_bottom_nav.dart';

class AdminRosterScreen extends StatefulWidget {
  const AdminRosterScreen({super.key});

  @override
  State<AdminRosterScreen> createState() => _AdminRosterScreenState();
}

class _AdminRosterScreenState extends State<AdminRosterScreen> {
  // Local state management
  String _selectedImportType = 'teacher';
  int _activeSegment = 0; // 0: Import & Add, 1: Roster List, 2: Accounts

  // Filters
  String _statusFilter = 'All'; // Roster list filters: 'All', 'Claimed', 'Unclaimed'
  String _accountFilter = 'Pending'; // Account status filters: 'Pending', 'Approved', 'Rejected'

  /// iOS-styled modal for adding a new roster entry manually
  Future<void> _showAddDialog(BuildContext context, AdminRosterController controller) async {
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
                  'Add to Roster',
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

                // Role Dropdown
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: controller.selectedRole.value,
                      isExpanded: true,
                      icon: const Icon(CupertinoIcons.chevron_down, size: 16),
                      items: AdminRosterController.roles
                          .map((r) => DropdownMenuItem(value: r, child: Text(r.capitalizeFirst ?? r)))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) controller.selectedRole.value = v;
                        if (v != 'student') controller.selectedSectionId.value = null;
                      },
                    ),
                  ),
                ),

                if (controller.selectedRole.value == 'student') ...[
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
                        items: controller.sections
                            .map((s) => DropdownMenuItem(
                          value: s.id,
                          child: Text('${s.yearLevel ?? ''} — ${s.name}'.trim()),
                        ))
                            .toList(),
                        onChanged: (v) => controller.selectedSectionId.value = v,
                      ),
                    ),
                  ),
                ],

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
                    Obx(() => CupertinoButton(
                      color: primaryRed,
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
                            'Roster entry created.',
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
                    )),
                  ],
                ),
              ],
            )),
          ),
        ),
      ),
    );
  }

  /// Sleek, modern flat hybrid sheet layout with inline editing, row deletions, and keyboard awareness
  Future<void> _showImportPreviewModal(BuildContext context, AdminRosterController controller) async {
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

                      // Action Header Title Bar
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            TextButton(
                              onPressed: () {
                                controller.cancelStagedImport();
                                Get.back();
                              },
                              style: TextButton.styleFrom(foregroundColor: Colors.grey.shade600),
                              child: const Text('Cancel', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                            ),
                            Column(
                              children: [
                                Text(
                                  'Review Import (${rows.length})',
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  errorCount > 0
                                      ? '$activeRows ready · $errorCount alert${errorCount == 1 ? '' : 's'}'
                                      : '$activeRows ready to import',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: errorCount > 0 ? Colors.amber.shade800 : Colors.grey.shade500,
                                  ),
                                ),
                              ],
                            ),
                            Obx(() {
                              final isImporting = controller.isImportingTeachers.value || controller.isImportingStudents.value;
                              return TextButton(
                                onPressed: (activeRows == 0 || isImporting)
                                    ? null
                                    : () {
                                  controller.confirmStagedImport();
                                  Get.back();
                                },
                                style: TextButton.styleFrom(foregroundColor: primaryRed),
                                child: isImporting
                                    ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: primaryRed),
                                )
                                    : const Text('Import', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                              );
                            }),
                          ],
                        ),
                      ),
                      const Divider(height: 8, thickness: 1, color: Color(0xFFF1F5F9)),

                      // Main Scrollable Staged Queue List View
                      Expanded(
                        child: rows.isEmpty
                            ? const Center(
                          child: Text(
                            'All rows cleared.',
                            style: TextStyle(color: Colors.grey, fontSize: 15),
                          ),
                        )
                            : ListView.builder(
                          controller: scrollController,
                          physics: const ClampingScrollPhysics(),
                          padding: const EdgeInsets.only(top: 8, bottom: 24),
                          itemCount: rows.length,
                          itemBuilder: (context, i) {
                            final row = rows[i];

                            return Dismissible(
                              key: ValueKey('dismiss_${row.rowIndex}'),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                color: Colors.red.shade600,
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 24),
                                child: const Icon(Icons.delete_sweep, color: Colors.white, size: 24),
                              ),
                              onDismissed: (_) {
                                rows.removeAt(i);
                              },
                              child: _StagedRowCard(
                                key: ValueKey('card_${row.rowIndex}'),
                                row: row,
                                onNameChanged: (text) {
                                  controller.updateStagedRow(i, fullName: text);
                                },
                                onIdChanged: (text) {
                                  controller.updateStagedRow(i, schoolId: text);
                                },
                                onDelete: () {
                                  rows.removeAt(i);
                                },
                              ),
                            );
                          },
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
    final rosterController = Get.put(AdminRosterController());
    final approvalController = Get.put(AdminApprovalController());

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      extendBody: true,
      appBar: AppBar(
        backgroundColor: const Color(0xFFF2F2F7),
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          'Roster & Accounts',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
            color: Colors.black,
          ),
        ),
      ),
      body: Column(
        children: [
          // 3-Way iOS Segmented Toggle Switcher
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SizedBox(
              width: double.infinity,
              child: CupertinoSlidingSegmentedControl<int>(
                groupValue: _activeSegment,
                children: {
                  0: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('Import & Add', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  ),
                  1: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('Roster List', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  ),
                  2: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Obx(() {
                      final pendingCount = approvalController.pendingCount.value;

                      return Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('Accounts', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                          if (pendingCount > 0) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: const BoxDecoration(
                                color: CupertinoColors.systemRed,
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                '$pendingCount',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      );
                    }),
                  ),
                },
                onValueChanged: (value) {
                  if (value != null) {
                    setState(() => _activeSegment = value);
                  }
                },
              ),
            ),
          ),

          // Contextual filter row render systems
          if (_activeSegment == 1) _buildRosterStatusFilterRow(),
          if (_activeSegment == 2) _buildAccountStatusFilterRow(approvalController),

          Expanded(
            child: _buildActiveContent(rosterController, approvalController),
          ),
        ],
      ),

    );
  }

  /// Directs dynamic content selection based on the active Segment index.
  Widget _buildActiveContent(AdminRosterController rosterController, AdminApprovalController approvalController) {
    switch (_activeSegment) {
      case 0:
        return Obx(() {
          if (rosterController.isLoading.value) {
            return const Center(child: CupertinoActivityIndicator(radius: 16));
          }
          return RefreshIndicator(
            onRefresh: rosterController.refresh,
            color: primaryRed,
            child: _buildImportAndAddView(context, rosterController),
          );
        });
      case 1:
        return Obx(() {
          if (rosterController.isLoading.value) {
            return const Center(child: CupertinoActivityIndicator(radius: 16));
          }
          if (rosterController.errorMessage.value != null) {
            return Center(child: Text(rosterController.errorMessage.value!));
          }
          return RefreshIndicator(
            onRefresh: rosterController.refresh,
            color: primaryRed,
            child: _buildRosterListView(rosterController),
          );
        });
      case 2:
        return Obx(() {
          if (approvalController.isLoading.value) {
            return const Center(child: CupertinoActivityIndicator(radius: 16));
          }
          if (approvalController.errorMessage.value != null) {
            return Center(child: Text(approvalController.errorMessage.value!));
          }
          return RefreshIndicator(
            onRefresh: approvalController.fetchPending,
            color: primaryRed,
            child: _buildAccountsListView(approvalController),
          );
        });
      default:
        return const SizedBox.shrink();
    }
  }

  /// Horizontal scrolling filter capsule for Claimed/Unclaimed Roster DB entries
  Widget _buildRosterStatusFilterRow() {
    final filters = ['All', 'Claimed', 'Unclaimed'];

    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: filters.length,
        itemBuilder: (context, index) {
          final filterLabel = filters[index];
          final isSelected = _statusFilter == filterLabel;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => setState(() => _statusFilter = filterLabel),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.black : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? Colors.black : Colors.grey.shade300,
                    width: 1,
                  ),
                ),
                child: Center(
                  child: Text(
                    filterLabel,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: isSelected ? Colors.white : Colors.grey.shade800,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// Horizontal scrolling filter capsule for Registered Accounts (Pending, Approved, Rejected)
  Widget _buildAccountStatusFilterRow(AdminApprovalController controller) {
    final filters = ['Pending', 'Approved', 'Rejected'];

    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: filters.length,
        itemBuilder: (context, index) {
          final filterLabel = filters[index];
          final isSelected = _accountFilter == filterLabel;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () {
                setState(() => _accountFilter = filterLabel);
                controller.fetchPending(filterLabel);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.black : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? Colors.black : Colors.grey.shade300,
                    width: 1,
                  ),
                ),
                child: Center(
                  child: Text(
                    filterLabel,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: isSelected ? Colors.white : Colors.grey.shade800,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// Segment 0: Combined Bulk Import & Manual Add Card View
  Widget _buildImportAndAddView(BuildContext context, AdminRosterController controller) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: [
        // Card 1: Bulk Import Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Row(
                children: [
                  Icon(CupertinoIcons.doc_on_clipboard_fill, color: primaryRed, size: 20),
                  SizedBox(width: 8),
                  Text('Bulk Import', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Two columns expected: school ID number, then full name. Header row is skipped.',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade500, height: 1.4),
              ),
              const SizedBox(height: 20),

              const Padding(
                padding: EdgeInsets.only(left: 4, bottom: 6),
                child: Text('Account Type', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  border: Border.all(color: Colors.grey.shade200),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedImportType,
                    isExpanded: true,
                    icon: const Icon(CupertinoIcons.chevron_down, size: 16, color: Colors.grey),
                    items: const [
                      DropdownMenuItem(value: 'teacher', child: Text('Teachers')),
                      DropdownMenuItem(value: 'student', child: Text('Students')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _selectedImportType = value);
                      }
                    },
                  ),
                ),
              ),

              if (_selectedImportType == 'student') ...[
                const SizedBox(height: 16),
                const Padding(
                  padding: EdgeInsets.only(left: 4, bottom: 6),
                  child: Text('Target Section', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    border: Border.all(color: Colors.grey.shade200),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: controller.selectedSectionId.value,
                      hint: const Text('Select target section'),
                      isExpanded: true,
                      icon: const Icon(CupertinoIcons.chevron_down, size: 16, color: Colors.grey),
                      items: controller.sections
                          .map((s) => DropdownMenuItem(
                        value: s.id,
                        child: Text('${s.yearLevel ?? ''} — ${s.name}'.trim()),
                      ))
                          .toList(),
                      onChanged: (v) => controller.selectedSectionId.value = v,
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 20),

              Obx(() {
                final isParsing = controller.isParsingImport.value;

                return CupertinoButton(
                  color: primaryRed,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  borderRadius: BorderRadius.circular(10),
                  onPressed: isParsing
                      ? null
                      : () async {
                    await controller.pickAndParseRosterExcel(_selectedImportType);
                    if (controller.stagedRows.isNotEmpty) {
                      // ignore: use_build_context_synchronously
                      _showImportPreviewModal(context, controller);
                    }
                  },
                  child: isParsing
                      ? const CupertinoActivityIndicator(color: Colors.white)
                      : Text(
                    'Import ${_selectedImportType == 'teacher' ? 'Teachers' : 'Students'}',
                    style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
                  ),
                );
              }),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Card 2: Manual Single Entry Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Row(
                children: [
                  Icon(CupertinoIcons.person_badge_plus_fill, color: primaryRed, size: 20),
                  SizedBox(width: 8),
                  Text('Manual Entry', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Add an individual account entry directly into the operational database system.',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade500, height: 1.4),
              ),
              const SizedBox(height: 20),
              CupertinoButton(
                color: primaryRed,
                padding: const EdgeInsets.symmetric(vertical: 12),
                borderRadius: BorderRadius.circular(10),
                onPressed: () => _showAddDialog(context, controller),
                child: const Text(
                  'Add Individual Entry',
                  style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Segment 1: Filtered Roster Entries List view (Database Records)
  Widget _buildRosterListView(AdminRosterController controller) {
    final filteredRoster = controller.roster.where((entry) {
      if (_statusFilter == 'All') return true;
      if (_statusFilter == 'Claimed') return entry.claimed == true;
      if (_statusFilter == 'Unclaimed') return entry.claimed == false;
      return true;
    }).toList();

    if (filteredRoster.isEmpty) {
      return ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Icon(CupertinoIcons.person_3_fill, size: 48, color: Colors.grey.shade300),
                const SizedBox(height: 12),
                Text(
                  _statusFilter == 'All' ? 'No one added yet.' : 'No entries found.',
                  style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey.shade700),
                ),
                const SizedBox(height: 4),
                Text(
                  _statusFilter == 'All'
                      ? 'Switch to the "Import & Add" tab to start adding users.'
                      : 'No accounts match the "$_statusFilter" status filter.',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 100),
      itemCount: filteredRoster.length,
      itemBuilder: (context, index) {
        final entry = filteredRoster[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              leading: CircleAvatar(
                backgroundColor: primaryRed.withValues(alpha: 0.1),
                child: Text(
                  entry.role.isNotEmpty ? entry.role[0].toUpperCase() : '?',
                  style: const TextStyle(color: primaryRed, fontWeight: FontWeight.bold),
                ),
              ),
              title: Text(entry.fullName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('${entry.schoolIdNumber} · ${entry.role.capitalizeFirst}', style: TextStyle(color: Colors.grey.shade600)),
              ),
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: entry.claimed
                      ? Colors.green.withValues(alpha: 0.15)
                      : Colors.orange.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  entry.claimed ? 'Claimed' : 'Unclaimed',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: entry.claimed ? Colors.green.shade700 : Colors.orange.shade800,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Segment 2: Signup Accounts Verification List view
  Widget _buildAccountsListView(AdminApprovalController controller) {
    final filteredAccounts = controller.pending;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${filteredAccounts.length} Accounts',
                style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w600),
              ),
              IconButton(
                icon: const Icon(CupertinoIcons.refresh, size: 20, color: primaryRed),
                onPressed: controller.isLoading.value ? null : () => controller.fetchPending(),
              ),
            ],
          ),
        ),

        Expanded(
          child: RefreshIndicator(
            onRefresh: controller.fetchPending,
            color: primaryRed,
            child: filteredAccounts.isEmpty
                ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                const SizedBox(height: 100),
                Center(
                  child: Column(
                    children: [
                      Icon(
                        _accountFilter == 'Pending'
                            ? CupertinoIcons.checkmark_seal_fill
                            : (_accountFilter == 'Approved' ? CupertinoIcons.checkmark_circle : CupertinoIcons.xmark_circle),
                        size: 64,
                        color: _accountFilter == 'Pending'
                            ? Colors.green.withValues(alpha: 0.4)
                            : Colors.grey.shade400,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _accountFilter == 'Pending' ? 'All Caught Up' : 'No $_accountFilter Accounts',
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ],
            )
                : ListView.builder(
              padding: const EdgeInsets.only(left: 16, right: 16, top: 0, bottom: 100),
              itemCount: filteredAccounts.length,
              itemBuilder: (context, index) {
                final profile = filteredAccounts[index];
                return Obx(() {
                  final isApproving = controller.approvingId.value == profile.id;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      clipBehavior: Clip.antiAlias,
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        leading: CircleAvatar(
                          backgroundColor: primaryRed.withValues(alpha: 0.1),
                          child: Text(
                            profile.role.isNotEmpty ? profile.role[0].toUpperCase() : '?',
                            style: const TextStyle(
                              color: primaryRed,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(
                          profile.fullName,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 17),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            '${profile.role.capitalizeFirst} · ID: ${profile.schoolIdNumber ?? '—'}',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        ),
                        trailing: _buildAccountTrailing(profile, controller, isApproving),
                      ),
                    ),
                  );
                });
              },
            ),
          ),
        ),
      ],
    );
  }

  /// Renders dynamic trailing status widgets for registered Accounts.
  Widget _buildAccountTrailing(dynamic profile, AdminApprovalController controller, bool isApproving) {
    if (_accountFilter == 'Approved') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Text(
          'Approved',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.green,
          ),
        ),
      );
    } else if (_accountFilter == 'Rejected') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Text(
          'Rejected',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.red,
          ),
        ),
      );
    } else {
      if (isApproving) {
        return const SizedBox(
          height: 32,
          width: 32,
          child: Padding(
            padding: EdgeInsets.all(4.0),
            child: CupertinoActivityIndicator(radius: 10),
          ),
        );
      }
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CupertinoButton(
            color: Colors.red.withValues(alpha: 0.1),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            borderRadius: BorderRadius.circular(14),
            minimumSize: const Size(0, 32),
            onPressed: () => _confirmReject(context, controller, profile),
            child: const Text(
              'Reject',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.red,
              ),
            ),
          ),
          const SizedBox(width: 8),
          CupertinoButton(
            color: primaryRed,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            borderRadius: BorderRadius.circular(14),
            minimumSize: const Size(0, 32),
            onPressed: () => controller.approve(profile.id),
            child: const Text(
              'Approve',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ],
      );
    }
  }

  Future<void> _confirmReject(
      BuildContext context,
      AdminApprovalController controller,
      dynamic profile,
      ) async {
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Reject this account?'),
        content: Text(
          '${profile.fullName} will not be able to sign in. You can still find them under the "Rejected" filter afterward.',
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      controller.reject(profile.id);
    }
  }
}

/// Standalone element keeping the text input controllers alive and isolated from Getx reactive rebuild loops
class _StagedRowCard extends StatefulWidget {
  final ParsedRosterRow row;
  final ValueChanged<String> onNameChanged;
  final ValueChanged<String> onIdChanged;
  final VoidCallback onDelete;

  const _StagedRowCard({
    required this.row,
    required this.onNameChanged,
    required this.onIdChanged,
    required this.onDelete,
    super.key,
  });

  @override
  State<_StagedRowCard> createState() => _StagedRowCardState();
}

class _StagedRowCardState extends State<_StagedRowCard> {
  late TextEditingController _nameController;
  late TextEditingController _idController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.row.fullName);
    _idController = TextEditingController(text: widget.row.schoolId);
  }

  @override
  void didUpdateWidget(covariant _StagedRowCard oldWidget) {
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
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
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
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.blueGrey.shade600,
                    letterSpacing: 0.5,
                  ),
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
            style: const TextStyle(fontSize: 15, color: Colors.black87),
            decoration: InputDecoration(
              isDense: true,
              prefixText: 'Name:  ',
              prefixStyle: TextStyle(fontWeight: FontWeight.w500, color: Colors.grey.shade500),
              border: InputBorder.none,
              hintText: 'Enter Name',
              hintStyle: TextStyle(color: Colors.grey.shade400),
            ),
            onChanged: widget.onNameChanged,
          ),
          Divider(height: 12, color: Colors.grey.shade100),

          TextField(
            controller: _idController,
            style: const TextStyle(fontSize: 15, color: Colors.black87),
            decoration: InputDecoration(
              isDense: true,
              prefixText: 'ID:      ',
              prefixStyle: TextStyle(fontWeight: FontWeight.w500, color: Colors.grey.shade500),
              border: InputBorder.none,
              hintText: 'Enter School ID',
              hintStyle: TextStyle(color: Colors.grey.shade400),
            ),
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
                      style: TextStyle(
                        fontSize: 12.5,
                        color: Colors.amber.shade900,
                        fontWeight: FontWeight.w500,
                      ),
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