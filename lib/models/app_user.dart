import 'package:cloud_firestore/cloud_firestore.dart';

/// Role values stored on the user record. Descriptive only — never used to
/// grant access (security rules do not trust client-written roles).
const List<String> kUserRoles = ['student', 'instructor', 'other'];

/// The private user record stored at `users/{uid}`.
///
/// Writer: the client, exactly once, at registration (keyed by the auth uid).
/// `role` is descriptive profile data only — it never grants permissions.
class AppUser {
  const AppUser({
    required this.uid,
    required this.firstName,
    required this.lastName,
    required this.role,
    required this.registrationDateTime,
    this.hasRegistrationField = true,
  });

  final String uid;
  final String firstName;
  final String lastName;
  final String role;

  /// Server timestamp. Null for a moment while a local write is still
  /// pending (Firestore reports unresolved server timestamps as null).
  final DateTime? registrationDateTime;

  /// Whether the document contains the registrationDateTime key at all.
  final bool hasRegistrationField;

  String get fullName => '$firstName $lastName';

  /// True when all five required fields are present and valid.
  bool get isComplete =>
      uid.isNotEmpty &&
      firstName.trim().isNotEmpty &&
      lastName.trim().isNotEmpty &&
      role.trim().isNotEmpty &&
      hasRegistrationField;

  factory AppUser.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    final ts = data['registrationDateTime'];
    return AppUser(
      uid: data['uid'] as String? ?? '',
      firstName: data['firstName'] as String? ?? '',
      lastName: data['lastName'] as String? ?? '',
      role: data['role'] as String? ?? '',
      registrationDateTime: ts is Timestamp ? ts.toDate() : null,
      hasRegistrationField: data.containsKey('registrationDateTime'),
    );
  }
}

/// Name and role collected by the registration form, waiting to be saved.
class ProfileDraft {
  const ProfileDraft({
    required this.firstName,
    required this.lastName,
    required this.role,
  });

  final String firstName;
  final String lastName;
  final String role;
}
