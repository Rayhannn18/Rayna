import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/moments_service.dart';

final momentsServiceProvider = Provider<MomentsService>(
  (ref) => MomentsService(),
);

final momentsProvider = StreamProvider<QuerySnapshot<Map<String, dynamic>>>((
  ref,
) {
  return ref.watch(momentsServiceProvider).momentsStream;
});
