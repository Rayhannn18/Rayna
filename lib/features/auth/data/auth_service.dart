import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

class AuthService {
  AuthService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  /// Check if a username is already taken.
  Future<bool> isUsernameAvailable(String username) async {
    final cleanUsername = username.trim().toLowerCase();
    if (cleanUsername.isEmpty) return false;
    final doc =
        await _firestore.collection('usernames').doc(cleanUsername).get();
    return !doc.exists;
  }

  Future<void> signIn({required String email, required String password}) async {
    await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<void> register({
    required String displayName,
    required String username,
    required String email,
    required String password,
  }) =>
      signUp(
        email: email,
        password: password,
        displayName: displayName,
        username: username,
      );

  Future<void> signUp({
    required String email,
    required String password,
    required String displayName,
    required String username,
  }) async {
    final cleanUsername = username.trim().toLowerCase();
    final isAvailable = await isUsernameAvailable(cleanUsername);
    if (!isAvailable) {
      throw const UsernameAlreadyTakenException();
    }

    final userCredential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    final user = userCredential.user;
    if (user == null) {
      throw StateError('Firebase User is null after registration.');
    }

    try {
      await _firestore.runTransaction((transaction) async {
        final usernameRef =
            _firestore.collection('usernames').doc(cleanUsername);
        final usernameDoc = await transaction.get(usernameRef);
        if (usernameDoc.exists) {
          throw const UsernameAlreadyTakenException();
        }

        transaction.set(usernameRef, {
          'uid': user.uid,
          'username': username.trim(),
          'displayName': displayName.trim(),
          'createdAt': FieldValue.serverTimestamp(),
        });

        final userRef = _firestore.collection('users').doc(user.uid);
        transaction.set(userRef, {
          'uid': user.uid,
          'email': email.trim().toLowerCase(),
          'displayName': displayName.trim(),
          'username': username.trim(),
          'usernameLower': cleanUsername,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });
      await user.updateDisplayName(displayName.trim());
    } catch (_) {
      // Rollback auth user creation if writing to Firestore failed
      await user.delete();
      rethrow;
    }
  }

  /// Upload a profile photo and return download URL (or base64 fallback)
  Future<String> uploadProfilePhoto(Uint8List bytes) async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('No authenticated user found.');

    final path =
        'users/${user.uid}/profile_${DateTime.now().millisecondsSinceEpoch}.jpg';
    try {
      final uploadTask = _storage
          .ref(path)
          .putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
      final snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } catch (_) {
      try {
        final fallback = FirebaseStorage.instanceFor(
          bucket: 'gs://closer-3e8d7.appspot.com',
        );
        final snapshot2 = await fallback
            .ref(path)
            .putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
        return await snapshot2.ref.getDownloadURL();
      } catch (_) {
        // Fallback to embedded base64 data URI
        final base64String = base64Encode(bytes);
        return 'data:image/jpeg;base64,$base64String';
      }
    }
  }

  /// Update the current user's profile details.
  Future<void> updateProfile({
    required String displayName,
    String? bio,
    String? photoUrl,
    bool removePhoto = false,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('No authenticated user found.');

    final trimmedName = displayName.trim();
    if (trimmedName.isEmpty) {
      throw ArgumentError('Display name cannot be empty.');
    }

    final updates = <String, dynamic>{
      'displayName': trimmedName,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (bio != null) {
      updates['bio'] = bio.trim();
    }
    if (removePhoto) {
      updates['photoURL'] = FieldValue.delete();
      await user.updatePhotoURL(null);
    } else if (photoUrl != null) {
      updates['photoURL'] = photoUrl;
      await user.updatePhotoURL(photoUrl);
    }

    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    final usernameKey = userDoc.data()?['usernameLower'] as String? ??
        userDoc.data()?['username']?.toString().toLowerCase();

    await _firestore.collection('users').doc(user.uid).update(updates);
    if (usernameKey != null && usernameKey.isNotEmpty) {
      try {
        final usernameUpdates = <String, dynamic>{
          'displayName': trimmedName,
          'updatedAt': FieldValue.serverTimestamp(),
        };
        if (removePhoto) {
          usernameUpdates['photoURL'] = FieldValue.delete();
        } else if (photoUrl != null) {
          usernameUpdates['photoURL'] = photoUrl;
        }
        await _firestore.collection('usernames').doc(usernameKey).set(
          usernameUpdates,
          SetOptions(merge: true),
        );
      } catch (_) {}
    }
    await user.updateDisplayName(trimmedName);
  }

  /// Send password reset link to user's registered email.
  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  Future<void> signOut() => _auth.signOut();
}

class UsernameAlreadyTakenException implements Exception {
  const UsernameAlreadyTakenException();

  @override
  String toString() => 'Username is already taken.';
}
