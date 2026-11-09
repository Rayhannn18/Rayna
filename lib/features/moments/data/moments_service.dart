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

  Future<String> downloadUrl(String storagePath) =>
      _storage.ref(storagePath).getDownloadURL();

  /// Picks an image from camera or gallery.
  Future<XFile?> pickImage({ImageSource source = ImageSource.gallery}) async {
    return _picker.pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 1920,
      maxHeight: 1920,
    );
  }

  /// Uploads photo bytes and creates the moment document in Firestore.
  Future<String> uploadBytes({
    required String pairId,
    required Uint8List bytes,
    required String caption,
    String? senderDisplayName,
  }) async {
    final captionError = Validators.caption(caption);
    if (captionError != null) throw MomentsException(captionError);

    if (bytes.lengthInBytes > 10 * 1024 * 1024) {
      throw const MomentsException('Photo must be smaller than 10 MB.');
    }

    final user = _auth.currentUser;
    final name = senderDisplayName ?? user?.displayName ?? 'Partner';

    final ref = _db.collection('pairs').doc(pairId).collection('moments').doc();
    final path = 'pairs/$pairId/moments/${ref.id}.jpg';

    await ref.set({
      'senderUid': uid,
      'senderName': name,
      'storagePath': path,
      'caption': caption.trim(),
      'status': 'uploading',
      'createdAt': FieldValue.serverTimestamp(),
    });

    try {
      await _storage
          .ref(path)
          .putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
      await ref.update({
        'status': 'ready',
        'uploadedAt': FieldValue.serverTimestamp(),
      });
      return ref.id;
    } catch (e) {
      await ref.update({'status': 'failed'});
      rethrow;
    }
  }

  /// Deletes a moment from both Firestore and Firebase Storage.
  ///
  /// Only the sender who uploaded the photo is authorized to delete it.
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

    // Delete file from Firebase Storage
    if (storagePath != null && storagePath.isNotEmpty) {
      try {
        await _storage.ref(storagePath).delete();
      } catch (_) {
        // Silently ignore if storage file was already deleted or not found
      }
    }
  }
}

class MomentsException implements Exception {
  const MomentsException(this.message);
  final String message;

  @override
  String toString() => message;
}
