import 'package:flutter_test/flutter_test.dart';
import 'package:rayna_app/features/auth/data/auth_service.dart';

void main() {
  group('AuthService Exceptions & Validation', () {
    test('UsernameAlreadyTakenException formats message properly', () {
      const ex = UsernameAlreadyTakenException();
      expect(ex.toString(), equals('Username is already taken.'));
    });
  });
}
