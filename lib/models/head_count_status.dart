import 'package:flutter/material.dart';

/// Mirrors the `public.headcount_status` Postgres enum exactly — keep
/// these five values in sync with the DB if that enum ever changes.
///
/// ⚠️ 'absent' requires the 2026_07_headcount_status_absent.sql
/// migration (`alter type public.headcount_status add value 'absent';`)
/// to have actually been run — if it hasn't, writing status: 'absent'
/// will compile fine here but fail at runtime with a Postgres invalid
/// enum value error. Worth confirming before relying on this.
class HeadcountStatus {
  static const safe = 'safe';
  static const trap = 'trap';
  static const missing = 'missing';
  static const searching = 'searching';
  static const absent = 'absent';

  static const all = [safe, trap, missing, searching, absent];

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
      case absent:
        return 'Absent';
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
      case absent:
        return Colors.grey.shade600;
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
/// counted", distinct from any of the five real enum values, so don't
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