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

  /// Normalizes a raw username input (strips leading `@`, trims, lowercases).
  static String normalizeUsername(String raw) {
    return raw.trim().replaceFirst(RegExp(r'^@+'), '').toLowerCase();
  }

  /// Filters a list of raw connectionRequest maps/docs to `pending` only and
  /// sorts newest-first (treating unresolved server timestamps as newest).
  static List<QueryDocumentSnapshot<Map<String, dynamic>>>
  filterAndSortPendingRequests(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final pending = docs
        .where((doc) => doc.data()['status'] == 'pending')
        .toList();
    pending.sort((a, b) {
      final aTs = a.data()['createdAt'] as Timestamp?;
      final bTs = b.data()['createdAt'] as Timestamp?;
      if (aTs == null && bTs == null) return 0;
      if (aTs == null) return -1; // Pending server timestamp is newest
      if (bTs == null) return 1;
      return bTs.compareTo(aTs);
    });
    return pending;
  }

  /// Search for a user by username (case-insensitive) without exposing email or private data.
  Future<Map<String, dynamic>?> searchUsername(String username) async {
    final lower = normalizeUsername(username);
    if (lower.isEmpty) return null;

    final currentUid = _uidOrNull;
    if (currentUid == null) {
      throw const PairingException('Please sign in first.');
    }

    // 1. Direct O(1) lookup in public usernames directory
    final usernameDoc = await _firestore
        .collection('usernames')
        .doc(lower)
        .get();
    if (usernameDoc.exists) {
      final uData = usernameDoc.data()!;
      final foundUid = (uData['uid'] as String?)?.trim() ?? '';
      if (foundUid.isEmpty || foundUid == currentUid) return null;

      // Verify the referenced user document exists and read authoritative fields
      final userDoc = await _firestore.collection('users').doc(foundUid).get();
      if (!userDoc.exists) return null;
      final userData = userDoc.data() ?? <String, dynamic>{};
      final resolvedUsername =
          (userData['username'] as String?)?.trim() ??
          (uData['username'] as String?)?.trim() ??
          lower;
      final resolvedDisplayName =
          (userData['displayName'] as String?)?.trim() ??
          (uData['displayName'] as String?)?.trim() ??
          resolvedUsername;

      return {
        'uid': foundUid,
        'username': resolvedUsername,
        'displayName': resolvedDisplayName.isNotEmpty
            ? resolvedDisplayName
            : resolvedUsername,
      };
    }

    // 2. Fallback to users query if legacy username record
    final query = await _firestore
        .collection('users')
        .where('usernameLower', isEqualTo: lower)
        .limit(1)
        .get();
    if (query.docs.isEmpty) return null;
    final doc = query.docs.first;
    final data = doc.data();
    final foundUid = (data['uid'] as String?)?.trim() ?? doc.id;
    if (foundUid.isEmpty || foundUid == currentUid) return null;
    final resolvedUsername = (data['username'] as String?)?.trim() ?? lower;
    final resolvedDisplayName =
        (data['displayName'] as String?)?.trim() ?? resolvedUsername;
    return {
      'uid': foundUid,
      'username': resolvedUsername,
      'displayName': resolvedDisplayName.isNotEmpty
          ? resolvedDisplayName
          : resolvedUsername,
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
  Future<String> sendConnectionRequest(String toUid) async {
    final currentUid = _uidOrNull;
    if (currentUid == null) {
      throw const PairingException('Please sign in first.');
    }

    final cleanToUid = toUid.trim();
    if (cleanToUid.isEmpty) {
      throw const PairingException('Invalid recipient user.');
    }
    if (cleanToUid == currentUid) {
      throw const PairingException('You cannot send a request to yourself.');
    }

    final myDoc = await _firestore.collection('users').doc(currentUid).get();
    final myData = myDoc.data() ?? <String, dynamic>{};
    if ((myData['activePairId'] as String?)?.isNotEmpty == true) {
      throw const PairingException('You already have an active partner.');
    }

    final targetDoc = await _firestore
        .collection('users')
        .doc(cleanToUid)
        .get();
    if (!targetDoc.exists) throw const PairingException('User not found.');
    final targetData = targetDoc.data() ?? <String, dynamic>{};
    if ((targetData['activePairId'] as String?)?.isNotEmpty == true) {
      throw const PairingException('This user already has a partner.');
    }

    // Single-field equality queries guarantee zero composite-index failures
    // and match `allow read: if fromUid == auth.uid || toUid == auth.uid`.
    final mySentSnapshot = await _firestore
        .collection('connectionRequests')
        .where('fromUid', isEqualTo: currentUid)
        .get();
    final hasDuplicatePending = mySentSnapshot.docs.any((doc) {
      final d = doc.data();
      return d['toUid'] == cleanToUid && d['status'] == 'pending';
    });
    if (hasDuplicatePending) {
      throw const PairingException('You already sent a request to this user.');
    }

    final myIncomingSnapshot = await _firestore
        .collection('connectionRequests')
        .where('toUid', isEqualTo: currentUid)
        .get();
    final hasReversePending = myIncomingSnapshot.docs.any((doc) {
      final d = doc.data();
      return d['fromUid'] == cleanToUid && d['status'] == 'pending';
    });
    if (hasReversePending) {
      throw const PairingException(
        'This user already sent you a request. Check your pending requests.',
      );
    }

    final fromUsername = (myData['username'] as String?)?.trim() ?? '';
    final fromDisplayName =
        (myData['displayName'] as String?)?.trim() ??
        _auth.currentUser?.displayName?.trim() ??
        fromUsername;
    final toUsername = (targetData['username'] as String?)?.trim() ?? '';
    final toDisplayName =
        (targetData['displayName'] as String?)?.trim() ?? toUsername;

    final docRef = await _firestore.collection('connectionRequests').add({
      'fromUid': currentUid,
      'fromUsername': fromUsername,
      'fromDisplayName': fromDisplayName.isNotEmpty
          ? fromDisplayName
          : 'Rayna User',
      'toUid': cleanToUid,
      'toUsername': toUsername,
      'toDisplayName': toDisplayName.isNotEmpty ? toDisplayName : 'Partner',
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
    return docRef.id;
  }

  /// Real-time stream of connection requests addressed to [uid].
  ///
  /// Uses a single-field equality filter (`toUid == uid`) so it works reliably
  /// without requiring manual composite index deployment, while staying 100%
  /// aligned with `allow read: if resource.data.toUid == request.auth.uid`.
  Stream<QuerySnapshot<Map<String, dynamic>>> incomingRequestsStreamFor(
    String uid,
  ) {
    if (uid.isEmpty) return const Stream.empty();
    return _firestore
        .collection('connectionRequests')
        .where('toUid', isEqualTo: uid)
        .snapshots();
  }

  /// Real-time stream of connection requests sent by [uid].
  Stream<QuerySnapshot<Map<String, dynamic>>> outgoingRequestsStreamFor(
    String uid,
  ) {
    if (uid.isEmpty) return const Stream.empty();
    return _firestore
        .collection('connectionRequests')
        .where('fromUid', isEqualTo: uid)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> get incomingRequestsStream {
    final uid = _uidOrNull;
    if (uid == null) return const Stream.empty();
    return incomingRequestsStreamFor(uid);
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> get outgoingRequestsStream {
    final uid = _uidOrNull;
    if (uid == null) return const Stream.empty();
    return outgoingRequestsStreamFor(uid);
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

  /// Leave the current pair cleanly without failing if partner's user document
  /// cannot be updated due to strict security rules.
  Future<void> leavePair() async {
    final myDoc = await _userRef.get();
    final myData = myDoc.data() ?? <String, dynamic>{};
    final pairId = myData['activePairId'] as String?;
    if (pairId == null || pairId.isEmpty) {
      throw const PairingException('You are not paired yet.');
    }

    final pairRef = _firestore.collection('pairs').doc(pairId);
    final pairDoc = await pairRef.get();

    String partnerUid = '';
    final batch = _firestore.batch();

    if (pairDoc.exists) {
      final members = List<String>.from(pairDoc.data()?['memberUids'] ?? []);
      partnerUid = members.firstWhere((uid) => uid != _uid, orElse: () => '');
      batch.update(pairRef, {
        'status': 'dissolved',
        'dissolvedBy': _uid,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    batch.update(_userRef, {
      'activePairId': FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();

    // Best-effort: clear partner's activePairId if Firestore rules permit it.
    if (partnerUid.isNotEmpty) {
      try {
        await _firestore.collection('users').doc(partnerUid).update({
          'activePairId': FieldValue.delete(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } catch (_) {
        // Safe to ignore: pair status is already marked 'dissolved'.
      }
    }
  }
}

class PairingException implements Exception {
  const PairingException(this.message);
  final String message;

  @override
  String toString() => message;
}
