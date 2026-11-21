import 'package:flutter_test/flutter_test.dart';
import 'package:message_board/utils/format.dart';

void main() {
  final now = DateTime(2026, 11, 21, 18);

  test('today shows only the clock', () {
    expect(
      formatMessageTime(DateTime(2026, 11, 21, 15, 7), now: now),
      '3:07 PM',
    );
    expect(
      formatMessageTime(DateTime(2026, 11, 21, 0, 5), now: now),
      '12:05 AM',
    );
  });

  test('other days include the date', () {
    expect(
      formatMessageTime(DateTime(2026, 11, 20, 12, 0), now: now),
      'Nov 20, 12:00 PM',
    );
  });
}
