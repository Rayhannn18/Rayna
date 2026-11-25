import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_providers.dart';
import '../data/pairing_service.dart';

final pairingServiceProvider = Provider<PairingService>(
  (ref) => PairingService(),
);

final currentUserDocumentProvider =
    StreamProvider<DocumentSnapshot<Map<String, dynamic>>>((ref) {
      final auth = ref.watch(authStateProvider);
      final user = auth.valueOrNull;
      if (user == null) {
        return const Stream.empty();
      }
      return FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots();
    });

/// Real-time stream of connection requests addressed to the signed-in user.
///
/// Explicitly binds to `authStateProvider`'s `user.uid` so switching accounts
/// immediately re-subscribes with the new UID.
final incomingRequestsProvider =
    StreamProvider<QuerySnapshot<Map<String, dynamic>>>((ref) {
      final auth = ref.watch(authStateProvider);
      final user = auth.valueOrNull;
      if (user == null) {
        return const Stream.empty();
      }
      return ref
          .watch(pairingServiceProvider)
          .incomingRequestsStreamFor(user.uid);
    });

/// Filtered (`status == 'pending'`) and newest-first sorted incoming requests.
final pendingIncomingRequestsProvider =
    Provider<AsyncValue<List<QueryDocumentSnapshot<Map<String, dynamic>>>>>((
      ref,
    ) {
      return ref
          .watch(incomingRequestsProvider)
          .whenData(
            (snapshot) =>
                PairingService.filterAndSortPendingRequests(snapshot.docs),
          );
    });

/// Real-time stream of connection requests sent by the signed-in user.
final outgoingRequestsProvider =
    StreamProvider<QuerySnapshot<Map<String, dynamic>>>((ref) {
      final auth = ref.watch(authStateProvider);
      final user = auth.valueOrNull;
      if (user == null) {
        return const Stream.empty();
      }
      return ref
          .watch(pairingServiceProvider)
          .outgoingRequestsStreamFor(user.uid);
    });
