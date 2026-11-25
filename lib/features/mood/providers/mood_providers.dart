import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_providers.dart';
import '../data/mood_history_model.dart';
import '../data/mood_service.dart';

/// Filter modes for the Mood History list.
enum MoodHistoryFilter { all, myMood, partner }

final moodServiceProvider = Provider<MoodService>((ref) => MoodService());

final pairMoodsStreamProvider =
    StreamProvider.family<QuerySnapshot<Map<String, dynamic>>, String>(
      (ref, pairId) => ref.watch(moodServiceProvider).stream(pairId),
    );

/// Selected Mood History filter (client-side, never mutates Firestore).
final moodHistoryFilterProvider = StateProvider<MoodHistoryFilter>(
  (ref) => MoodHistoryFilter.all,
);

/// Current pagination window size for a pair's Mood History stream.
final moodHistoryLimitProvider = StateProvider.family<int, String>(
  (ref, pairId) => MoodService.defaultHistoryLimit,
);

/// Single real-time Firestore snapshot stream for a pair's Mood History.
final moodHistorySnapshotProvider =
    StreamProvider.family<QuerySnapshot<Map<String, dynamic>>, String>((
      ref,
      pairId,
    ) {
      final limit = ref.watch(moodHistoryLimitProvider(pairId));
      return ref
          .watch(moodServiceProvider)
          .historyStream(pairId: pairId, limit: limit);
    });

/// Whether the current Mood History snapshot is being served from local cache
/// (e.g. when the device is offline).
final moodHistoryIsFromCacheProvider = Provider.family<bool, String>((
  ref,
  pairId,
) {
  final snapshot = ref.watch(moodHistorySnapshotProvider(pairId)).valueOrNull;
  return snapshot?.metadata.isFromCache ?? false;
});

/// All parsed Mood History entries for [pairId], ordered newest to oldest.
final moodHistoryEntriesProvider =
    Provider.family<AsyncValue<List<MoodHistoryEntry>>, String>((ref, pairId) {
      final asyncSnap = ref.watch(moodHistorySnapshotProvider(pairId));
      return asyncSnap.whenData(
        (snapshot) =>
            snapshot.docs.map(MoodHistoryEntry.fromFirestore).toList(),
      );
    });

/// Pure filter helper so filtering logic can be unit-tested directly.
List<MoodHistoryEntry> filterMoodHistoryEntries({
  required List<MoodHistoryEntry> entries,
  required MoodHistoryFilter filter,
  required String? currentUid,
}) {
  switch (filter) {
    case MoodHistoryFilter.all:
      return entries;
    case MoodHistoryFilter.myMood:
      if (currentUid == null || currentUid.isEmpty) return const [];
      return entries.where((entry) => entry.uid == currentUid).toList();
    case MoodHistoryFilter.partner:
      if (currentUid == null || currentUid.isEmpty) return const [];
      return entries.where((entry) => entry.uid != currentUid).toList();
  }
}

/// Signed-in user's own Mood History entries for [pairId].
final myMoodHistoryProvider =
    Provider.family<AsyncValue<List<MoodHistoryEntry>>, String>((ref, pairId) {
      final currentUid = ref.watch(authStateProvider).valueOrNull?.uid;
      return ref
          .watch(moodHistoryEntriesProvider(pairId))
          .whenData(
            (entries) => filterMoodHistoryEntries(
              entries: entries,
              filter: MoodHistoryFilter.myMood,
              currentUid: currentUid,
            ),
          );
    });

/// Partner's Mood History entries for [pairId].
final partnerMoodHistoryProvider =
    Provider.family<AsyncValue<List<MoodHistoryEntry>>, String>((ref, pairId) {
      final currentUid = ref.watch(authStateProvider).valueOrNull?.uid;
      return ref
          .watch(moodHistoryEntriesProvider(pairId))
          .whenData(
            (entries) => filterMoodHistoryEntries(
              entries: entries,
              filter: MoodHistoryFilter.partner,
              currentUid: currentUid,
            ),
          );
    });

/// Filtered Mood History entries based on [moodHistoryFilterProvider] and UID.
final filteredMoodHistoryProvider =
    Provider.family<AsyncValue<List<MoodHistoryEntry>>, String>((ref, pairId) {
      final filter = ref.watch(moodHistoryFilterProvider);
      final currentUid = ref.watch(authStateProvider).valueOrNull?.uid;
      return ref
          .watch(moodHistoryEntriesProvider(pairId))
          .whenData(
            (entries) => filterMoodHistoryEntries(
              entries: entries,
              filter: filter,
              currentUid: currentUid,
            ),
          );
    });
