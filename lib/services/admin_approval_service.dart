import 'supabase_client.dart';
import '../models/app_profile.dart';

class AdminApprovalService {
  /// Fetches accounts filtered by approval_status directly in the query —
  /// pass null for every account regardless of status.
  Future<List<AppProfile>> fetchProfiles({String? status}) async {
    final query = supabase.from('profiles').select();
    final filtered = status == null ? query : query.eq('approval_status', status);
    final rows = await filtered.order('full_name');

    return (rows as List).map((r) => AppProfile.fromMap(r)).toList();
  }

  /// Lightweight count of pending accounts, for the notification badge —
  /// doesn't require pulling the full pending list.
  Future<int> countPending() async {
    final rows = await supabase
        .from('profiles')
        .select('id')
        .eq('approval_status', 'pending');
    return (rows as List).length;
  }

  /// Approves the account and verifies their phone number in the same
  /// action — see the design note in the API docs: v1 has no SMS/OTP
  /// provider, so phone verification is folded into this manual admin
  /// check rather than being a separate step. Harmless for roles where
  /// phone_verified isn't otherwise used (e.g. students).
  Future<void> approveProfile(String profileId) async {
    await supabase
        .from('profiles')
        .update({'approval_status': 'approved', 'phone_verified': true})
        .eq('id', profileId);
  }

  /// Rejects the account. phone_verified is left as-is — if this profile
  /// is later reconsidered and approved, verification still happens
  /// through approveProfile at that point.
  Future<void> rejectProfile(String profileId) async {
    await supabase
        .from('profiles')
        .update({'approval_status': 'rejected'})
        .eq('id', profileId);
  }
}