import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/validation/validators.dart';
import 'mood_config.dart';

class MoodService {
  MoodService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _db = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  static const int defaultHistoryLimit = 25;

  String get _uid {
    final user = _auth.currentUser;
    if (user == null) {
      throw const MoodException('Please sign in to share your mood.');
    }
    return user.uid;
  }

  CollectionReference<Map<String, dynamic>> _moodsCollection(String pairId) =>
      _db.collection('pairs').doc(pairId).collection('moods');

  CollectionReference<Map<String, dynamic>> _historyCollection(String pairId) =>
      _db.collection('pairs').doc(pairId).collection('moodHistory');

  /// Updates current user's mood in `pairs/{pairId}/moods/{uid}` AND appends a
  /// permanent check-in record in `pairs/{pairId}/moodHistory/{historyId}`
  /// atomically using a Firestore [WriteBatch].
  Future<String> setMood({
    required String pairId,
    required String mood,
    String note = '',
    String? displayName,
  }) async {
    final cleanPairId = pairId.trim();
    if (cleanPairId.isEmpty) {
      throw const MoodException('Pair with your partner first.');
    }

    final moodError = Validators.mood(mood) ?? Validators.moodNote(note);
    if (moodError != null) {
      throw MoodException(moodError);
    }

    final user = _auth.currentUser;
    if (user == null) {
      throw const MoodException('Please sign in to share your mood.');
    }

    final uid = user.uid;
    final trimmedName = (displayName ?? user.displayName ?? '').trim();
    final resolvedName = trimmedName.isNotEmpty ? trimmedName : 'You';
    final trimmedNote = note.trim();
    final category = MoodConfig.categoryFor(mood);
    final emoji = MoodConfig.emojiFor(mood);

    final currentMoodRef = _moodsCollection(cleanPairId).doc(uid);
    final historyRef = _historyCollection(cleanPairId).doc();

    final batch = _db.batch();

    batch.set(currentMoodRef, {
      'uid': uid,
      'displayName': resolvedName,
      'mood': mood,
      'category': category,
      'emoji': emoji,
      'note': trimmedNote,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': uid,
    });

    batch.set(historyRef, {
      'uid': uid,
      'displayName': resolvedName,
      'mood': mood,
      'category': category,
      'emoji': emoji,
      'note': trimmedNote,
      'createdAt': FieldValue.serverTimestamp(),
      'pairId': cleanPairId,
    });

    await batch.commit();
    return historyRef.id;
  }

  /// Real-time stream of all current moods in the couple space.
  Stream<QuerySnapshot<Map<String, dynamic>>> stream(String pairId) =>
      _moodsCollection(pairId).snapshots();

  /// Stream of partner's specific current mood in the couple space.
  Stream<DocumentSnapshot<Map<String, dynamic>>> partnerMoodStream({
    required String pairId,
    required String partnerUid,
  }) => _moodsCollection(pairId).doc(partnerUid).snapshots();

  /// Stream of my own current mood in the couple space.
  Stream<DocumentSnapshot<Map<String, dynamic>>> myMoodStream(String pairId) =>
      _moodsCollection(pairId).doc(_uid).snapshots();

  /// Real-time stream of mood history for [pairId], ordered newest first and
  /// bounded by [limit].
  Stream<QuerySnapshot<Map<String, dynamic>>> historyStream({
    required String pairId,
    int limit = defaultHistoryLimit,
  }) {
    return _historyCollection(pairId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots(includeMetadataChanges: true);
  }

  /// Real-time stream of mood history for a specific [uid] within [pairId].
  Stream<QuerySnapshot<Map<String, dynamic>>> userHistoryStream({
    required String pairId,
    required String uid,
    int limit = defaultHistoryLimit,
  }) {
    return _historyCollection(pairId)
        .where('uid', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots(includeMetadataChanges: true);
  }

  /// Cursor-based paginated fetch for loading older history pages.
  Future<QuerySnapshot<Map<String, dynamic>>> fetchHistoryPage({
    required String pairId,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
    int limit = defaultHistoryLimit,
  }) {
    Query<Map<String, dynamic>> query = _historyCollection(
      pairId,
    ).orderBy('createdAt', descending: true).limit(limit);

    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    return query.get();
  }

  /// Deletes a single mood history entry belonging to the signed-in user.
  ///
  /// Never deletes partner entries and never touches `pairs/{pairId}/moods/{uid}`.
  Future<void> deleteHistoryEntry({
    required String pairId,
    required String historyId,
  }) async {
    final uid = _uid;
    final docRef = _historyCollection(pairId).doc(historyId);
    final snapshot = await docRef.get();

    if (!snapshot.exists) return;

    final ownerUid = snapshot.data()?['uid'] as String?;
    if (ownerUid != uid) {
      throw const MoodException('You can only delete your own mood history.');
    }

    await docRef.delete();
  }
}

class MoodException implements Exception {
  const MoodException(this.message);
  final String message;

  @override
  String toString() => message;
}
