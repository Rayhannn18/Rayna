import 'package:cloud_firestore/cloud_firestore.dart';

import 'mood_config.dart';

/// Immutable model representing a single check-in record stored at
/// `pairs/{pairId}/moodHistory/{historyId}`.
class MoodHistoryEntry {
  const MoodHistoryEntry({
    required this.id,
    required this.uid,
    required this.displayName,
    required this.mood,
    required this.category,
    required this.emoji,
    required this.note,
    required this.createdAt,
    required this.pairId,
  });

  final String id;
  final String uid;
  final String displayName;
  final String mood;
  final String category;
  final String emoji;
  final String note;
  final DateTime? createdAt;
  final String pairId;

  factory MoodHistoryEntry.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    return MoodHistoryEntry.fromMap(id: doc.id, data: data);
  }

  factory MoodHistoryEntry.fromMap({
    required String id,
    required Map<String, dynamic> data,
  }) {
    final mood = (data['mood'] as String?)?.trim() ?? '';
    final rawCategory = (data['category'] as String?)?.trim() ?? '';
    final rawEmoji = (data['emoji'] as String?)?.trim() ?? '';
    final rawCreatedAt = data['createdAt'];

    DateTime? parsedCreatedAt;
    if (rawCreatedAt is Timestamp) {
      parsedCreatedAt = rawCreatedAt.toDate().toLocal();
    } else if (rawCreatedAt is DateTime) {
      parsedCreatedAt = rawCreatedAt.toLocal();
    }

    return MoodHistoryEntry(
      id: id,
      uid: (data['uid'] as String?)?.trim() ?? '',
      displayName: (data['displayName'] as String?)?.trim() ?? '',
      mood: mood,
      category: rawCategory.isNotEmpty
          ? rawCategory
          : MoodConfig.categoryFor(mood),
      emoji: rawEmoji.isNotEmpty ? rawEmoji : MoodConfig.emojiFor(mood),
      note: (data['note'] as String?)?.trim() ?? '',
      createdAt: parsedCreatedAt,
      pairId: (data['pairId'] as String?)?.trim() ?? '',
    );
  }

  /// Resolves the author name for display, falling back to "You" or "Partner".
  String resolvedAuthorName({required String? currentUid}) {
    if (displayName.isNotEmpty) return displayName;
    if (currentUid != null && uid == currentUid) return 'You';
    return 'Partner';
  }

  /// Formats the subtitle line shown on the history card, e.g. `Happy, Rayhan`.
  String subtitle({required String? currentUid}) {
    final author = resolvedAuthorName(currentUid: currentUid);
    if (mood.isEmpty) return author;
    return '$mood, $author';
  }

  /// Returns `true` if this entry belongs to [currentUid].
  bool isOwnedBy(String? currentUid) {
    return currentUid != null && currentUid.isNotEmpty && uid == currentUid;
  }

  /// Formats the local time as `h:mm AM/PM` (e.g. `4:21 PM`, `9:15 AM`).
  String formattedTime() {
    final dt = createdAt?.toLocal();
    if (dt == null) return 'Just now';
    return formatLocalTime(dt);
  }

  /// Formats the full local date and time for the detail sheet.
  String formattedFullDateTime() {
    final dt = createdAt?.toLocal();
    if (dt == null) return 'Just now';
    return formatLocalFullDateTime(dt);
  }

  static String formatLocalTime(DateTime dateTime) {
    final local = dateTime.toLocal();
    final hour24 = local.hour;
    final period = hour24 >= 12 ? 'PM' : 'AM';
    final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    return '$hour12:$minute $period';
  }

  static String formatLocalFullDateTime(DateTime dateTime) {
    final local = dateTime.toLocal();
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final weekday = weekdays[local.weekday - 1];
    final month = months[local.month - 1];
    final time = formatLocalTime(local);
    return '$weekday, ${local.day} $month ${local.year} • $time';
  }
}
