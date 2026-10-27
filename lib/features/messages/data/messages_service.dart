import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MessagesService {
  MessagesService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  String get _uid => _auth.currentUser!.uid;
  CollectionReference<Map<String, dynamic>> get _messages =>
      _firestore.collection('users').doc(_uid).collection('messages');
  Stream<QuerySnapshot<Map<String, dynamic>>> get stream =>
      _messages.orderBy('createdAt', descending: true).snapshots();
  Future<void> send(String text) async {
    final clean = text.trim();
    if (clean.isEmpty) return;
    final user = _auth.currentUser;
    if (user == null) return;
    final userData = (await _firestore.collection('users').doc(_uid).get())
        .data();
    final partner = userData?['partnerUid'] as String?;
    if (partner == null || partner.isEmpty)
      throw const MessageException('Pair with a partner first.');
    final ref = _messages.doc();
    final data = {
      'text': clean,
      'senderUid': _uid,
      'senderName': user.displayName ?? 'Closer user',
      'createdAt': FieldValue.serverTimestamp(),
    };
    await ref.set(data);
    await _firestore
        .collection('users')
        .doc(partner)
        .collection('messages')
        .doc(ref.id)
        .set(data);
  }
}

class MessageException implements Exception {
  const MessageException(this.message);
  final String message;
}
