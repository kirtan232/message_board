import 'package:cloud_firestore/cloud_firestore.dart';

/// Maximum message length, enforced by the client and the security rules.
const int kMaxMessageLength = 500;

/// A public board message stored at `messages/{msgId}`.
///
/// | Field        | Writer                                              |
/// |--------------|-----------------------------------------------------|
/// | text         | Author (create; update of own message)              |
/// | authorUid    | Author at create; must equal request.auth.uid       |
/// | authorName   | Author at create, copied from their user record     |
/// | createdAt    | Server (FieldValue.serverTimestamp at create)       |
/// | editedAt     | Server (FieldValue.serverTimestamp on each update)  |
class Message {
  const Message({
    required this.id,
    required this.text,
    required this.authorUid,
    required this.authorName,
    this.createdAt,
    this.editedAt,
    this.isPending = false,
  });

  final String id;
  final String text;
  final String authorUid;
  final String authorName;

  /// Null while the server timestamp has not resolved yet ("Sending…").
  final DateTime? createdAt;

  /// Null until the message has been edited at least once.
  final DateTime? editedAt;

  /// True while this device's write has not been confirmed by the server.
  final bool isPending;

  bool get isEdited => editedAt != null;

  bool isOwnedBy(String? uid) => uid != null && uid == authorUid;

  factory Message.fromMap(
    String id,
    Map<String, dynamic> data, {
    bool isPending = false,
  }) {
    return Message(
      id: id,
      text: data['text'] as String? ?? '',
      authorUid: data['authorUid'] as String? ?? '',
      authorName: data['authorName'] as String? ?? 'Unknown',
      createdAt: _toDate(data['createdAt']),
      editedAt: _toDate(data['editedAt']),
      isPending: isPending,
    );
  }

  factory Message.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> doc) {
    return Message.fromMap(
      doc.id,
      doc.data() ?? const <String, dynamic>{},
      isPending: doc.metadata.hasPendingWrites,
    );
  }

  static DateTime? _toDate(Object? value) =>
      value is Timestamp ? value.toDate() : null;
}
