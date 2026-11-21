import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

import '../firebase_options.dart';

/// Outcome of one security-rules probe.
class ProbeResult {
  const ProbeResult({
    required this.name,
    required this.expectAllowed,
    this.observedAllowed,
    this.code,
    this.skippedReason,
  });

  final String name;
  final bool expectAllowed;

  /// Null when the probe was skipped.
  final bool? observedAllowed;

  /// Firestore error code when the request failed (e.g. permission-denied).
  final String? code;
  final String? skippedReason;

  bool get skipped => skippedReason != null;
  bool get passed => !skipped && observedAllowed == expectAllowed;

  String get expectedLabel => expectAllowed ? 'ALLOWED' : 'DENIED';

  String get observedLabel {
    if (skipped) return 'SKIPPED';
    if (observedAllowed == true) return 'ALLOWED';
    return code == 'permission-denied'
        ? 'DENIED (permission-denied)'
        : 'ERROR ($code)';
  }
}

/// Sends real requests straight to Firestore to prove the security rules are
/// the gate — not hidden UI buttons. Every "denied" result here is a
/// `permission-denied` returned by the Firestore server itself.
///
/// This service deliberately bypasses BoardService's helpers so it can send
/// requests the normal UI never would (forged authorUid, cross-user writes).
class RulesProbeService {
  RulesProbeService({FirebaseFirestore? db})
    : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;
  static const _probeAppName = 'rules-probe-signed-out';

  CollectionReference<Map<String, dynamic>> get _messages =>
      _db.collection('messages');

  /// A second Firebase app instance that has no signed-in user, so its
  /// requests reach Firestore with `request.auth == null`.
  Future<FirebaseFirestore> _signedOutDb() async {
    final app = Firebase.apps.any((a) => a.name == _probeAppName)
        ? Firebase.app(_probeAppName)
        : await Firebase.initializeApp(
            name: _probeAppName,
            options: DefaultFirebaseOptions.currentPlatform,
          );
    return FirebaseFirestore.instanceFor(app: app);
  }

  Future<ProbeResult> _attempt(
    String name, {
    required bool expectAllowed,
    required Future<void> Function() request,
  }) async {
    try {
      await request().timeout(const Duration(seconds: 15));
      return ProbeResult(
        name: name,
        expectAllowed: expectAllowed,
        observedAllowed: true,
      );
    } on FirebaseException catch (e) {
      return ProbeResult(
        name: name,
        expectAllowed: expectAllowed,
        observedAllowed: false,
        code: e.code,
      );
    } catch (_) {
      return ProbeResult(
        name: name,
        expectAllowed: expectAllowed,
        observedAllowed: false,
        code: 'timeout-or-unknown',
      );
    }
  }

  ProbeResult _skip(String name, bool expectAllowed, String reason) =>
      ProbeResult(
        name: name,
        expectAllowed: expectAllowed,
        skippedReason: reason,
      );

  /// Runs every probe as [myUid] and returns the results in order.
  Future<List<ProbeResult>> runAll({
    required String myUid,
    required String myName,
  }) async {
    final results = <ProbeResult>[];

    // ---- Signed-out access (request.auth == null) ----
    final signedOut = await _signedOutDb();
    results.add(
      await _attempt(
        'Signed-out user reads messages',
        expectAllowed: false,
        request: () => signedOut
            .collection('messages')
            .limit(1)
            .get(const GetOptions(source: Source.server)),
      ),
    );
    results.add(
      await _attempt(
        'Signed-out user creates a message',
        expectAllowed: false,
        request: () => signedOut.collection('messages').add({
          'text': 'signed-out write',
          'authorUid': myUid,
          'authorName': myName,
          'createdAt': FieldValue.serverTimestamp(),
        }),
      ),
    );

    // ---- Forged ownership on create ----
    results.add(
      await _attempt(
        'Create with a forged authorUid',
        expectAllowed: false,
        request: () => _messages.add({
          'text': 'forged author',
          'authorUid': 'someone-else-uid',
          'authorName': 'Forged Name',
          'createdAt': FieldValue.serverTimestamp(),
        }),
      ),
    );

    // ---- Correct-author CRUD (positive control) ----
    final probeRef = _messages.doc();
    final created = await _attempt(
      'Owner creates own message',
      expectAllowed: true,
      request: () => probeRef.set({
        'text': '[rules check] temporary message',
        'authorUid': myUid,
        'authorName': myName,
        'createdAt': FieldValue.serverTimestamp(),
      }),
    );
    results.add(created);

    if (created.observedAllowed == true) {
      results.add(
        await _attempt(
          'Owner edits own message text',
          expectAllowed: true,
          request: () => probeRef.update({
            'text': '[rules check] edited',
            'editedAt': FieldValue.serverTimestamp(),
          }),
        ),
      );
      results.add(
        await _attempt(
          'Owner changes authorUid on own message',
          expectAllowed: false,
          request: () => probeRef.update({'authorUid': 'someone-else-uid'}),
        ),
      );
      results.add(
        await _attempt(
          'Owner deletes own message',
          expectAllowed: true,
          request: () => probeRef.delete(),
        ),
      );
    } else {
      const reason = 'Own create failed, so there is no message to test.';
      results
        ..add(_skip('Owner edits own message text', true, reason))
        ..add(_skip('Owner changes authorUid on own message', false, reason))
        ..add(_skip('Owner deletes own message', true, reason));
    }

    // ---- Cross-user writes on another author's message ----
    QueryDocumentSnapshot<Map<String, dynamic>>? other;
    try {
      final snap = await _messages
          .where('authorUid', isNotEqualTo: myUid)
          .limit(1)
          .get(const GetOptions(source: Source.server));
      if (snap.docs.isNotEmpty) other = snap.docs.first;
    } on FirebaseException {
      other = null;
    }

    if (other != null) {
      final otherRef = other.reference;
      final otherUid = other.data()['authorUid'] as String? ?? '';
      results.add(
        await _attempt(
          "Edit another user's message",
          expectAllowed: false,
          request: () => otherRef.update({
            'text': 'hijacked',
            'editedAt': FieldValue.serverTimestamp(),
          }),
        ),
      );
      results.add(
        await _attempt(
          "Delete another user's message",
          expectAllowed: false,
          request: () => otherRef.delete(),
        ),
      );
      results.add(
        await _attempt(
          "Read another user's private record",
          expectAllowed: false,
          request: () => _db
              .collection('users')
              .doc(otherUid)
              .get(const GetOptions(source: Source.server)),
        ),
      );
    } else {
      const reason = 'Post a message from a second account first.';
      results
        ..add(_skip("Edit another user's message", false, reason))
        ..add(_skip("Delete another user's message", false, reason))
        ..add(_skip("Read another user's private record", false, reason));
    }

    // ---- Own user record is create-once ----
    results.add(
      await _attempt(
        'Reset own registrationDateTime',
        expectAllowed: false,
        request: () => _db.collection('users').doc(myUid).update({
          'registrationDateTime': FieldValue.serverTimestamp(),
        }),
      ),
    );

    return results;
  }
}
