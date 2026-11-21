import 'package:flutter_test/flutter_test.dart';
import 'package:message_board/utils/validators.dart';

void main() {
  group('Validators.email', () {
    test('rejects empty and malformed emails', () {
      expect(Validators.email(''), isNotNull);
      expect(Validators.email('   '), isNotNull);
      expect(Validators.email('ada'), isNotNull);
      expect(Validators.email('ada@board'), isNotNull);
      expect(Validators.email('ada @board.com'), isNotNull);
    });
    test('accepts a valid email (trimmed)', () {
      expect(Validators.email(' ada@board.com '), isNull);
    });
  });

  group('Validators.newPassword', () {
    test('enforces minimum length of 6', () {
      expect(Validators.newPassword(''), isNotNull);
      expect(Validators.newPassword('12345'), isNotNull);
      expect(Validators.newPassword('123456'), isNull);
    });
  });

  group('Validators.requiredPassword', () {
    test('only checks presence', () {
      expect(Validators.requiredPassword(''), isNotNull);
      expect(Validators.requiredPassword('x'), isNull);
    });
  });

  group('Validators.name', () {
    test('requires a non-blank value up to 50 chars', () {
      expect(Validators.name('  ', label: 'first name'), isNotNull);
      expect(Validators.name('A' * 51, label: 'first name'), isNotNull);
      expect(Validators.name('Ada', label: 'first name'), isNull);
    });
  });
}
