import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/validation/validators.dart';
import 'message_model.dart';

class MessagesService {
  MessagesService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _db = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  String get uid => _auth.currentUser!.uid;

  /// Real-time stream of messages in the couple's private space, sorted newest first.
  Stream<List<ChatMessage>> streamMessages(String pairId) {
    return _db
        .collection('pairs')
        .doc(pairId)
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => ChatMessage.fromFirestore(doc))
              .toList(),
        );
  }

  /// Sends a text message to the couple's private space.
  Future<void> sendMessage({
    required String pairId,
    required String text,
    String? senderName,
  }) async {
    final validationError = Validators.messageText(text);
    if (validationError != null) {
      throw MessagesException(validationError);
    }

    final trimmedText = text.trim();
    final user = _auth.currentUser;
    final name = senderName ?? user?.displayName ?? 'Partner';

    final messagesRef = _db
        .collection('pairs')
        .doc(pairId)
        .collection('messages');
    final pairRef = _db.collection('pairs').doc(pairId);

    final batch = _db.batch();

    // 1. Add new message
    final newMsgRef = messagesRef.doc();
    batch.set(newMsgRef, {
      'senderUid': uid,
      'senderName': name,
      'text': trimmedText,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // 2. Update pair lastMessage snippet for dashboard
    batch.update(pairRef, {
      'lastMessage': trimmedText,
      'lastMessageSenderUid': uid,
      'lastMessageAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  /// Deletes a specific message sent by the user.
  Future<void> deleteMessage({
    required String pairId,
    required String messageId,
  }) async {
    final docRef = _db
        .collection('pairs')
        .doc(pairId)
        .collection('messages')
        .doc(messageId);

    final snap = await docRef.get();
    if (!snap.exists) throw const MessagesException('Message not found.');
    if (snap.data()?['senderUid'] != uid) {
      throw const MessagesException('Only the sender can delete this message.');
    }

    await docRef.delete();
  }
}

class MessagesException implements Exception {
  const MessagesException(this.message);
  final String message;

  @override
  String toString() => message;
}
