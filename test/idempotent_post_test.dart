import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:message_board/services/board_service.dart';

void main() {
  late FakeFirebaseFirestore db;
  late BoardService board;

  setUp(() {
    db = FakeFirebaseFirestore();
    board = BoardService(db: db);
  });

  Future<void> post(String id, String text) => board.postMessage(
    messageId: id,
    authorUid: 'uid_ada',
    authorName: 'Ada Lovelace',
    text: text,
  );

  test('posting the same message twice creates exactly one document', () async {
    final id = board.newMessageId();
    await post(id, 'Hello once');
    await post(id, 'Hello once'); // double-tap / retry

    final all = await db.collection('messages').get();
    expect(all.docs, hasLength(1));
    expect(all.docs.single.id, id);
  });

  test('a retry never overwrites the original message', () async {
    final id = board.newMessageId();
    await post(id, 'Original');
    await post(id, 'Retry with different text');

    final doc = await db.collection('messages').doc(id).get();
    expect(doc.data()!['text'], 'Original');
  });

  test('different messages get different ids', () async {
    await post(board.newMessageId(), 'One');
    await post(board.newMessageId(), 'Two');

    final all = await db.collection('messages').get();
    expect(all.docs, hasLength(2));
  });

  test('blank text is rejected before any write', () async {
    expect(
      () => post(board.newMessageId(), '   '),
      throwsA(isA<BoardException>()),
    );
    final all = await db.collection('messages').get();
    expect(all.docs, isEmpty);
  });

  test('edit changes text and sets editedAt; delete removes one doc', () async {
    final a = board.newMessageId();
    final b = board.newMessageId();
    await post(a, 'Keep me');
    await post(b, 'Edit me');

    await board.editMessage(messageId: b, newText: 'Edited');
    final edited = await db.collection('messages').doc(b).get();
    expect(edited.data()!['text'], 'Edited');
    expect(edited.data()!.containsKey('editedAt'), isTrue);

    await board.deleteMessage(messageId: b);
    final all = await db.collection('messages').get();
    expect(all.docs.map((d) => d.id), [a]);
    expect(all.docs.single.data()['text'], 'Keep me');
  });
}
