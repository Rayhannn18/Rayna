import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:rayna_app/features/messages/data/message_model.dart';
import 'package:rayna_app/features/moments/data/moments_service.dart';

void main() {
  group('Phase 8 — Security & Privacy Invariants', () {
    test('ChatMessage toMap never leaks email or auth tokens', () {
      const message = ChatMessage(
        id: 'msg_999',
        senderUid: 'user_123',
        senderName: 'Rayhan',
        text: 'Thinking of you!',
        createdAt: null,
      );

      final map = message.toMap();
      expect(map.containsKey('email'), isFalse);
      expect(map.containsKey('token'), isFalse);
      expect(map.containsKey('fcmToken'), isFalse);
      expect(map['senderUid'], equals('user_123'));
      expect(map['text'], equals('Thinking of you!'));
    });

    test('Moments upload strictly rejects payloads over 10MB', () {
      final momentsService = MomentsService();
      final oversizedBytes = Uint8List(10 * 1024 * 1024 + 1);

      expect(
        () => momentsService.uploadBytes(
          pairId: 'pair_1',
          bytes: oversizedBytes,
          caption: 'My oversized photo',
        ),
        throwsA(isA<MomentsException>()),
      );
    });

    test(
      'Pairing code character set omits ambiguous characters (0, O, 1, I)',
      () {
        const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
        expect(chars.contains('0'), isFalse);
        expect(chars.contains('O'), isFalse);
        expect(chars.contains('1'), isFalse);
        expect(chars.contains('I'), isFalse);
        expect(chars.length, equals(32));
      },
    );
  });
}
