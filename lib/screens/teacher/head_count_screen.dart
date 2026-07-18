import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/head_count_controller.dart';
import '../../models/head_count_status.dart';

const _primaryRed = Color(0xFF7B1113);
const _iosBackground = Color(0xFFF2F2F7);

class HeadcountScreen extends StatelessWidget {
  const HeadcountScreen({
    super.key,
    required this.drillEventId,
    required this.sectionId,
    required this.sectionLabel,
  });

  final String drillEventId;
  final String sectionId;
  final String sectionLabel;

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(
      HeadcountController(drillEventId: drillEventId, sectionId: sectionId),
      tag: '$drillEventId-$sectionId',
    );

    return Scaffold(
      backgroundColor: _iosBackground,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: Obx(
              () => CupertinoTabBar(
            currentIndex: controller.selectedTab.value,
            backgroundColor: Colors.white.withOpacity(0.9),
            activeColor: _primaryRed,
            inactiveColor: CupertinoColors.inactiveGray,
            border: const Border(top: BorderSide(color: Colors.transparent)),
            onTap: (val) => controller.selectedTab.value = val,
            items: const [
              BottomNavigationBarItem(
                icon: Padding(
                  padding: EdgeInsets.only(bottom: 4),
                  child: Icon(CupertinoIcons.person_2_fill, size: 24),
                ),
                label: 'Students',
              ),
              BottomNavigationBarItem(
                icon: Padding(
                  padding: EdgeInsets.only(bottom: 4),
                  child: Icon(CupertinoIcons.chart_pie_fill, size: 24),
                ),
                label: 'Overview',
              ),
            ],
          ),
        ),
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CupertinoActivityIndicator(radius: 14));
        }
        if (controller.errorMessage.value != null) {
          return Center(
            child: Text(
              controller.errorMessage.value!,
              style: const TextStyle(color: CupertinoColors.secondaryLabel),
            ),
          );
        }

        return IndexedStack(
          index: controller.selectedTab.value,
          children: [
            _StudentsTab(controller: controller, sectionLabel: sectionLabel),
            _OverviewTab(controller: controller),
          ],
        );
      }),
    );
  }
}

// ============================================================================
// 1. STUDENTS TAB
// ============================================================================
class _StudentsTab extends StatelessWidget {
  const _StudentsTab({required this.controller, required this.sectionLabel});

  final HeadcountController controller;
  final String sectionLabel;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: controller.refresh,
      color: _primaryRed,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        slivers: [
          SliverAppBar.large(
            backgroundColor: _iosBackground,
            surfaceTintColor: Colors.transparent,
            stretch: true,
            leadingWidth: 85,
            leading: GestureDetector(
              onTap: () => Get.back(),
              behavior: HitTestBehavior.opaque,
              child: const Row(
                children: [
                  SizedBox(width: 8),
                  Icon(CupertinoIcons.back, color: _primaryRed, size: 26),
                  SizedBox(width: 2),
                  Text(
                    'Back',
                    style: TextStyle(
                      color: _primaryRed,
                      fontSize: 17,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
            ),
            title: Text(
              sectionLabel,
              style: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.5),
            ),
          ),
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Container(
                    decoration: BoxDecoration(
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.02),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: CupertinoSearchTextField(
                      onChanged: controller.setSearchQuery,
                      placeholder: 'Search name or ID',
                      backgroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      borderRadius: BorderRadius.circular(12),
                      prefixInsets: const EdgeInsets.only(left: 12),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: SizedBox(
                    height: 36,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      scrollDirection: Axis.horizontal,
                      itemCount: ['All', ...HeadcountStatus.all].length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final filter = ['All', ...HeadcountStatus.all][index];

                        return Obx(() {
                          final isSelected = controller.selectedFilter.value == filter;

                          return GestureDetector(
                            onTap: () => controller.selectedFilter.value = filter,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(horizontal: 20),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: isSelected ? _primaryRed : CupertinoColors.systemGrey6,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: isSelected
                                    ? [BoxShadow(color: _primaryRed.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))]
                                    : [],
                              ),
                              child: Text(
                                filter,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: isSelected ? Colors.white : CupertinoColors.secondaryLabel,
                                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                                ),
                              ),
                            ),
                          );
                        });
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          Obx(() {
            if (controller.filteredStudents.isEmpty) {
              return const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(40.0),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(CupertinoIcons.search, size: 40, color: CupertinoColors.systemFill),
                        SizedBox(height: 12),
                        Text(
                          'No students found',
                          style: TextStyle(color: CupertinoColors.secondaryLabel, fontSize: 16, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            return SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.02),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: EdgeInsets.zero,
                      itemCount: controller.filteredStudents.length,
                      separatorBuilder: (context, index) => const Divider(
                        height: 1,
                        thickness: 0.5,
                        indent: 20,
                        endIndent: 20,
                        color: CupertinoColors.systemGrey5,
                      ),
                      itemBuilder: (context, index) {
                        final student = controller.filteredStudents[index];
                        return _StudentContactRow(
                          student: student,
                          isSaving: controller.isSaving(student.rosterId),
                          onSetStatus: (status) => controller.setStatus(student.rosterId, status),
                        );
                      },
                    ),
                  ),
                ),
              ),
            );
          }),
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }
}

