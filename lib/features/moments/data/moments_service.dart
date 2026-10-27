import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MomentsService {
  MomentsService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  String get _uid => _auth.currentUser!.uid;
  CollectionReference<Map<String, dynamic>> get _momentsRef =>
      _firestore.collection('users').doc(_uid).collection('moments');

  Stream<QuerySnapshot<Map<String, dynamic>>> get momentsStream =>
      _momentsRef.orderBy('createdAt', descending: true).snapshots();

  Future<void> createMoment(String text) async {
    final cleanText = text.trim();
    if (cleanText.isEmpty)
      throw const MomentsException('Moment cannot be empty.');
    if (cleanText.length > 500) {
      throw const MomentsException('Moment must be 500 characters or less.');
    }
    final user = _auth.currentUser;
    if (user == null) throw const MomentsException('You are not signed in.');

    final userSnapshot = await _firestore.collection('users').doc(_uid).get();
    final partnerUid = userSnapshot.data()?['partnerUid'] as String?;
    if (partnerUid == null || partnerUid.isEmpty) {
      throw const MomentsException(
        'Pair with a partner before sharing moments.',
      );
    }

    final momentRef = _momentsRef.doc();
    final data = {
      'id': momentRef.id,
      'text': cleanText,
      'authorUid': _uid,
      'authorName': user.displayName ?? 'Closer user',
      'createdAt': FieldValue.serverTimestamp(),
    };
    final partnerMomentRef = _firestore
        .collection('users')
        .doc(partnerUid)
        .collection('moments')
        .doc(momentRef.id);
    final batch = _firestore.batch();
    batch.set(momentRef, data);
    batch.set(partnerMomentRef, data);
    await batch.commit();
  }
}

class MomentsException implements Exception {
  const MomentsException(this.message);
  final String message;
}
