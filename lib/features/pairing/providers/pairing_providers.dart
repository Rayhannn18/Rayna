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

final incomingRequestsProvider =
    StreamProvider<QuerySnapshot<Map<String, dynamic>>>((ref) {
      final auth = ref.watch(authStateProvider);
      final user = auth.valueOrNull;
      if (user == null) {
        return const Stream.empty();
      }
      return ref.watch(pairingServiceProvider).incomingRequestsStream;
    });

final outgoingRequestsProvider =
    StreamProvider<QuerySnapshot<Map<String, dynamic>>>((ref) {
      final auth = ref.watch(authStateProvider);
      final user = auth.valueOrNull;
      if (user == null) {
        return const Stream.empty();
      }
      return ref.watch(pairingServiceProvider).outgoingRequestsStream;
    });
