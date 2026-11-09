import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/mood_service.dart';

final moodServiceProvider = Provider<MoodService>((ref) => MoodService());

final pairMoodsStreamProvider =
    StreamProvider.family<QuerySnapshot<Map<String, dynamic>>, String>(
      (ref, pairId) => ref.watch(moodServiceProvider).stream(pairId),
    );
