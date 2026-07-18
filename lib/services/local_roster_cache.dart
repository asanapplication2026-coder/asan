import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Caches a teacher's roster list on-device via flutter_secure_storage,
/// keyed per teacher, so the roster screen still has something to show
/// if the network fetch fails (e.g. no signal during a drill).
///
/// Generic on purpose: rather than assuming the exact shape of your
/// `RosterEntry` model, the caller supplies `toJson`/`fromJson`. See the
/// instantiation in TeacherRosterController for the one spot you need
/// to line up with your actual model fields.
class LocalRosterCache<T> {
  LocalRosterCache({required this.toJson, required this.fromJson});

  final Map<String, dynamic> Function(T item) toJson;
  final T Function(Map<String, dynamic> json) fromJson;

  static const _storage = FlutterSecureStorage();

  String _key(String teacherId) => 'teacher_roster_cache_$teacherId';

  Future<void> save(String teacherId, List<T> items) async {
    final encoded = jsonEncode(items.map(toJson).toList());
    await _storage.write(key: _key(teacherId), value: encoded);
  }

  /// Returns an empty list if nothing has been cached yet, rather than
  /// throwing — callers shouldn't need a try/catch just to check.
  Future<List<T>> load(String teacherId) async {
    final raw = await _storage.read(key: _key(teacherId));
    if (raw == null || raw.isEmpty) return <T>[];
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded.map((e) => fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> clear(String teacherId) async {
    await _storage.delete(key: _key(teacherId));
  }
}