import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:get/get.dart';
import 'package:latlong2/latlong.dart';
import '../../controllers/teacher/distress_signal_controller.dart';
import '../../models/distress_signal_model.dart';

const _primaryRed = Color(0xFF7B1113);

/// Live replacement for the old dummy `_DistressMapTab`.
///
/// Drop this in place of `const _DistressMapTab()` inside
/// `head_count_screen.dart`, e.g.:
///
/// ```dart
/// DistressSignalTab(
///   drillEventId: widget.drillEventId,
///   studentDirectory: controller.studentDirectory, // id -> name map, if you have one
/// ),
/// ```
class DistressSignalTab extends StatefulWidget {
  const DistressSignalTab({
    super.key,
    required this.drillEventId,
    this.studentDirectory = const {},
  });

  final String drillEventId;
  final Map<String, String> studentDirectory;

  @override
  State<DistressSignalTab> createState() => _DistressSignalTabState();
}

class _DistressSignalTabState extends State<DistressSignalTab> {
  late final controller = Get.put(
    DistressSignalController(
      drillEventId: widget.drillEventId,
      studentDirectory: widget.studentDirectory,
    ),
    tag: 'distress-${widget.drillEventId}',
  );

  static const _fallbackCenter = LatLng(11.5853, 122.7550);

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.isLoading.value) {
        return const Center(child: CupertinoActivityIndicator(radius: 14));
      }

      final signals = controller.signals;
      final located = controller.signalsWithLocation;
      final mapCenter = located.isNotEmpty
          ? LatLng(located.first.latitude!, located.first.longitude!)
          : _fallbackCenter;

      return RefreshIndicator(
        onRefresh: controller.refresh,
        color: _primaryRed,
        child: Stack(
          children: [
            // 1. LIVE MAP
            FlutterMap(
              options: MapOptions(
                initialCenter: mapCenter,
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
                  markers: located.map((signal) {
                    return Marker(
                      point: LatLng(signal.latitude!, signal.longitude!),
                      width: 75,
                      height: 75,
                      child: _MapPin(
                        name: controller.nameFor(signal.studentId),
                        channel: signal.channel,
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),

            // 2. TOP FLOATING STATUS HEADER
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
                        color: (signals.isEmpty
                            ? CupertinoColors.systemGrey
                            : CupertinoColors.systemRed)
                            .withValues(alpha: 0.9),
                      ),
                      child: Row(
                        children: [
                          const Icon(CupertinoIcons.waveform_path_ecg, color: Colors.white, size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              signals.isEmpty
                                  ? 'No distress signals reported'
                                  : '${signals.length} Active Distress Signal${signals.length == 1 ? '' : 's'} Detected',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                letterSpacing: -0.2,
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

            if (controller.errorMessage.value != null)
              Positioned(
                top: 116,
                left: 16,
                right: 16,
                child: SafeArea(
                  top: false,
                  child: _ErrorBanner(message: controller.errorMessage.value!),
                ),
              ),

            // 3. SLIDING BROADCAST ROSTER
            if (signals.isNotEmpty)
              Positioned(
                left: 16,
                right: 16,
                bottom: 104,
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 320),
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
                      Flexible(
                        child: ListView.separated(
                          shrinkWrap: true,
                          padding: EdgeInsets.zero,
                          itemCount: signals.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final signal = signals[index];
                            return _SignalRow(
                              name: controller.nameFor(signal.studentId),
                              signal: signal,
                              onClear: () => controller.clearSignal(signal.id),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      );
    });
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: CupertinoColors.systemYellow.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(CupertinoIcons.exclamationmark_triangle, size: 16, color: CupertinoColors.black),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _SignalRow extends StatelessWidget {
  const _SignalRow({
    required this.name,
    required this.signal,
    required this.onClear,
  });

  final String name;
  final DistressSignalModel signal;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final locationLabel = [signal.building, signal.floor]
        .where((v) => v != null && v.isNotEmpty)
        .join(' · ');

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
            decoration: BoxDecoration(
              color: _channelColor(signal.channel),
              shape: BoxShape.circle,
            ),
            child: Icon(_channelIcon(signal.channel), color: Colors.white, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                const SizedBox(height: 2),
                Text(
                  locationLabel.isNotEmpty ? locationLabel : signal.channel.label,
                  style: const TextStyle(fontSize: 12, color: CupertinoColors.secondaryLabel, fontWeight: FontWeight.w500),
                ),
                if (signal.message != null && signal.message!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      signal.message!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: CupertinoColors.label, fontWeight: FontWeight.w500),
                    ),
                  ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _timeAgo(signal.createdAt),
                style: const TextStyle(fontSize: 11, color: CupertinoColors.systemRed, fontWeight: FontWeight.w700),
              ),
              GestureDetector(
                onTap: onClear,
                child: const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Text(
                    'Clear',
                    style: TextStyle(fontSize: 11, color: CupertinoColors.secondaryLabel, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MapPin extends StatelessWidget {
  const _MapPin({required this.name, required this.channel});
  final String name;
  final DistressChannel channel;

  @override
  Widget build(BuildContext context) {
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
            '${name.split(' ').first}.',
            style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(height: 2),
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: _channelColor(channel),
            shape: BoxShape.circle,
            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 1))],
          ),
          child: Icon(_channelIcon(channel), color: Colors.white, size: 14),
        ),
      ],
    );
  }
}

Color _channelColor(DistressChannel channel) {
  switch (channel) {
    case DistressChannel.app:
      return CupertinoColors.systemRed;
    case DistressChannel.sms:
      return CupertinoColors.systemOrange;
    case DistressChannel.missedCall:
      return CupertinoColors.systemPurple;
  }
}

IconData _channelIcon(DistressChannel channel) {
  switch (channel) {
    case DistressChannel.app:
      return CupertinoIcons.person_fill;
    case DistressChannel.sms:
      return CupertinoIcons.chat_bubble_text_fill;
    case DistressChannel.missedCall:
      return CupertinoIcons.phone_fill;
  }
}

String _timeAgo(DateTime time) {
  final diff = DateTime.now().difference(time);
  if (diff.inSeconds < 60) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  return '${diff.inDays}d ago';
}