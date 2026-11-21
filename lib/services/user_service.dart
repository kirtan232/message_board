import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/app_user.dart';

/// Owns every Firestore call for the private `users/{uid}` record.
class UserService {
  UserService({FirebaseFirestore? db}) : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  /// Names/role from the registration form, handed to ProfileGate so the
  /// record is written for the newly signed-in uid. Cleared once saved.
  ProfileDraft? pendingDraft;

  DocumentReference<Map<String, dynamic>> _doc(String uid) =>
      _db.collection('users').doc(uid);

  /// Live view of the signed-in user's record (null when it does not exist).
  Stream<AppUser?> watchUser(String uid) {
    return _doc(uid)
        .snapshots()
        .map((snap) => snap.exists ? AppUser.fromSnapshot(snap) : null);
  }

  /// Writes the five required fields once. If a record already exists it is
  /// left untouched, so retries never reset `registrationDateTime`.
  Future<void> saveUserRecord({
    required String uid,
    required ProfileDraft draft,
  }) async {
    final ref = _doc(uid);
    final existing = await ref.get();
    if (existing.exists) return;
    await ref.set({
      'uid': uid,
      'firstName': draft.firstName.trim(),
      'lastName': draft.lastName.trim(),
      'role': draft.role,
      'registrationDateTime': FieldValue.serverTimestamp(),
    });
  }
}
