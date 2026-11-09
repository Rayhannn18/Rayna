import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/pairing_service.dart';

final pairingServiceProvider = Provider<PairingService>(
  (ref) => PairingService(),
);

final currentUserDocumentProvider =
    StreamProvider<DocumentSnapshot<Map<String, dynamic>>>((ref) {
      return ref.watch(pairingServiceProvider).userStream;
    });

final incomingRequestsProvider =
    StreamProvider<QuerySnapshot<Map<String, dynamic>>>((ref) {
      return ref.watch(pairingServiceProvider).incomingRequestsStream;
    });

final outgoingRequestsProvider =
    StreamProvider<QuerySnapshot<Map<String, dynamic>>>((ref) {
      return ref.watch(pairingServiceProvider).outgoingRequestsStream;
    });
