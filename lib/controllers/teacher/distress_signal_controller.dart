import 'package:asan_evac_app/models/distress_signal_model.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';


import '../../services/distress_signal_service.dart';

/// Backs the Distress tab on the headcount screen. Read-mostly: it loads
/// the current signals for this drill event, then keeps the list live via
/// Realtime. Sending a signal (in-app SOS, SMS listener, missed-call
/// listener) goes through DistressSignalService directly from wherever
/// that signal originates — this controller only displays them.
class DistressSignalController extends GetxController {
  DistressSignalController({required this.drillEventId});

  final String drillEventId;
  final _service = DistressSignalService();

  final RxList<DistressSignal> signals = <DistressSignal>[].obs;
  final RxBool isLoading = false.obs;
  final RxnString errorMessage = RxnString();

  /// Filter chip: 'All', or one of the DistressChannel values.
  final RxString selectedChannelFilter = 'All'.obs;

  RealtimeChannel? _channel;

  List<DistressSignal> get filteredSignals {
    final filter = selectedChannelFilter.value;
    if (filter == 'All') return signals.toList();
    return signals.where((s) => s.channel.value == filter).toList();
  }

  /// Only signals with coordinates show up as map pins; SMS/missed-call
  /// signals commonly won't have a location.
  List<DistressSignal> get mappableSignals =>
      filteredSignals.where((s) => s.hasCoordinates).toList();

  int get totalCount => signals.length;
  int get appCount => signals.where((s) => s.channel == DistressChannel.app).length;
  int get smsCount => signals.where((s) => s.channel == DistressChannel.sms).length;
  int get missedCallCount =>
      signals.where((s) => s.channel == DistressChannel.missedCall).length;

  @override
  void onInit() {
    super.onInit();
    debugPrint('[DistressSignalController] onInit drillEventId=$drillEventId');
    _load();
    _subscribeRealtime();
  }

  Future<void> _load() async {
    isLoading.value = true;
    errorMessage.value = null;
    try {
      final rows = await _service.fetchSignals(drillEventId);
      signals.assignAll(rows);
      debugPrint('[DistressSignalController] loaded ${rows.length} signals');
    } catch (e) {
      // Previously this only set errorMessage (which the UI may or may not
      // render prominently). Logging it too means a silent RLS/select
      // failure shows up in the console even if the UI swallows it.
      debugPrint('[DistressSignalController] load FAILED: $e');
      errorMessage.value = 'Failed to load distress signals: $e';
    } finally {
      isLoading.value = false;
    }
  }

  @override
  Future<void> refresh() => _load();

  void _subscribeRealtime() {
    try {
      _channel = _service.subscribeToSignals(
        drillEventId: drillEventId,
        onInsert: (signal) {
          debugPrint('[DistressSignalController] realtime onInsert id=${signal.id} channel=${signal.channel.value}');
          // Guard against a duplicate if the row also comes back through
          // a manual refresh before the realtime event lands.
          if (signals.any((s) => s.id == signal.id)) return;
          signals.insert(0, signal);
        },
      );
    } catch (e) {
      // Realtime not available for this table yet — non-fatal, the tab
      // still works via pull-to-refresh. Now logged instead of fully silent.
      debugPrint('[DistressSignalController] subscribeToSignals threw synchronously: $e');
    }
  }

  @override
  void onClose() {
    _channel?.unsubscribe();
    super.onClose();
  }
}