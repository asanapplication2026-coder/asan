import 'package:flutter/material.dart';

/// Mirrors the `public.headcount_status` Postgres enum exactly — keep
/// these four values in sync with the DB if that enum ever changes.
class HeadcountStatus {
  static const safe = 'safe';
  static const trap = 'trap';
  static const missing = 'missing';
  static const searching = 'searching';

  static const all = [safe, trap, missing, searching];

  static String label(String status) {
    switch (status) {
      case safe:
        return 'Safe';
      case trap:
        return 'Trapped';
      case missing:
        return 'Missing';
      case searching:
        return 'Searching';
      default:
        return status;
    }
  }

  static Color color(String status) {
    switch (status) {
      case safe:
        return Colors.green;
      case trap:
        return Colors.deepOrange;
      case missing:
        return Colors.red;
      case searching:
        return Colors.amber.shade800;
      default:
        return Colors.grey;
    }
  }
}

/// A student on the roster for a section, being headcounted for a
/// specific drill event. Keyed by `roster.id` — NOT `profiles.id` —
/// so a student who hasn't signed up for the app yet can still be
/// marked. `isRegistered` (from `roster.claimed`) is display-only; it
/// doesn't gate whether a status can be set.
///
/// `status` is null until a teacher marks them — that's "not yet
/// counted", distinct from any of the four real enum values, so don't
/// treat null as one of the HeadcountStatus constants.
class HeadcountStudent {
  final String rosterId;
  final String fullName;
  final String schoolIdNumber;
  final bool isRegistered;
  String? status;
  DateTime? updatedAt;

  HeadcountStudent({
    required this.rosterId,
    required this.fullName,
    required this.schoolIdNumber,
    required this.isRegistered,
    this.status,
    this.updatedAt,
  });
}
class KpiDataModel {
  final int totalExpected;
  final int totalCounted;
  final int safeCount;
  final int injuredCount;
  final int missingCount;
  final int absentCount;

  KpiDataModel({
    required this.totalExpected,
    required this.totalCounted,
    required this.safeCount,
    required this.injuredCount,
    required this.missingCount,
    required this.absentCount,
  });
}

