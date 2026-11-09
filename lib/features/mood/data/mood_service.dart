import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/validation/validators.dart';

class MoodService {
  MoodService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _db = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  String get _uid => _auth.currentUser!.uid;

  /// Updates current user's mood in the pair's space.
  Future<void> setMood({
    required String pairId,
    required String mood,
    String note = '',
    String? displayName,
  }) {
    final moodError = Validators.mood(mood) ?? Validators.moodNote(note);
    if (moodError != null) return Future.error(MoodException(moodError));

    final user = _auth.currentUser;
    final name = displayName ?? user?.displayName ?? 'Partner';

    return _db
        .collection('pairs')
        .doc(pairId)
        .collection('moods')
        .doc(_uid)
        .set({
          'uid': _uid,
          'displayName': name,
          'mood': mood,
          'note': note.trim(),
          'updatedAt': FieldValue.serverTimestamp(),
          'updatedBy': _uid,
        });
  }

  /// Real-time stream of all moods in the couple space.
  Stream<QuerySnapshot<Map<String, dynamic>>> stream(String pairId) =>
      _db.collection('pairs').doc(pairId).collection('moods').snapshots();

  /// Stream of partner's specific mood in the couple space.
  Stream<DocumentSnapshot<Map<String, dynamic>>> partnerMoodStream({
    required String pairId,
    required String partnerUid,
  }) => _db
      .collection('pairs')
      .doc(pairId)
      .collection('moods')
      .doc(partnerUid)
      .snapshots();

  /// Stream of my own current mood in the couple space.
  Stream<DocumentSnapshot<Map<String, dynamic>>> myMoodStream(String pairId) =>
      _db
          .collection('pairs')
          .doc(pairId)
          .collection('moods')
          .doc(_uid)
          .snapshots();
}

class MoodException implements Exception {
  const MoodException(this.message);
  final String message;

  @override
  String toString() => message;
}
