import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MoodService {
  MoodService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  String get _uid => _auth.currentUser!.uid;
  DocumentReference<Map<String, dynamic>> get _moodRef => _firestore
      .collection('users')
      .doc(_uid)
      .collection('mood')
      .doc('current');

  Stream<DocumentSnapshot<Map<String, dynamic>>> get moodStream =>
      _moodRef.snapshots();

  Future<void> setMood(String mood, String emoji) async {
    final user = _auth.currentUser;
    if (user == null) throw const MoodException('You are not signed in.');
    final userData = (await _firestore.collection('users').doc(_uid).get())
        .data();
    final partnerUid = userData?['partnerUid'] as String?;
    if (partnerUid == null || partnerUid.isEmpty) {
      throw const MoodException(
        'Pair with a partner before sharing your mood.',
      );
    }
    final data = {
      'uid': _uid,
      'mood': mood,
      'emoji': emoji,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    await _moodRef.set(data);
    await _firestore
        .collection('users')
        .doc(partnerUid)
        .collection('mood')
        .doc('partner')
        .set(data);
  }
}

class MoodException implements Exception {
  const MoodException(this.message);
  final String message;
}
