import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/messages_service.dart';

final messagesServiceProvider = Provider<MessagesService>(
  (ref) => MessagesService(),
);
final messagesProvider = StreamProvider<QuerySnapshot<Map<String, dynamic>>>(
  (ref) => ref.watch(messagesServiceProvider).stream,
);
