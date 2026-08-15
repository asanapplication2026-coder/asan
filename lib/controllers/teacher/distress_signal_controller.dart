import 'dart:async';
import 'package:get/get.dart';
import '../../models/distress_signal_model.dart';
import '../../services/distress_signal_service.dart';

class DistressSignalController extends GetxController {
  DistressSignalController({
    required this.drillEventId,
    this.studentDirectory = const {},
  });

  /// The drill/event these signals belong to. Passed in the same way
  /// `HeadcountController` receives it, so both controllers stay
  /// scoped to the same active drill.
  final String drillEventId;

  /// Optional studentId -> display name lookup (e.g. built from the
  /// section roster already loaded by HeadcountController), used so
  /// the UI can show "Juan Dela Cruz" instead of a raw uuid. Falls
  /// back gracefully if not provided.
  final Map<String, String> studentDirectory;

  final DistressSignalService _service = DistressSignalService();

  final signals = <DistressSignalModel>[].obs;
  final isLoading = true.obs;
  final isSending = false.obs;
  final errorMessage = RxnString();

  StreamSubscription<List<DistressSignalModel>>? _realtimeSub;

  @override
  void onInit() {
    super.onInit();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await _fetchInitial();
    _subscribeRealtime();
  }

  Future<void> _fetchInitial() async {
    try {
      isLoading.value = true;
      errorMessage.value = null;
      final data = await _service.fetchForDrillEvent(drillEventId);
      signals.assignAll(data);
    } on DistressSignalException catch (e) {
      errorMessage.value = e.message;
    } catch (e) {
      errorMessage.value = 'Something went wrong loading distress signals.';
    } finally {
      isLoading.value = false;
    }
  }

  void _subscribeRealtime() {
    _realtimeSub?.cancel();
    _realtimeSub = _service.streamForDrillEvent(drillEventId).listen(
          (data) {
        signals.assignAll(data);
        // A live update means the connection is fine again.
        if (errorMessage.value != null) errorMessage.value = null;
      },
      onError: (_) {
        errorMessage.value = 'Lost live connection to distress signals.';
      },
    );
  }

  @override
  Future<void> refresh() async => _fetchInitial();

  /// Fires an in-app SOS. SMS / missed-call signals are never sent
  /// from here — they land in the table via the backend integration
  /// and simply show up through the realtime stream above.
  Future<void> sendAppSos({
    required String studentId,
    double? latitude,
    double? longitude,
    String? building,
    String? floor,
    String? message,
  }) async {
    try {
      isSending.value = true;
      final created = await _service.sendAppDistressSignal(
        drillEventId: drillEventId,
        studentId: studentId,
        latitude: latitude,
        longitude: longitude,
        building: building,
        floor: floor,
        message: message,
      );
      // Optimistic insert; the realtime stream will also confirm it.
      if (!signals.any((s) => s.id == created.id)) {
        signals.insert(0, created);
      }
    } on DistressSignalException catch (e) {
      errorMessage.value = e.message;
      rethrow;
    } finally {
      isSending.value = false;
    }
  }

  Future<void> clearSignal(String id) async {
    try {
      await _service.deleteSignal(id);
      signals.removeWhere((s) => s.id == id);
    } on DistressSignalException catch (e) {
      errorMessage.value = e.message;
    }
  }

  // ---- Derived / display helpers -----------------------------------

  int get totalCount => signals.length;

  int countByChannel(DistressChannel channel) =>
      signals.where((s) => s.channel == channel).length;

  List<DistressSignalModel> get signalsWithLocation =>
      signals.where((s) => s.hasLocation).toList();

  String nameFor(String studentId) =>
      studentDirectory[studentId] ?? 'Student ${studentId.substring(0, 8)}';

  @override
  void onClose() {
    _realtimeSub?.cancel();
    super.onClose();
  }
}