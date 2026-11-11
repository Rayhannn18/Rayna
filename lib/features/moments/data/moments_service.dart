import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/validation/validators.dart';

class MomentsService {
  MomentsService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    FirebaseStorage? storage,
    ImagePicker? picker,
  }) : _firestore = firestore,
       _authInstance = auth,
       _storageInstance = storage,
       _pickerInstance = picker;

  final FirebaseFirestore? _firestore;
  final FirebaseAuth? _authInstance;
  final FirebaseStorage? _storageInstance;
  final ImagePicker? _pickerInstance;

  FirebaseFirestore get _db => _firestore ?? FirebaseFirestore.instance;
  FirebaseAuth get _auth => _authInstance ?? FirebaseAuth.instance;
  FirebaseStorage get _storage => _storageInstance ?? FirebaseStorage.instance;
  ImagePicker get _picker => _pickerInstance ?? ImagePicker();

  String get uid => _auth.currentUser!.uid;

  /// Stream of all shared moments in the pair, sorted chronologically descending.
  Stream<QuerySnapshot<Map<String, dynamic>>> stream(String pairId) => _db
      .collection('pairs')
      .doc(pairId)
      .collection('moments')
      .orderBy('createdAt', descending: true)
      .snapshots();

  /// Stream of a single moment document.
  Stream<DocumentSnapshot<Map<String, dynamic>>> momentStream({
    required String pairId,
    required String momentId,
  }) => _db
      .collection('pairs')
      .doc(pairId)
      .collection('moments')
      .doc(momentId)
      .snapshots();

  /// Resolves download URL with fallback between primary and secondary storage buckets.
  Future<String> downloadUrl(String storagePath) async {
    try {
      return await _storage.ref(storagePath).getDownloadURL();
    } catch (_) {
      try {
        final fallback = FirebaseStorage.instanceFor(
          bucket: 'gs://closer-3e8d7.appspot.com',
        );
        return await fallback.ref(storagePath).getDownloadURL();
      } catch (_) {
        final fallback2 = FirebaseStorage.instanceFor(
          bucket: 'gs://closer-3e8d7.firebasestorage.app',
        );
        return await fallback2.ref(storagePath).getDownloadURL();
      }
    }
  }

  /// Picks an image from camera or gallery with optimal compression for fast transfers.
  Future<XFile?> pickImage({ImageSource source = ImageSource.gallery}) async {
    return _picker.pickImage(
      source: source,
      imageQuality: 72,
      maxWidth: 1080,
      maxHeight: 1080,
    );
  }

  /// Uploads photo bytes. Tries Firebase Storage first, and seamlessly falls back
  /// to an embedded Firestore base64 payload if Storage bucket is unprovisioned or unreachable.
  Future<String> uploadBytes({
    required String pairId,
    required Uint8List bytes,
    required String caption,
    String? senderDisplayName,
  }) async {
    final captionError = Validators.caption(caption);
    if (captionError != null) throw MomentsException(captionError);

    final user = _auth.currentUser;
    final name = senderDisplayName ?? user?.displayName ?? 'Partner';

    final ref = _db.collection('pairs').doc(pairId).collection('moments').doc();
    final path = 'pairs/$pairId/moments/${ref.id}.jpg';

    String resolvedDownloadUrl;

    // 1. Attempt upload to Firebase Storage
    try {
      final uploadTask = _storage
          .ref(path)
          .putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
      final snapshot = await uploadTask;
      resolvedDownloadUrl = await snapshot.ref.getDownloadURL();
    } catch (storageError) {
      // 2. If Storage is unprovisioned or object-not-found, attempt legacy bucket
      try {
        final fallback = FirebaseStorage.instanceFor(
          bucket: 'gs://closer-3e8d7.appspot.com',
        );
        final snapshot2 = await fallback
            .ref(path)
            .putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
        resolvedDownloadUrl = await snapshot2.ref.getDownloadURL();
      } catch (_) {
        // 3. Resilient Fallback: Encode photo as data URI directly in Firestore
        // This ensures couple photo sharing NEVER fails even when Cloud Storage bucket is down
        final base64String = base64Encode(bytes);
        resolvedDownloadUrl = 'data:image/jpeg;base64,$base64String';
      }
    }

    // 4. Save moment document in Firestore with resolved download URL
    await ref.set({
      'senderUid': uid,
      'senderName': name,
      'storagePath': path,
      'downloadUrl': resolvedDownloadUrl,
      'caption': caption.trim(),
      'status': 'ready',
      'createdAt': FieldValue.serverTimestamp(),
      'uploadedAt': FieldValue.serverTimestamp(),
    });

    return ref.id;
  }

  /// Deletes a moment from both Firestore and Firebase Storage.
  Future<void> deleteMoment({
    required String pairId,
    required String momentId,
  }) async {
    final docRef = _db
        .collection('pairs')
        .doc(pairId)
        .collection('moments')
        .doc(momentId);

    final snapshot = await docRef.get();
    if (!snapshot.exists) {
      throw const MomentsException('Moment not found.');
    }

    final data = snapshot.data()!;
    if (data['senderUid'] != uid) {
      throw const MomentsException(
        'Only the sender who shared this photo can delete it.',
      );
    }

    final storagePath = data['storagePath'] as String?;

    // Delete Firestore document first
    await docRef.delete();

    // Delete file from Firebase Storage if it was uploaded there
    if (storagePath != null && storagePath.isNotEmpty) {
      try {
        await _storage.ref(storagePath).delete();
      } catch (_) {}
    }
  }
}

class MomentsException implements Exception {
  const MomentsException(this.message);
  final String message;

  @override
  String toString() => message;
}
