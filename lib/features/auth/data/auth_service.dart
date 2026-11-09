import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  AuthService({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _auth = auth ?? FirebaseAuth.instance,
      _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  /// Check if a username is already taken.
  Future<bool> isUsernameAvailable(String username) async {
    final cleanUsername = username.trim().toLowerCase();
    if (cleanUsername.isEmpty) return false;
    final doc = await _firestore
        .collection('usernames')
        .doc(cleanUsername)
        .get();
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
  }) async {
    final cleanUsername = username.trim();
    final usernameKey = cleanUsername.toLowerCase();
    final usernameRef = _firestore.collection('usernames').doc(usernameKey);

    // Pre-check before user creation to prevent creating unnecessary Auth accounts
    final preCheck = await usernameRef.get();
    if (preCheck.exists) {
      throw const UsernameAlreadyTakenException();
    }

    final userCredential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final user = userCredential.user!;

    try {
      await _firestore.runTransaction((transaction) async {
        final usernameSnapshot = await transaction.get(usernameRef);
        if (usernameSnapshot.exists) {
          throw const UsernameAlreadyTakenException();
        }
        transaction.set(usernameRef, {
          'uid': user.uid,
          'username': cleanUsername,
          'displayName': displayName.trim(),
          'createdAt': FieldValue.serverTimestamp(),
        });
        transaction.set(_firestore.collection('users').doc(user.uid), {
          'uid': user.uid,
          'displayName': displayName.trim(),
          'username': cleanUsername,
          'usernameLower': usernameKey,
          'email': email.trim(),
          'bio': '',
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

  /// Update the current user's profile details.
  Future<void> updateProfile({required String displayName, String? bio}) async {
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

    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    final usernameKey =
        userDoc.data()?['usernameLower'] as String? ??
        userDoc.data()?['username']?.toString().toLowerCase();

    await _firestore.collection('users').doc(user.uid).update(updates);
    if (usernameKey != null && usernameKey.isNotEmpty) {
      try {
        await _firestore.collection('usernames').doc(usernameKey).set({
          'displayName': trimmedName,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
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
