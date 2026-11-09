import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/message_model.dart';
import '../data/messages_service.dart';

final messagesServiceProvider = Provider<MessagesService>(
  (ref) => MessagesService(),
);

final messagesStreamProvider = StreamProvider.family<List<ChatMessage>, String>(
  (ref, pairId) {
    return ref.watch(messagesServiceProvider).streamMessages(pairId);
  },
);
