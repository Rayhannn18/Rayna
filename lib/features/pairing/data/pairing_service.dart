import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/validation/validators.dart';

/// Service for couple pairing via both Pairing Codes and Connection Requests.
class PairingService {
  PairingService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  String? get _uidOrNull => _auth.currentUser?.uid;
  String get _uid => _auth.currentUser!.uid;
  DocumentReference<Map<String, dynamic>> get _userRef =>
      _firestore.collection('users').doc(_uid);

  Stream<DocumentSnapshot<Map<String, dynamic>>> get userStream {
    final uid = _uidOrNull;
    if (uid == null) return const Stream.empty();
    return _firestore.collection('users').doc(uid).snapshots();
  }

  /// Search for a user by username (case-insensitive) without exposing email or private data.
  Future<Map<String, dynamic>?> searchUsername(String username) async {
    final lower = username.trim().toLowerCase();
    if (lower.isEmpty) return null;

    // 1. Direct O(1) lookup in public usernames directory
    final usernameDoc = await _firestore
        .collection('usernames')
        .doc(lower)
        .get();
    if (usernameDoc.exists) {
      final uData = usernameDoc.data()!;
      if (uData['uid'] == _uid) return null;
      return {
        'uid': uData['uid'],
        'username': uData['username'],
        'displayName': uData['displayName'] ?? uData['username'],
      };
    }

    // 2. Fallback to users query if legacy username record
    final query = await _firestore
        .collection('users')
        .where('usernameLower', isEqualTo: lower)
        .limit(1)
        .get();
    if (query.docs.isEmpty) return null;
    final data = query.docs.first.data();
    if (data['uid'] == _uid) return null;
    return {
      'uid': data['uid'],
      'username': data['username'],
      'displayName': data['displayName'] ?? data['username'],
    };
  }

