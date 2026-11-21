import 'package:flutter_test/flutter_test.dart';
import 'package:message_board/models/app_user.dart';

void main() {
  AppUser user({String first = 'Ada', bool hasDate = true}) => AppUser(
    uid: 'u1',
    firstName: first,
    lastName: 'Lovelace',
    role: 'student',
    registrationDateTime: hasDate ? DateTime(2026, 11, 21) : null,
    hasRegistrationField: hasDate,
  );

  test('record with all five fields is complete', () {
    expect(user().isComplete, isTrue);
    expect(user().fullName, 'Ada Lovelace');
  });

  test('blank name or missing datetime is incomplete', () {
    expect(user(first: '  ').isComplete, isFalse);
    expect(user(hasDate: false).isComplete, isFalse);
  });

  test('roles are descriptive values only', () {
    expect(kUserRoles, ['student', 'instructor', 'other']);
  });
}
