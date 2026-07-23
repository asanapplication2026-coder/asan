import 'dart:ui';
import 'package:asan_evac_app/screens/teacher/chat_screen.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart'; // Added for OpenStreetMap support
import 'package:get/get.dart';
import 'package:latlong2/latlong.dart'; // Added for coordinate mapping
import '../../controllers/teacher/head_count_controller.dart';
import '../../models/head_count_status.dart';

const _primaryRed = Color(0xFF7B1113);
const _iosBackground = Color(0xFFF2F2F7);

class HeadcountScreen extends StatefulWidget {
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
  State<HeadcountScreen> createState() => _HeadcountScreenState();
}

class _HeadcountScreenState extends State<HeadcountScreen> {
  late final controller = Get.put(
    HeadcountController(drillEventId: widget.drillEventId, sectionId: widget.sectionId),
    tag: '${widget.drillEventId}-${widget.sectionId}',
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _iosBackground,
      extendBody: true,
      bottomNavigationBar: Obx(() => _buildModernTabBar()),
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
            _StudentsTab(controller: controller, sectionLabel: widget.sectionLabel),
            ChatScreen(sectionId: widget.sectionId, drillEventId: widget.drillEventId),
            _OverviewTab(controller: controller),
            const _DistressMapTab(),
          ],
        );
      }),
    );
  }

  Widget _buildModernTabBar() {
    final currentTab = controller.selectedTab.value;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, bottomPadding > 0 ? bottomPadding : 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            height: 72,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.4),
                width: 0.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildTabItem(index: 0, icon: CupertinoIcons.person_2_fill, label: 'Roster', active: currentTab == 0),
                _buildTabItem(index: 1, icon: CupertinoIcons.chat_bubble_2_fill, label: 'Chat', active: currentTab == 1),
                _buildTabItem(index: 2, icon: CupertinoIcons.chart_pie_fill, label: 'Overview', active: currentTab == 2),

                Container(
                  height: 32,
                  width: 1,
                  color: CupertinoColors.separator.withValues(alpha: 0.3),
                ),

                _buildTabItem(index: 3, icon: CupertinoIcons.exclamationmark_shield_fill, label: 'Distress', active: currentTab == 3, isEmergency: true),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabItem({
    required int index,
    required IconData icon,
    required String label,
    required bool active,
    bool isEmergency = false,
  }) {
    final activeColor = isEmergency ? CupertinoColors.systemRed : _primaryRed;
    final inactiveColor = isEmergency ? CupertinoColors.systemRed.withValues(alpha: 0.4) : CupertinoColors.inactiveGray;

    return Expanded(
      child: GestureDetector(
        onTap: () => controller.selectedTab.value = index,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              transform: Matrix4.identity()..scale(active ? 1.05 : 1.0),
              child: Icon(
                icon,
                color: active ? activeColor : inactiveColor,
                size: 23,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                color: active ? activeColor : inactiveColor,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// REFACTORED: DISTRESS MAP TAB WITH REAL OPEN STREET MAPS LAYER
// ============================================================================
class _DistressMapTab extends StatelessWidget {
  const _DistressMapTab();

  @override
  Widget build(BuildContext context) {
    // Structured Dummy Data for Students
    final dummyDistressAlerts = [
      {
        'name': 'Juan Dela Cruz',
        'id': '2021-10432',
        'loc': 'Building A - Near Main Entrance',
        'time': '2m ago',
        'coords': const LatLng(11.5845, 122.7540) // Dummy coordinates inside Roxas City area
      },
      {
        'name': 'Maria Clara',
        'id': '2022-11904',
        'loc': 'Gymnasium East Bleachers',
        'time': '5m ago',
        'coords': const LatLng(11.5860, 122.7565)
      },
    ];

    return Stack(
      children: [
        // 1. OPEN STREET MAP IMPLEMENTATION
        FlutterMap(
          options: MapOptions(
            initialCenter: const LatLng(11.5853, 122.7550), // Center focus point
            initialZoom: 16.0,
            maxZoom: 19.0,
            minZoom: 12.0,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.asan.evac.app',
            ),
            MarkerLayer(
              markers: dummyDistressAlerts.map((alert) {
                return Marker(
                  point: alert['coords'] as LatLng,
                  width: 75,
                  height: 75,
                  child: _buildMapPinWidget(name: alert['name'] as String),
                );
              }).toList(),
            ),
          ],
        ),

        // 2. TOP FLOATING EMERGENCY STATUS HEADER
        Positioned(
          top: 60,
          left: 16,
          right: 16,
          child: SafeArea(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: CupertinoColors.systemRed.withValues(alpha: 0.9),
                  ),
                  child: Row(
                    children: [
                      const Icon(CupertinoIcons.waveform_path_ecg, color: Colors.white, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '${dummyDistressAlerts.length} Active Distress Signals Detected',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              letterSpacing: -0.2
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),

        // 3. iOS SLIDING ACTION SHEET OVERLAY
        Positioned(
          left: 16,
          right: 16,
          bottom: 104, // Space maintained perfectly clear above floating custom navbar
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.96),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 24,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 5,
                    decoration: BoxDecoration(
                      color: CupertinoColors.systemGrey4,
                      borderRadius: BorderRadius.circular(2.5),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Critical Broadcast Roster',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: -0.3),
                ),
                const SizedBox(height: 12),
                ListView.separated(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: dummyDistressAlerts.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final item = dummyDistressAlerts[index];
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: CupertinoColors.systemGrey6,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: const BoxDecoration(
                              color: CupertinoColors.destructiveRed,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(CupertinoIcons.exclamationmark_triangle_fill, color: Colors.white, size: 16),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item['name'] as String, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                                const SizedBox(height: 2),
                                Text(item['loc'] as String, style: const TextStyle(fontSize: 12, color: CupertinoColors.secondaryLabel, fontWeight: FontWeight.w500)),
                              ],
                            ),
                          ),
                          Text(
                            item['time'] as String,
                            style: const TextStyle(fontSize: 11, color: CupertinoColors.systemRed, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    );
                  },
                )
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Refactored Map Marker component layout for standard rendering inside MarkerLayer
  Widget _buildMapPinWidget({required String name}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            color: CupertinoColors.black,
            borderRadius: BorderRadius.circular(6),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 4)],
          ),
          child: Text(
            name.split(' ').first + '.', // Inline compression to save space on map grids
            style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(height: 2),
        Stack(
          alignment: Alignment.center,
          children: [
            _AnimatedMapPulseRing(),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: CupertinoColors.systemRed,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 1))],
              ),
              child: const Icon(
                CupertinoIcons.person_fill,
                color: Colors.white,
                size: 14,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// Built-in looping widget emitting clear beacon ripple signals over coordinates
class _AnimatedMapPulseRing extends StatefulWidget {
  @override
  State<_AnimatedMapPulseRing> createState() => _AnimatedMapPulseRingState();
}

class _AnimatedMapPulseRingState extends State<_AnimatedMapPulseRing> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return Container(
          width: 24 + (28 * _pulseController.value),
          height: 24 + (28 * _pulseController.value),
          decoration: BoxDecoration(
            color: CupertinoColors.systemRed.withValues(alpha: 1.0 - _pulseController.value),
            shape: BoxShape.circle,
          ),
        );
      },
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
                          color: Colors.black.withValues(alpha: 0.02),
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
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
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
                                    ? [BoxShadow(color: _primaryRed.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 4))]
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
                        color: Colors.black.withValues(alpha: 0.02),
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
                        return Obx(() => _StudentContactRow(
                          student: student,
                          isSaving: controller.isSaving(student.rosterId),
                          justSaved: controller.wasRecentlySaved(student.rosterId),
                          onSetStatus: (status) => controller.setStatus(student.rosterId, status),
                        ));
                      },
                    ),
                  ),
                ),
              ),
            );
          }),
          const SliverToBoxAdapter(child: SizedBox(height: 140)),
        ],
      ),
    );
  }
}

