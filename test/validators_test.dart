import 'package:flutter_test/flutter_test.dart';

import 'package:rayna_app/core/validation/validators.dart';

void main() {
  group('email', () {
    test('rejects empty and malformed values', () {
      expect(Validators.email(null), isNotNull);
      expect(Validators.email('   '), isNotNull);
      expect(Validators.email('not-an-email'), isNotNull);
      expect(Validators.email('missing@domain'), isNotNull);
    });

    test('accepts a valid address', () {
      expect(Validators.email('rayhan@example.com'), isNull);
      expect(Validators.email('  rayhan@example.com  '), isNull);
    });
  });

  group('username', () {
    test('enforces length and allowed characters', () {
      expect(Validators.username(''), isNotNull);
      expect(Validators.username('ab'), isNotNull);
      expect(Validators.username('has space'), isNotNull);
      expect(Validators.username('a' * 21), isNotNull);
    });

    test('accepts dots and underscores', () {
      expect(Validators.username('rayhan.giri_24'), isNull);
    });
  });

  group('pairing code', () {
    test('normalises lowercase input', () {
      expect(Validators.normalizePairingCode(' ab12cd '), 'AB12CD');
    });

    test('rejects wrong length or characters', () {
      expect(Validators.normalizePairingCode('ABC'), isNull);
      expect(Validators.normalizePairingCode('ABCDEFG'), isNull);
      expect(Validators.normalizePairingCode('AB-12C'), isNull);
    });
  });

  group('moment text', () {
    test('rejects empty content', () {
      expect(Validators.momentText('   '), isNotNull);
    });

    test('enforces the maximum length', () {
      expect(Validators.momentText('a' * Validators.momentMaxLength), isNull);
      expect(
        Validators.momentText('a' * (Validators.momentMaxLength + 1)),
        isNotNull,
      );
    });
  });

  group('message text', () {
    test('trims and validates', () {
      expect(Validators.messageText(' hello '), isNull);
      expect(Validators.messageText(''), isNotNull);
    });
  });

  group('MVP payload validation', () {
    test('validates captions and mood notes', () {
      expect(Validators.caption('optional caption'), isNull);
      expect(Validators.caption('a' * 501), isNotNull);
      expect(Validators.moodNote('short note'), isNull);
      expect(Validators.moodNote('a' * 301), isNotNull);
    });

    test('accepts only Master Prompt moods', () {
      for (final mood in Validators.allowedMoods) {
        expect(Validators.mood(mood), isNull);
      }
      expect(Validators.mood('NonExistentMood'), isNotNull);
    });
  });
}
