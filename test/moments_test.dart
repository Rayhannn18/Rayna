import 'package:flutter_test/flutter_test.dart';
import 'package:rayna_app/core/validation/validators.dart';
import 'package:rayna_app/features/moments/data/moments_service.dart';

void main() {
  group('Moments System Tests', () {
    test('MomentsException properly stores and outputs message', () {
      const ex = MomentsException('Photo must be smaller than 10 MB.');
      expect(ex.message, equals('Photo must be smaller than 10 MB.'));
      expect(ex.toString(), equals('Photo must be smaller than 10 MB.'));
    });

    test('Caption validator accepts valid captions and trims', () {
      expect(Validators.caption(''), isNull);
      expect(Validators.caption('   '), isNull);
      expect(Validators.caption('Having coffee with a view ☕'), isNull);
    });

    test('Caption validator rejects captions over 500 characters', () {
      final longCaption = 'A' * 501;
      expect(Validators.caption(longCaption), isNotNull);
    });
  });
}