class _StudentContactRow extends StatelessWidget {
  const _StudentContactRow({
    required this.student,
    required this.isSaving,
    required this.justSaved,
    required this.onSetStatus,
  });

  final dynamic student;
  final bool isSaving;
  final bool justSaved;
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
                  color: _primaryRed.withValues(alpha: 0.08),
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
              if (isSaving)
                const CupertinoActivityIndicator(radius: 10)
              else if (justSaved)
                const Icon(CupertinoIcons.check_mark_circled_solid, color: Color(0xFF4CAF50), size: 20),
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
                      _buildModernStatusCard('Missing', data.missingCount, _primaryRed, _primaryRed.withValues(alpha: 0.08), CupertinoIcons.exclamationmark_triangle_fill),
                      _buildModernStatusCard('Absent', data.absentCount, const Color(0xFF757575), const Color(0xFFF5F5F5), CupertinoIcons.xmark_circle_fill),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildStatusChart(data),
                  const SizedBox(height: 140),
                ],
              );
            }),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusChart(dynamic data) {
    final int safe = data.safeCount as int;
    final int injured = data.injuredCount as int;
    final int missing = data.missingCount as int;
    final int absent = data.absentCount as int;
    final int total = safe + injured + missing + absent;

    const safeColor = Color(0xFF4CAF50);
    const injuredColor = Color(0xFFFF9800);
    const absentColor = Color(0xFF757575);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Status Breakdown',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 20),
          if (total == 0)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'No headcount data yet',
                  style: TextStyle(color: CupertinoColors.secondaryLabel, fontSize: 14, fontWeight: FontWeight.w500),
                ),
              ),
            )
          else
            SizedBox(
              height: 180,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 3,
                  centerSpaceRadius: 42,
                  startDegreeOffset: -90,
                  sections: [
                    if (safe > 0)
                      PieChartSectionData(
                        value: safe.toDouble(),
                        color: safeColor,
                        radius: 52,
                        title: '$safe',
                        titleStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white),
                      ),
                    if (injured > 0)
                      PieChartSectionData(
                        value: injured.toDouble(),
                        color: injuredColor,
                        radius: 52,
                        title: '$injured',
                        titleStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white),
                      ),
                    if (missing > 0)
                      PieChartSectionData(
                        value: missing.toDouble(),
                        color: _primaryRed,
                        radius: 52,
                        title: '$missing',
                        titleStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white),
                      ),
                    if (absent > 0)
                      PieChartSectionData(
                        value: absent.toDouble(),
                        color: absentColor,
                        radius: 52,
                        title: '$absent',
                        titleStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white),
                      ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 20,
            runSpacing: 10,
            children: [
              _legendItem('Safe', safeColor),
              _legendItem('Injured', injuredColor),
              _legendItem('Missing', _primaryRed),
              _legendItem('Absent', absentColor),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: CupertinoColors.secondaryLabel,
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
            color: Colors.black.withValues(alpha: 0.02),
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
        border: Border.all(color: primaryColor.withValues(alpha: 0.1), width: 1),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.15),
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
                  color: primaryColor.withValues(alpha: 0.8),
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