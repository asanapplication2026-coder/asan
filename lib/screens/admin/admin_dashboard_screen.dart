import 'package:asan_evac_app/screens/widgets/create_section_modal.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

// Existing screens and controllers
import '../../controllers/admin/admin_section_controller.dart';
import '../../controllers/admin/admin_dashboard_controller.dart';

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

  // Single pull-to-refresh entry point for everything in the body:
  // active-drill banner, head-count analytics, the grade filter chips
  // (which derive from `controller.sections`), and the section list itself.
  // Note: AdminDashboardController.fetchActiveDrill() already re-fetches
  // analytics internally (via the private _fetchAnalytics) whenever a
  // drill is active, so there's no separate analytics call needed here.
  Future<void> _refreshDashboard(
      AdminSectionController controller,
      AdminDashboardController dashboardController,
      ) async {
    await Future.wait([
      controller.fetchSections(),
      dashboardController.fetchActiveDrill(),
    ]);
  }

  Future<void> _confirmCompleteDrill(
      BuildContext context,
      AdminDashboardController dashboardController,
      ) async {
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Complete Drill'),
        content: const Text(
          'Mark this drill/emergency as completed? This will end live status tracking for it.',
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(ctx, false),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text('Complete'),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await dashboardController.completeActiveDrill();
      if (success && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Drill marked as completed.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(AdminSectionController());
    final dashboardController = Get.put(AdminDashboardController());

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
      body: RefreshIndicator(
        onRefresh: () => _refreshDashboard(controller, dashboardController),
        color: primaryRed,
        child: Column(
          children: [
            _buildActiveDrillBanner(dashboardController),
            _buildAnalyticsSummary(dashboardController),
            _buildFilterRow(controller),
            Expanded(child: _buildBody(controller)),
          ],
        ),
      ),
    );
  }

  // Shows a red banner with a "Complete" action, only while a drill/emergency
  // is active. Resolves: "add completed drill or emergency".
  Widget _buildActiveDrillBanner(AdminDashboardController dashboardController) {
    return Obx(() {
      final drill = dashboardController.activeDrill.value;
      if (dashboardController.isDrillLoading.value || drill == null) {
        return const SizedBox.shrink();
      }

      return Container(
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: primaryRed,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            const Icon(
              CupertinoIcons.exclamationmark_triangle_fill,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                (drill.title?.isNotEmpty ?? false)
                    ? 'Active drill: ${drill.title}'
                    : 'Drill in progress',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            CupertinoButton(
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              onPressed: () => _confirmCompleteDrill(context, dashboardController),
              child: const Text(
                'Complete',
                style: TextStyle(
                  color: accentYellow,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      );
    });
  }

  // Head count per status category + head count per section.
  // Only rendered while a drill/emergency is active.
  // Resolves: "show all the head count per category" and
  // "show per section head count".
  Widget _buildAnalyticsSummary(AdminDashboardController dashboardController) {
    return Obx(() {
      final drill = dashboardController.activeDrill.value;
      if (drill == null) return const SizedBox.shrink();

      final statusCounts = dashboardController.statusHeadCounts;
      final sectionCounts = dashboardController.sectionHeadCounts;

      return Container(
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        padding: const EdgeInsets.all(16),
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Head Count by Status',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
            const SizedBox(height: 10),
            if (dashboardController.isAnalyticsLoading.value && statusCounts.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: CupertinoActivityIndicator(),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: AdminDashboardController.statusCategories.map((status) {
                  final count = statusCounts[status] ?? 0;
                  return _StatusChip(label: status, count: count);
                }).toList(),
              ),
            if (sectionCounts.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                'Head Count by Section',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
              const SizedBox(height: 10),
              ...sectionCounts.entries.map(
                    (e) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(e.key, style: TextStyle(color: Colors.grey.shade800)),
                      Text(
                        '${e.value}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      );
    });
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

      return ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
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

class _StatusChip extends StatelessWidget {
  final String label;
  final int count;

  const _StatusChip({required this.label, required this.count});

  Color _colorForStatus(String status) {
    switch (status) {
      case 'safe':
        return Colors.green;
      case 'injured':
        return Colors.orange;
      case 'missing':
        return primaryRed;
      case 'searching':
        return accentYellow;
      case 'absent':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _colorForStatus(label);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        '${label[0].toUpperCase()}${label.substring(1)}: $count',
        style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 13),
      ),
    );
  }
}