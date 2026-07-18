import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_client.dart';
import '../models/app_profile.dart';

class RosterNotFoundException implements Exception {
  final String message;
  RosterNotFoundException(this.message);
  @override
  String toString() => message;
}

/// Thrown when complete_signup fails after email confirmation —
/// e.g. the roster row got claimed by someone else in the interim.
class SignupCompletionException implements Exception {
  final String message;
  SignupCompletionException(this.message);
  @override
  String toString() => message;
}

class AuthService {
  /// Step 1 of signup. Validates the school ID against an unclaimed
  /// roster row, creates the auth user, and stashes the school ID in
  /// user metadata so it survives until email confirmation completes.
  ///
  /// Does NOT create the profiles row or claim the roster row — that
  /// happens in completeSignupIfPending(), which requires a real
  /// session and therefore can't run until after confirmation.
  Future<void> signUp({
    required String email,
    required String password,
    required String schoolIdNumber,
  }) async {
    final rows = await supabase.rpc(
      'check_roster_claimable',
      params: {'p_school_id_number': schoolIdNumber},
    ) as List;

    if (rows.isEmpty) {
      throw RosterNotFoundException(
        'No unclaimed roster entry found for school ID "$schoolIdNumber". '
            'Check the number, or ask an admin to confirm you\'ve been added.',
      );
    }

    await supabase.auth.signUp(
      email: email,
      password: password,
      data: {'school_id_number': schoolIdNumber},
    );
  }

  /// Step 2 of signup. Call this whenever a user is authenticated but
  /// has no profile row yet (first sign-in after confirming email).
  /// Safe to call repeatedly — no-ops if there's nothing pending or
  /// if the profile already exists.
  ///
  /// Returns true if a profile was created (or already existed),
  /// false if there was nothing pending to do.
  Future<bool> completeSignupIfPending() async {
    final user = currentUser;
    if (user == null) return false;

    final pendingSchoolId = user.userMetadata?['school_id_number'] as String?;
    if (pendingSchoolId == null) return false;

    try {
      await supabase.rpc(
        'complete_signup',
        params: {'p_school_id_number': pendingSchoolId},
      );
      return true;
    } on PostgrestException catch (e) {
      throw SignupCompletionException(
        'We couldn\'t finish setting up your account: ${e.message}. '
            'The roster entry may no longer be available — contact an admin.',
      );
    }
  }

  Future<void> signIn({required String email, required String password}) async {
    await supabase.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signOut() async {
    await supabase.auth.signOut();
  }

  User? get currentUser => supabase.auth.currentUser;

  Future<AppProfile?> fetchCurrentProfile() async {
    final uid = currentUser?.id;
    if (uid == null) return null;

    final row = await supabase.from('profiles').select().eq('id', uid).maybeSingle();
    if (row == null) return null;
    return AppProfile.fromMap(row);
  }

  Stream<AuthState> get authStateChanges => supabase.auth.onAuthStateChange;
}