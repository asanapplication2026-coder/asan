import 'package:supabase_flutter/supabase_flutter.dart';

/// Profile-level updates that don't belong in SectionService.
///
/// For now this only covers saving a contact number for the signed-in
/// user. There is no OTP/SMS verification step — `phone_verified` is
/// intentionally left untouched here so it can be wired up later
/// (either an admin flips it, or a future verification flow does).
class ProfileService {
  final _client = Supabase.instance.client;

  Future<void> updateRegisteredPhoneNumber({
    required String profileId,
    required String phoneNumber,
  }) async {
    await _client
        .from('profiles')
        .update({'registered_phone_number': phoneNumber})
        .eq('id', profileId);
  }
}