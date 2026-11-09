import 'package:flutter_test/flutter_test.dart';
import 'package:rayna_app/core/validation/validators.dart';
import 'package:rayna_app/features/messages/data/message_model.dart';
import 'package:rayna_app/features/messages/data/messages_service.dart';

void main() {
  group('Messages System Tests', () {
    test('MessagesException stores and formats message properly', () {
      const ex = MessagesException('Message cannot be empty.');
      expect(ex.message, equals('Message cannot be empty.'));
      expect(ex.toString(), equals('Message cannot be empty.'));
    });

    test('ChatMessage model toMap produces expected map structure', () {
      const message = ChatMessage(
        id: 'msg123',
        senderUid: 'user1',
        senderName: 'Rayhan',
        text: 'I love you!',
        createdAt: null,
      );

      final map = message.toMap();
      expect(map['senderUid'], equals('user1'));
      expect(map['senderName'], equals('Rayhan'));
      expect(map['text'], equals('I love you!'));
    });

    test('Message text validator rejects empty strings and limits length', () {
      expect(Validators.messageText(''), isNotNull);
      expect(Validators.messageText('   '), isNotNull);
      expect(Validators.messageText('Thinking of you ❤️'), isNull);
      expect(Validators.messageText('a' * 1001), isNotNull);
    });
  });
}
