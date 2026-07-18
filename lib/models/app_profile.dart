class AppProfile {
  final String id;
  final String role; // 'admin' | 'teacher' | 'student'
  final String fullName;
  final String? sectionId;
  final String? schoolIdNumber;
  final String approvalStatus; // 'pending' | 'approved' | 'rejected'
  final String? registeredPhoneNumber;
  final bool phoneVerified;

  AppProfile({
    required this.id,
    required this.role,
    required this.fullName,
    this.sectionId,
    this.schoolIdNumber,
    required this.approvalStatus,
    this.registeredPhoneNumber,
    this.phoneVerified = false,
  });

  factory AppProfile.fromMap(Map<String, dynamic> map) {
    return AppProfile(
      id: map['id'] as String,
      role: map['role'] as String,
      fullName: map['full_name'] as String,
      sectionId: map['section_id'] as String?,
      schoolIdNumber: map['school_id_number'] as String?,
      approvalStatus: map['approval_status'] as String,
      registeredPhoneNumber: map['registered_phone_number'] as String?,
      phoneVerified: map['phone_verified'] as bool? ?? false,
    );
  }

  bool get isAdmin => role == 'admin';

  bool get isTeacher => role == 'teacher';

  bool get isStudent => role == 'student';

  bool get isApproved => approvalStatus == 'approved';

  bool get isPending => approvalStatus == 'pending';

  bool get isRejected => approvalStatus == 'rejected';

  /// True once the advisor has saved a contact number. Note this is
  /// intentionally independent of [phoneVerified] — we're not doing
  /// OTP verification yet, so "has a number on file" is the bar for
  /// now, not "verified".
  bool get hasRegisteredPhone =>
      registeredPhoneNumber != null && registeredPhoneNumber!.trim().isNotEmpty;

  /// Convenience for updating just the phone number locally after a
  /// save, without refetching the whole profile from Supabase.
  AppProfile copyWithPhone(String phoneNumber) {
    return AppProfile(
      id: id,
      role: role,
      fullName: fullName,
      sectionId: sectionId,
      schoolIdNumber: schoolIdNumber,
      approvalStatus: approvalStatus,
      registeredPhoneNumber: phoneNumber,
      phoneVerified: phoneVerified,
    );
  }
}