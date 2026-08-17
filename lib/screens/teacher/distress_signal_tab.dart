import 'dart:ui';

import 'package:asan_evac_app/models/distress_signal_model.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:get/get.dart';
import 'package:latlong2/latlong.dart' hide Path;

import '../../controllers/teacher/distress_signal_controller.dart';

const _primaryRed = Color(0xFF7B1113);
const _iosBackground = Color(0xFFF2F2F7);

// 14.568488, 121.076232
class DistressSignalTab extends StatefulWidget {
  const DistressSignalTab({
    super.key,
    required this.drillEventId,
    this.studentDirectory,
  });

  final String drillEventId;

  /// Optional id -> display name map, since `distress_signals` only stores
  /// `roster_id`. Falls back to a shortened id when not provided.
  final Map<String, String>? studentDirectory;

  @override
  State<DistressSignalTab> createState() => _DistressSignalTabState();
}

class _DistressSignalTabState extends State<DistressSignalTab> {
  late final controller = Get.put(
    DistressSignalController(drillEventId: widget.drillEventId),
    tag: 'distress-${widget.drillEventId}',
  );

  String _nameFor(String rosterId) {
    final directory = widget.studentDirectory;
    if (directory != null && directory.containsKey(rosterId)) {
      return directory[rosterId]!;
    }
    return rosterId.length > 8 ? rosterId.substring(0, 8) : rosterId;
  }

  Color _channelColor(DistressChannel channel) {
    switch (channel) {
      case DistressChannel.app:
        return _primaryRed;
      case DistressChannel.sms:
        return const Color(0xFFCB6E17);
      case DistressChannel.missedCall:
        return const Color(0xFF6E3ACB);
    }
  }

  IconData _channelIcon(DistressChannel channel) {
    switch (channel) {
      case DistressChannel.app:
        return CupertinoIcons.exclamationmark_shield_fill;
      case DistressChannel.sms:
        return CupertinoIcons.chat_bubble_text_fill;
      case DistressChannel.missedCall:
        return CupertinoIcons.phone_down_fill;
    }
  }

  String _channelLabel(DistressChannel channel) {
    switch (channel) {
      case DistressChannel.app:
        return 'App';
      case DistressChannel.sms:
        return 'SMS';
      case DistressChannel.missedCall:
        return 'Missed Call';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _iosBackground,
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

        return RefreshIndicator(
          color: _primaryRed,
          onRefresh: controller.refresh,
          child: Stack(
            children: [
              _buildMap(),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(child: _buildHeader()),
              ),
              Positioned.fill(
                child: _buildFeedSheet(),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildMap() {
    return Obx(() {
      final pins = controller.mappableSignals;
      return FlutterMap(
        options: const MapOptions(
          initialCenter: LatLng(14.568488, 121.076232),
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
            markers: pins.map((signal) {
              return Marker(
                point: LatLng(signal.latitude!, signal.longitude!),
                width: 70,
                height: 70,
                child: _MapPin(
                  color: _channelColor(signal.channel),
                  icon: _channelIcon(signal.channel),
                ),
              );
            }).toList(),
          ),
        ],
      );
    });
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.4),
                width: 0.5,
              ),
            ),
            child: Obx(() {
              return Row(
                children: [
                  const Icon(
                    CupertinoIcons.exclamationmark_shield_fill,
                    color: _primaryRed,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Live Distress Alerts',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                  _countPill('${controller.totalCount}'),
                ],
              );
            }),
          ),
        ),
      ),
    );
  }

  Widget _countPill(String count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _primaryRed,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        count,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  // ⚠️ FIX: DraggableScrollableSheet's `builder` runs during Flutter's
  // layout phase (it's backed by a LayoutBuilder internally). The Obx used
  // to live *inside* that builder, so a Rx change mid-layout (e.g. a
  // realtime insert) re-entered layout and threw
  // '!_debugDoingThisLayout'. Wrapping the whole sheet in Obx instead means
  // rebuilds happen as an ordinary widget rebuild, not mid-layout.
  Widget _buildFeedSheet() {
    return Obx(() {
      final signals = controller.filteredSignals;
      return DraggableScrollableSheet(
        initialChildSize: 0.38,
        minChildSize: 0.14,
        maxChildSize: 0.85,
        builder: (context, scrollController) {
          return ClipRRect(
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(24),
            ),
            child: Container(
              color: Colors.white,
              child: CustomScrollView(
                controller: scrollController,
                slivers: [
                  SliverToBoxAdapter(
                    child: Column(
                      children: [
                        const SizedBox(height: 10),
                        Container(
                          width: 36,
                          height: 4,
                          decoration: BoxDecoration(
                            color: CupertinoColors.systemGrey4,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(height: 14),
                        _buildFilterChips(),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                  if (signals.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 32),
                        child: Center(
                          child: Text(
                            'No distress signals yet',
                            style: TextStyle(
                              color: CupertinoColors.secondaryLabel,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    )
                  else
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                            (context, index) => _signalTile(signals[index]),
                        childCount: signals.length,
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      );
    });
  }

  Widget _buildFilterChips() {
    final options = ['All', ...DistressChannel.values.map((c) => c.value)];
    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: options.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final value = options[index];
          final label = value == 'All'
              ? 'All'
              : _channelLabel(DistressChannel.fromValue(value));
          final active = controller.selectedChannelFilter.value == value;
          return GestureDetector(
            onTap: () => controller.selectedChannelFilter.value = value,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: active ? _primaryRed : CupertinoColors.systemGrey6,
                borderRadius: BorderRadius.circular(17),
              ),
              alignment: Alignment.center,
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: active ? Colors.white : CupertinoColors.secondaryLabel,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _signalTile(DistressSignal signal) {
    final color = _channelColor(signal.channel);
    final locationText = [
      signal.building,
      signal.floor,
    ].where((s) => s != null && s.isNotEmpty).join(' · ');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.15)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(_channelIcon(signal.channel), color: color, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          signal.isResolved
                              ? _nameFor(signal.rosterId!)
                              : (signal.studentName ?? 'Unknown sender'),
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                      if (!signal.isResolved) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Unresolved',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: Colors.orange,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (locationText.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      locationText,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: CupertinoColors.secondaryLabel,
                      ),
                    ),
                  ],
                  if (signal.message != null && signal.message!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      signal.message!,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _channelLabel(signal.channel),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _relativeTime(signal.createdAt),
                  style: const TextStyle(
                    fontSize: 11,
                    color: CupertinoColors.tertiaryLabel,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _relativeTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

class _MapPin extends StatelessWidget {
  const _MapPin({required this.color, required this.icon});

  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.4),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(icon, color: Colors.white, size: 16),
        ),
        CustomPaint(size: const Size(10, 6), painter: _TrianglePainter(color)),
      ],
    );
  }
}

class _TrianglePainter extends CustomPainter {
  _TrianglePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}