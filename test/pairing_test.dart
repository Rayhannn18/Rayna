import 'package:flutter_test/flutter_test.dart';
import 'package:rayna_app/core/validation/validators.dart';
import 'package:rayna_app/features/pairing/data/pairing_service.dart';

void main() {
  group('Pairing System Tests', () {
    test('PairingException preserves message', () {
      const ex = PairingException('Cannot pair with oneself');
      expect(ex.message, equals('Cannot pair with oneself'));
      expect(ex.toString(), equals('Cannot pair with oneself'));
    });

    test('Pairing code validation correctly handles various input formats', () {
      // Valid codes
      expect(Validators.normalizePairingCode('AB12CD'), equals('AB12CD'));
      expect(Validators.normalizePairingCode('  ab12cd  '), equals('AB12CD'));
      expect(Validators.normalizePairingCode('7X9K2P'), equals('7X9K2P'));

      // Invalid length or characters
      expect(Validators.normalizePairingCode(''), isNull);
      expect(Validators.normalizePairingCode('12345'), isNull);
      expect(Validators.normalizePairingCode('1234567'), isNull);
      expect(Validators.normalizePairingCode('AB-12C'), isNull);
      expect(Validators.normalizePairingCode('AB!2CD'), isNull);
    });
  });
}
