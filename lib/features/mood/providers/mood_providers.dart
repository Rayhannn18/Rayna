import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/mood_service.dart';

final moodServiceProvider = Provider<MoodService>((ref) => MoodService());
final moodProvider = StreamProvider<DocumentSnapshot<Map<String, dynamic>>>((
  ref,
) {
  return ref.watch(moodServiceProvider).moodStream;
});
