import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:message_board/models/message.dart';
import 'package:message_board/widgets/edit_message_dialog.dart';

const _message = Message(
  id: 'msg_1',
  text: 'Original',
  authorUid: 'u1',
  authorName: 'Ada',
);

/// Pumps a button that opens the dialog and stores its result in [out].
Future<void> _openDialog(WidgetTester tester, List<String?> out) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async =>
              out.add(await showEditMessageDialog(context, _message)),
          child: const Text('open'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('blank edit is rejected, real edit is returned', (tester) async {
    final out = <String?>[];
    await _openDialog(tester, out);

    await tester.enterText(find.byType(TextFormField), '   ');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Message cannot be empty.'), findsOneWidget);
    expect(out, isEmpty);

    await tester.enterText(find.byType(TextFormField), 'Edited text');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(out, ['Edited text']);
  });

  testWidgets('unchanged edit returns null (no write)', (tester) async {
    final out = <String?>[];
    await _openDialog(tester, out);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(out, [null]);
  });
}
