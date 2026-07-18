import 'package:asan_evac_app/screens/widgets/create_section_modal.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

// Existing screens and controllers
import '../../controllers/admin_section_controller.dart';

// Updated Branding Colors
const Color primaryRed = Color(0xFF751018);
const Color accentYellow = Color(0xFFFDBF44);

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  String _selectedGradeFilter = 'All';

  // Helper method to present the Bottom Sheet and handle refresh on success
  void _openCreateSectionModal(BuildContext context, AdminSectionController controller) async {
    final created = await Get.bottomSheet<bool>(
      const CreateSectionModal(),
      isScrollControlled: true, // Allows the modal to resize gracefully for keyboards
      ignoreSafeArea: false,
    );
    if (created == true) {
      controller.fetchSections();
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(AdminSectionController());

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      extendBody: true,
      appBar: AppBar(
        backgroundColor: const Color(0xFFF2F2F7),
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          'Sections',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
            color: primaryRed,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(
              CupertinoIcons.add,
              color: primaryRed,
              size: 26,
            ),
            onPressed: () => _openCreateSectionModal(context, controller),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Column(
        children: [
          _buildFilterRow(controller),
          Expanded(child: _buildBody(controller)),
        ],
      ),
    );
  }

  Widget _buildFilterRow(AdminSectionController controller) {
    return Obx(() {
      if (controller.sections.isEmpty) return const SizedBox.shrink();

      final uniqueGrades = controller.sections
          .map((s) => s.yearLevel?.toString().trim() ?? '')
          .where((grade) => grade.isNotEmpty)
          .toSet()
          .toList();
      uniqueGrades.sort();

      final filters = ['All', ...uniqueGrades];

      return Container(
        height: 50,
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: filters.length,
          itemBuilder: (context, index) {
            final filterLabel = filters[index];
            final isSelected = _selectedGradeFilter == filterLabel;

            return Material(
              color: Colors.transparent,
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () =>
                      setState(() => _selectedGradeFilter = filterLabel),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected ? primaryRed : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected ? primaryRed : Colors.grey.shade300,
                        width: 1,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        filterLabel,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.w500,
                          color: isSelected
                              ? Colors.white
                              : Colors.grey.shade800,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      );
    });
  }

  Widget _buildBody(AdminSectionController controller) {
    return Obx(() {
      if (controller.isLoading.value) {
        return const Center(child: CupertinoActivityIndicator(radius: 16));
      }
      if (controller.errorMessage.value != null) {
        return Center(child: Text(controller.errorMessage.value!));
      }
      if (controller.sections.isEmpty) {
        return _buildEmptyState(controller);
      }

      final filteredSections = controller.sections.where((section) {
        if (_selectedGradeFilter == 'All') return true;
        return (section.yearLevel?.toString().trim() ?? '') ==
            _selectedGradeFilter;
      }).toList();

      if (filteredSections.isEmpty) {
        return Center(
          child: Text(
            'No sections found for "$_selectedGradeFilter"',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 16),
          ),
        );
      }

      return RefreshIndicator(
        onRefresh: controller.fetchSections,
        color: primaryRed,
        child: ListView.builder(
          padding: const EdgeInsets.only(
            left: 16,
            right: 16,
            top: 8,
            bottom: 100,
          ),
          itemCount: filteredSections.length,
          itemBuilder: (context, index) {
            final section = filteredSections[index];
            final isRostered = section.isRostered;

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
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isRostered
                          ? primaryRed.withValues(alpha: 0.1)
                          : accentYellow.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isRostered
                          ? CupertinoIcons.checkmark_seal_fill
                          : CupertinoIcons.hourglass,
                      color: isRostered ? primaryRed : accentYellow,
                      size: 24,
                    ),
                  ),
                  title: Text(
                    '${section.yearLevel ?? ''} — ${section.name}'.trim(),
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 17,
                    ),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Expected: ${section.numberOfStudents ?? '—'} students\n'
                          '${isRostered ? 'Rostered' : 'Not yet rostered'}',
                      style: TextStyle(color: Colors.grey.shade600, height: 1.3),
                    ),
                  ),
                  trailing: const Icon(
                    CupertinoIcons.chevron_right,
                    color: Colors.grey,
                    size: 18,
                  ),
                  onTap: () {},
                ),
              ),
            );
          },
        ),
      );
    });
  }

  Widget _buildEmptyState(AdminSectionController controller) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            CupertinoIcons.folder_badge_plus,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          const Text(
            'No sections yet',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          CupertinoButton(
            child: const Text('Create New Section', style: TextStyle(color: primaryRed)),
            onPressed: () => _openCreateSectionModal(context, controller),
          ),
        ],
      ),
    );
  }
}