  /// Generates a unique 6-character alphanumeric pairing code for the user.
  Future<String> generatePairingCode() async {
    final myDoc = await _userRef.get();
    final myData = myDoc.data() ?? <String, dynamic>{};
    if ((myData['activePairId'] as String?)?.isNotEmpty == true) {
      throw const PairingException('You already have an active partner.');
    }

    // Characters omitting easily confused symbols (0, O, 1, I)
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rand = Random.secure();
    final code = List.generate(
      6,
      (_) => chars[rand.nextInt(chars.length)],
    ).join();

    final codeRef = _firestore.collection('pairingCodes').doc(code);
    await codeRef.set({
      'code': code,
      'uid': _uid,
      'username': myData['username'] ?? '',
      'displayName': myData['displayName'] ?? '',
      'createdAt': FieldValue.serverTimestamp(),
      'status': 'active',
    });

    await _userRef.set({
      'pairingCode': code,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    return code;
  }

  /// Connects with a partner using their 6-character pairing code.
  Future<void> connectWithPairingCode(String rawCode) async {
    final code = Validators.normalizePairingCode(rawCode);
    if (code == null) {
      throw const PairingException(
        'Please enter a valid 6-character pairing code (letters and numbers only).',
      );
    }

    final codeRef = _firestore.collection('pairingCodes').doc(code);

    await _firestore.runTransaction((transaction) async {
      final codeSnap = await transaction.get(codeRef);
      if (!codeSnap.exists) {
        throw const PairingException(
          'Pairing code not found. Please check and try again.',
        );
      }
      final codeData = codeSnap.data()!;
      if (codeData['status'] != 'active') {
        throw const PairingException(
          'This pairing code has already been used or is expired.',
        );
      }
      final partnerUid = codeData['uid'] as String;
      if (partnerUid == _uid) {
        throw const PairingException('You cannot pair with your own code.');
      }

      final myDoc = await transaction.get(_userRef);
      final myData = myDoc.data() ?? <String, dynamic>{};
      if ((myData['activePairId'] as String?)?.isNotEmpty == true) {
        throw const PairingException('You already have an active partner.');
      }

      final partnerRef = _firestore.collection('users').doc(partnerUid);
      final partnerDoc = await transaction.get(partnerRef);
      if (!partnerDoc.exists) {
        throw const PairingException('Partner account not found.');
      }
      final partnerData = partnerDoc.data() ?? <String, dynamic>{};
      if ((partnerData['activePairId'] as String?)?.isNotEmpty == true) {
        throw const PairingException(
          'This user already has an active partner.',
        );
      }

      final pairRef = _firestore.collection('pairs').doc();
      final memberUids = [_uid, partnerUid]..sort();

      transaction.set(pairRef, {
        'memberUids': memberUids,
        'status': 'active',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'pairedVia': 'code',
      });

      transaction.update(_userRef, {
        'activePairId': pairRef.id,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      transaction.update(partnerRef, {
        'activePairId': pairRef.id,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      transaction.update(codeRef, {
        'status': 'used',
        'usedByUid': _uid,
        'usedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  /// Send a connection request to another user.
  Future<void> sendConnectionRequest(String toUid) async {
    if (toUid == _uid) {
      throw const PairingException('You cannot send a request to yourself.');
    }
    final myDoc = await _userRef.get();
    final myData = myDoc.data() ?? <String, dynamic>{};
    if ((myData['activePairId'] as String?)?.isNotEmpty == true) {
      throw const PairingException('You already have an active partner.');
    }
    final targetDoc = await _firestore.collection('users').doc(toUid).get();
    if (!targetDoc.exists) throw const PairingException('User not found.');
    final targetData = targetDoc.data() ?? <String, dynamic>{};
    if ((targetData['activePairId'] as String?)?.isNotEmpty == true) {
      throw const PairingException('This user already has a partner.');
    }
    // Check duplicate pending
    final existing = await _firestore
        .collection('connectionRequests')
        .where('fromUid', isEqualTo: _uid)
        .where('toUid', isEqualTo: toUid)
        .where('status', isEqualTo: 'pending')
        .limit(1)
        .get();
    if (existing.docs.isNotEmpty) {
      throw const PairingException('You already sent a request to this user.');
    }
    // Check reverse
    final reverse = await _firestore
        .collection('connectionRequests')
        .where('fromUid', isEqualTo: toUid)
        .where('toUid', isEqualTo: _uid)
        .where('status', isEqualTo: 'pending')
        .limit(1)
        .get();
    if (reverse.docs.isNotEmpty) {
      throw const PairingException(
        'This user already sent you a request. Check your pending requests.',
      );
    }
    await _firestore.collection('connectionRequests').add({
      'fromUid': _uid,
      'fromUsername': myData['username'] ?? '',
      'fromDisplayName': myData['displayName'] ?? '',
      'toUid': toUid,
      'toUsername': targetData['username'] ?? '',
      'toDisplayName': targetData['displayName'] ?? '',
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> get incomingRequestsStream {
    final uid = _uidOrNull;
    if (uid == null) return const Stream.empty();
    return _firestore
        .collection('connectionRequests')
        .where('toUid', isEqualTo: uid)
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> get outgoingRequestsStream {
    final uid = _uidOrNull;
    if (uid == null) return const Stream.empty();
    return _firestore
        .collection('connectionRequests')
        .where('fromUid', isEqualTo: uid)
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  /// Accept a connection request — create a pair and update both users.
  Future<void> acceptRequest(String requestId) async {
    final requestRef = _firestore
        .collection('connectionRequests')
        .doc(requestId);
    await _firestore.runTransaction((transaction) async {
      final snap = await transaction.get(requestRef);
      if (!snap.exists) throw const PairingException('Request not found.');
      final data = snap.data()!;
      if (data['toUid'] != _uid) {
        throw const PairingException('Only the recipient can accept.');
      }
      if (data['status'] != 'pending') {
        throw const PairingException('This request is no longer pending.');
      }
      final fromUid = data['fromUid'] as String;
      final myDoc = await transaction.get(_userRef);
      final myData = myDoc.data() ?? <String, dynamic>{};
      if ((myData['activePairId'] as String?)?.isNotEmpty == true) {
        throw const PairingException('You already have an active partner.');
      }
      final partnerRef = _firestore.collection('users').doc(fromUid);
      final partnerDoc = await transaction.get(partnerRef);
      final partnerData = partnerDoc.data() ?? <String, dynamic>{};
      if ((partnerData['activePairId'] as String?)?.isNotEmpty == true) {
        throw const PairingException('The other user already has a partner.');
      }
      final pairRef = _firestore.collection('pairs').doc();
      final memberUids = [_uid, fromUid]..sort();
      transaction.set(pairRef, {
        'memberUids': memberUids,
        'status': 'active',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'pairedVia': 'request',
      });
      transaction.update(_userRef, {
        'activePairId': pairRef.id,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      transaction.update(partnerRef, {
        'activePairId': pairRef.id,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      transaction.update(requestRef, {
        'status': 'accepted',
        'respondedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  /// Reject a connection request.
  Future<void> rejectRequest(String requestId) async {
    final ref = _firestore.collection('connectionRequests').doc(requestId);
    await _firestore.runTransaction((transaction) async {
      final snap = await transaction.get(ref);
      if (!snap.exists) throw const PairingException('Request not found.');
      final data = snap.data()!;
      if (data['toUid'] != _uid) {
        throw const PairingException('Only the recipient can reject.');
      }
      if (data['status'] != 'pending') {
        throw const PairingException('This request is no longer pending.');
      }
      transaction.update(ref, {
        'status': 'rejected',
        'respondedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  /// Get the active pair ID.
  Future<String?> getActivePairId() async {
    final doc = await _userRef.get();
    return doc.data()?['activePairId'] as String?;
  }

  /// Get partner data from the pair.
  Future<Map<String, dynamic>?> getPartnerData() async {
    final pairId = await getActivePairId();
    if (pairId == null || pairId.isEmpty) return null;
    final pairDoc = await _firestore.collection('pairs').doc(pairId).get();
    if (!pairDoc.exists) return null;
    final members = List<String>.from(pairDoc.data()!['memberUids'] ?? []);
    final partnerUid = members.firstWhere(
      (uid) => uid != _uid,
      orElse: () => '',
    );
    if (partnerUid.isEmpty) return null;
    final doc = await _firestore.collection('users').doc(partnerUid).get();
    return doc.data();
  }

  /// Leave the current pair.
  Future<void> leavePair() async {
    final myDoc = await _userRef.get();
    final myData = myDoc.data() ?? <String, dynamic>{};
    final pairId = myData['activePairId'] as String?;
    if (pairId == null || pairId.isEmpty) {
      throw const PairingException('You are not paired yet.');
    }
    final pairRef = _firestore.collection('pairs').doc(pairId);
    await _firestore.runTransaction((transaction) async {
      final pairDoc = await transaction.get(pairRef);
      if (!pairDoc.exists) {
        transaction.update(_userRef, {
          'activePairId': FieldValue.delete(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        return;
      }
      final members = List<String>.from(pairDoc.data()!['memberUids'] ?? []);
      final partnerUid = members.firstWhere(
        (uid) => uid != _uid,
        orElse: () => '',
      );
      transaction.update(pairRef, {
        'status': 'dissolved',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      transaction.update(_userRef, {
        'activePairId': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (partnerUid.isNotEmpty) {
        transaction.update(_firestore.collection('users').doc(partnerUid), {
          'activePairId': FieldValue.delete(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    });
  }
}

class PairingException implements Exception {
  const PairingException(this.message);
  final String message;

  @override
  String toString() => message;
}
