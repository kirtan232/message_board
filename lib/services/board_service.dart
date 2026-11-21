import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/message.dart';

/// A safe, user-facing error from a board operation.
class BoardException implements Exception {
  const BoardException(this.message, {this.code});

  final String message;
  final String? code;

  bool get isPermissionDenied => code == 'permission-denied';

  @override
  String toString() => 'BoardException($code): $message';
}

/// Owns every Firestore call for the public `messages` collection.
///
/// Widgets never import cloud_firestore; they call these typed methods and
/// receive [Message] objects or [BoardException]s. Ownership is enforced by
/// the security rules — the UI only hides buttons as a convenience.
class BoardService {
  BoardService({FirebaseFirestore? db})
    : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _messages =>
      _db.collection('messages');

  /// Returns null when [text] is valid, otherwise a reason it is not.
  static String? validateText(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return 'Message cannot be empty.';
    if (trimmed.length > kMaxMessageLength) {
      return 'Message must be $kMaxMessageLength characters or fewer.';
    }
    return null;
  }

  /// A fresh document id. The composer reserves one id per message so that
  /// retries and double-submits of the same message target the same document.
  String newMessageId() => _messages.doc().id;

  /// CREATE — uid-owned and server-timestamped.
  ///
  /// Idempotent: inside a transaction, the document is written only if it
  /// does not already exist, so calling this twice with the same
  /// [messageId] still leaves exactly one message.
  Future<void> postMessage({
    required String messageId,
    required String authorUid,
    required String authorName,
    required String text,
  }) async {
    final problem = validateText(text);
    if (problem != null) throw BoardException(problem, code: 'invalid-text');

    final ref = _messages.doc(messageId);
    await _guard(
      () => _db.runTransaction((tx) async {
        final existing = await tx.get(ref);
        if (existing.exists) return;
        tx.set(ref, {
          'text': text.trim(),
          'authorUid': authorUid,
          'authorName': authorName,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }),
    );
  }

  /// READ (live) — every signed-in device re-renders on each change.
  /// Ordered oldest to newest by the server timestamp.
  Stream<List<Message>> messageBoard() {
    return _messages
        .orderBy('createdAt')
        .snapshots()
        .handleError((Object error) => throw _translate(error))
        .map((snap) => snap.docs.map(Message.fromSnapshot).toList());
  }

  /// UPDATE — own message only (rules enforce it). Changes text + editedAt.
  Future<void> editMessage({
    required String messageId,
    required String newText,
  }) async {
    final problem = validateText(newText);
    if (problem != null) throw BoardException(problem, code: 'invalid-text');

    await _guard(
      () => _messages.doc(messageId).update({
        'text': newText.trim(),
        'editedAt': FieldValue.serverTimestamp(),
      }),
    );
  }

  /// DELETE — own message only (rules enforce it). Removes one document.
  Future<void> deleteMessage({required String messageId}) {
    return _guard(() => _messages.doc(messageId).delete());
  }

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } catch (error) {
      throw _translate(error);
    }
  }

  static BoardException _translate(Object error) {
    if (error is BoardException) return error;
    if (error is FirebaseException) {
      return BoardException(
        friendlyFirestoreError(error.code),
        code: error.code,
      );
    }
    return const BoardException('Something went wrong. Please try again.');
  }
}

/// Maps Firestore error codes to safe messages (never raw exception text).
String friendlyFirestoreError(String code) {
  switch (code) {
    case 'permission-denied':
      return 'Permission denied: you can only change your own messages.';
    case 'not-found':
      return 'That message no longer exists.';
    case 'unavailable':
      return 'You appear to be offline. Check your connection and try again.';
    case 'unauthenticated':
      return 'Please sign in again.';
    case 'failed-precondition':
      return 'The board is not ready yet. Please try again shortly.';
    default:
      return 'Something went wrong. Please try again.';
  }
}
