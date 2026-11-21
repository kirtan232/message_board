import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:message_board/models/message.dart';
import 'package:message_board/services/board_service.dart';

void main() {
  group('Message.fromMap', () {
    test('maps all fields and timestamps', () {
      final created = Timestamp.fromDate(DateTime.utc(2026, 11, 21, 10));
      final m = Message.fromMap('msg_1', {
        'text': 'Hello, board!',
        'authorUid': 'uid_ada',
        'authorName': 'Ada Lovelace',
        'createdAt': created,
      });
      expect(m.id, 'msg_1');
      expect(m.text, 'Hello, board!');
      expect(m.createdAt, created.toDate());
      expect(m.isEdited, isFalse);
      expect(m.isOwnedBy('uid_ada'), isTrue);
      expect(m.isOwnedBy('uid_grace'), isFalse);
      expect(m.isOwnedBy(null), isFalse);
    });

    test('pending server timestamp maps to null createdAt', () {
      final m = Message.fromMap('msg_2', {
        'text': 'Sending',
        'authorUid': 'u',
        'authorName': 'A',
        'createdAt': null,
      }, isPending: true);
      expect(m.createdAt, isNull);
      expect(m.isPending, isTrue);
    });
  });

  group('BoardService.validateText', () {
    test('rejects blank and over-long text', () {
      expect(BoardService.validateText(''), isNotNull);
      expect(BoardService.validateText('   '), isNotNull);
      expect(
        BoardService.validateText('a' * (kMaxMessageLength + 1)),
        isNotNull,
      );
    });
    test('accepts trimmed text within the limit', () {
      expect(BoardService.validateText('  hi  '), isNull);
      expect(BoardService.validateText('a' * kMaxMessageLength), isNull);
    });
  });

  test('permission-denied maps to a friendly message', () {
    expect(
      friendlyFirestoreError('permission-denied'),
      contains('Permission denied'),
    );
  });
}
