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
          'createdAt': FieldValue.serverTimestamp(),
        });
        transaction.set(_firestore.collection('users').doc(user.uid), {
          'uid': user.uid,
          'displayName': displayName.trim(),
          'username': cleanUsername,
          'usernameLower': usernameKey,
          'email': email.trim(),
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });
      await user.updateDisplayName(displayName.trim());
    } catch (_) {
      await user.delete();
      rethrow;
    }
  }

  Future<void> signOut() => _auth.signOut();
}

class UsernameAlreadyTakenException implements Exception {
  const UsernameAlreadyTakenException();
}