class _StudentContactRow extends StatelessWidget {
  const _StudentContactRow({
    super.key,
    required this.student,
    required this.isSaving,
    required this.onSetStatus,
  });

  final dynamic student;
  final bool isSaving;
  final ValueChanged<String> onSetStatus;

  String get _initials {
    final parts = student.fullName.trim().split(RegExp(r'\s+'));
    if (student.fullName.isEmpty) return '?';
    final firstInitial = parts.first.isNotEmpty ? parts.first.substring(0, 1) : '';
    if (parts.length == 1) return firstInitial.toUpperCase();
    final lastInitial = parts.last.isNotEmpty ? parts.last.substring(0, 1) : '';
    return '$firstInitial$lastInitial'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final status = student.status;
    final Map<String, Widget> segmentWidgets = {
      for (var s in HeadcountStatus.all)
        s: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Text(
            HeadcountStatus.label(s),
            style: TextStyle(
              fontSize: 13,
              fontWeight: status == s ? FontWeight.w700 : FontWeight.w600,
              color: status == s ? CupertinoColors.white : CupertinoColors.secondaryLabel,
            ),
          ),
        )
    };

    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _primaryRed.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  _initials,
                  style: const TextStyle(
                    color: _primaryRed,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      student.fullName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 17,
                        letterSpacing: -0.3,
                        color: CupertinoColors.black,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      student.schoolIdNumber,
                      style: const TextStyle(
                        fontSize: 13,
                        color: CupertinoColors.secondaryLabel,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSaving) const CupertinoActivityIndicator(radius: 10),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: CupertinoSlidingSegmentedControl<String>(
              groupValue: status,
              thumbColor: status != null
                  ? HeadcountStatus.color(status).withValues(alpha: 1.0)
                  : CupertinoColors.white,
              backgroundColor: CupertinoColors.systemGrey6,
              children: segmentWidgets,
              onValueChanged: (val) {
                if (val != null && !isSaving) onSetStatus(val);
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// 2. OVERVIEW TAB
// ============================================================================
class _OverviewTab extends StatelessWidget {
  const _OverviewTab({required this.controller});

  final HeadcountController controller;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverAppBar.large(
          title: const Text('Overview', style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.5)),
          backgroundColor: _iosBackground,
          leadingWidth: 85,
          leading: GestureDetector(
            onTap: () => Get.back(),
            behavior: HitTestBehavior.opaque,
            child: const Row(
              children: [
                SizedBox(width: 8),
                Icon(CupertinoIcons.back, color: _primaryRed, size: 26),
                SizedBox(width: 2),
                Text(
                  'Back',
                  style: TextStyle(
                    color: _primaryRed,
                    fontSize: 17,
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Obx(() {
              final data = controller.realtimeKpiData;
              final total = data.totalExpected;
              final counted = data.totalCounted;
              final double progress = total == 0 ? 0.0 : (counted / total);

              return Column(
                children: [
                  _buildMainKpiCard(counted, total, progress),
                  const SizedBox(height: 16),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    padding: EdgeInsets.zero,
                    children: [
                      _buildModernStatusCard('Safe', data.safeCount, const Color(0xFF4CAF50), const Color(0xFFE8F5E9), CupertinoIcons.checkmark_shield_fill),
                      _buildModernStatusCard('Injured', data.injuredCount, const Color(0xFFFF9800), const Color(0xFFFFF3E0), CupertinoIcons.bandage_fill),
                      _buildModernStatusCard('Missing', data.missingCount, _primaryRed, _primaryRed.withOpacity(0.08), CupertinoIcons.exclamationmark_triangle_fill),
                      _buildModernStatusCard('Absent', data.absentCount, const Color(0xFF757575), const Color(0xFFF5F5F5), CupertinoIcons.xmark_circle_fill),
                    ],
                  ),
                  const SizedBox(height: 32),
                ],
              );
            }),
          ),
        ),
      ],
    );
  }

  Widget _buildMainKpiCard(int counted, int total, double progress) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                height: 120,
                width: 120,
                child: CircularProgressIndicator(
                  value: progress,
                  color: _primaryRed,
                  backgroundColor: CupertinoColors.systemGrey6,
                  strokeWidth: 10,
                  strokeCap: StrokeCap.round,
                ),
              ),
              Text(
                '${(progress * 100).toInt()}%',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            '$counted of $total Accounted',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
              color: CupertinoColors.black,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Live Headcount Progress',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: CupertinoColors.secondaryLabel,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernStatusCard(String label, int count, Color primaryColor, Color bgColor, IconData icon) {
    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: primaryColor.withOpacity(0.1), width: 1),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: primaryColor, size: 24),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  color: primaryColor,
                  letterSpacing: -1.5,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  color: primaryColor.withOpacity(0.8),
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}