import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:message_board/screens/splash_screen.dart';

Widget _wrap(Widget child) => MaterialApp(home: child);

void main() {
  testWidgets('Splash shows while initializing, then the ready screen',
      (tester) async {
    final init = Completer<void>();
    await tester.pumpWidget(_wrap(SplashScreen(
      initialize: () => init.future,
      onReady: (_) => const Text('READY'),
      minimumDuration: Duration.zero,
    )));

    expect(find.text('Message Board'), findsOneWidget);
    expect(find.text('READY'), findsNothing);

    init.complete();
    await tester.pumpAndSettle();
    expect(find.text('READY'), findsOneWidget);
  });

  testWidgets('Failed initialization shows Retry, and retry recovers',
      (tester) async {
    var attempts = 0;
    await tester.pumpWidget(_wrap(SplashScreen(
      initialize: () async {
        attempts++;
        if (attempts == 1) throw Exception('no network');
      },
      onReady: (_) => const Text('READY'),
      minimumDuration: Duration.zero,
    )));
    await tester.pumpAndSettle();

    expect(find.text('Firebase could not start.'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(find.text('READY'), findsOneWidget);
    expect(attempts, 2);
  });
}
