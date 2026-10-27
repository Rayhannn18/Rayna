import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PairingService {
  PairingService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  String get _uid => _auth.currentUser!.uid;
  DocumentReference<Map<String, dynamic>> get _userRef =>
      _firestore.collection('users').doc(_uid);

  Stream<DocumentSnapshot<Map<String, dynamic>>> get userStream =>
      _userRef.snapshots();

  Future<String> createPairingCode() async {
    final user = _auth.currentUser;
    if (user == null) throw const PairingException('You are not signed in.');

    final existing = await _userRef.get();
    final existingData = existing.data() ?? <String, dynamic>{};
    if ((existingData['partnerUid'] as String?)?.isNotEmpty == true) {
      throw const PairingException('You are already paired.');
    }
    final existingCode = existingData['pairingCode'] as String?;
    if (existingCode != null && existingCode.isNotEmpty) return existingCode;

    for (var attempt = 0; attempt < 5; attempt++) {
      final code = _randomCode();
      final codeRef = _firestore.collection('pairingCodes').doc(code);
      try {
        await _firestore.runTransaction((transaction) async {
          final snapshot = await transaction.get(codeRef);
          if (snapshot.exists) throw const PairingCodeTakenException();
          transaction.set(codeRef, {
            'uid': _uid,
            'createdAt': FieldValue.serverTimestamp(),
          });
          transaction.update(_userRef, {
            'pairingCode': code,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        });
        return code;
      } on PairingCodeTakenException {
        continue;
      }
    }
    throw const PairingException('Could not create a pairing code. Try again.');
  }

  Future<void> joinPair(String input) async {
    final code = input.trim().toUpperCase();
    if (!RegExp(r'^[A-Z0-9]{6}$').hasMatch(code)) {
      throw const PairingException('Enter a valid 6-character code.');
    }
    final current = _auth.currentUser;
    if (current == null) throw const PairingException('You are not signed in.');
    final currentUserSnapshot = await _userRef.get();
    if ((currentUserSnapshot.data()?['partnerUid'] as String?)?.isNotEmpty ==
        true) {
      throw const PairingException('You are already paired.');
    }

    final codeRef = _firestore.collection('pairingCodes').doc(code);
    await _withRetry(
      () => _firestore.runTransaction((transaction) async {
        final codeSnapshot = await transaction.get(codeRef);
        if (!codeSnapshot.exists) {
          throw const PairingException('Pairing code not found.');
        }
        final data = codeSnapshot.data()!;
        final partnerUid = data['uid'] as String?;
        if (partnerUid == null || partnerUid == _uid) {
          throw const PairingException('You cannot pair with yourself.');
        }
        final partnerRef = _firestore.collection('users').doc(partnerUid);
        final currentSnapshot = await transaction.get(_userRef);
        final partnerSnapshot = await transaction.get(partnerRef);
        final currentData = currentSnapshot.data() ?? <String, dynamic>{};
        final partnerData = partnerSnapshot.data() ?? <String, dynamic>{};
        if (partnerData['partnerUid'] != null ||
            currentData['partnerUid'] != null) {
          throw const PairingException(
            'One of these accounts is already paired.',
          );
        }
        transaction.update(_userRef, {
          'partnerUid': partnerUid,
          'partnerUsername': partnerData['username'],
          'pairingCode': FieldValue.delete(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        transaction.update(partnerRef, {
          'partnerUid': _uid,
          'partnerUsername': currentData['username'],
          'pairingCode': FieldValue.delete(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        transaction.delete(codeRef);
      }),
    );
  }

  Future<T> _withRetry<T>(Future<T> Function() operation) async {
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        return await operation();
      } on FirebaseException catch (error) {
        final retryable =
            error.code == 'unavailable' ||
            error.code == 'deadline-exceeded' ||
            error.code == 'aborted';
        if (!retryable || attempt == 2) rethrow;
        await Future<void>.delayed(Duration(milliseconds: 500 * (attempt + 1)));
      }
    }
    throw const PairingException('Pairing failed. Please try again.');
  }

  Future<void> leavePair() async {
    final currentSnapshot = await _userRef.get();
    final currentData = currentSnapshot.data() ?? <String, dynamic>{};
    final partnerUid = currentData['partnerUid'] as String?;
    if (partnerUid == null || partnerUid.isEmpty) {
      throw const PairingException('You are not paired yet.');
    }

    final partnerRef = _firestore.collection('users').doc(partnerUid);
    await _firestore.runTransaction((transaction) async {
      final partnerSnapshot = await transaction.get(partnerRef);
      final partnerData = partnerSnapshot.data() ?? <String, dynamic>{};
      transaction.update(_userRef, {
        'partnerUid': FieldValue.delete(),
        'partnerUsername': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (partnerSnapshot.exists && partnerData['partnerUid'] == _uid) {
        transaction.update(partnerRef, {
          'partnerUid': FieldValue.delete(),
          'partnerUsername': FieldValue.delete(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    });
  }

  String _randomCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random.secure();
    return List.generate(6, (_) => chars[random.nextInt(chars.length)]).join();
  }
}

class PairingException implements Exception {
  const PairingException(this.message);
  final String message;
}

class PairingCodeTakenException implements Exception {
  const PairingCodeTakenException();
}
