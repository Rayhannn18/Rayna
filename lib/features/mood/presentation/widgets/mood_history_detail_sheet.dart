import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../data/mood_config.dart';
import '../../data/mood_history_model.dart';

/// Shows a clean bottom sheet containing full details of a Mood History entry.
Future<void> showMoodHistoryDetailSheet({
  required BuildContext context,
  required MoodHistoryEntry entry,
  required String? currentUid,
  required VoidCallback onRequestDelete,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.white,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => MoodHistoryDetailSheet(
      entry: entry,
      currentUid: currentUid,
      onDelete: () {
        Navigator.of(ctx).pop();
        onRequestDelete();
      },
    ),
  );
}

class MoodHistoryDetailSheet extends StatelessWidget {
  const MoodHistoryDetailSheet({
    super.key,
    required this.entry,
    required this.currentUid,
    required this.onDelete,
  });

  final MoodHistoryEntry entry;
  final String? currentUid;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final isOwn = entry.isOwnedBy(currentUid);
    final author = entry.resolvedAuthorName(currentUid: currentUid);
    final circleColor = MoodConfig.circleColorFor(entry.mood);
    final badgeBg = MoodConfig.categoryBadgeColor(entry.category);
    final badgeText = MoodConfig.categoryTextColor(entry.category);

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Header with emoji, mood, and category badge
            Row(
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: circleColor,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    entry.emoji,
                    style: const TextStyle(fontSize: 30, height: 1.1),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              entry.mood.isNotEmpty ? entry.mood : 'Mood',
                              style: AppTextStyles.h3.copyWith(
                                fontSize: 19,
                                fontWeight: FontWeight.w700,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: badgeBg,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              entry.category,
                              style: AppTextStyles.labelSmall.copyWith(
                                fontSize: 11.5,
                                color: badgeText,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            author,
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (isOwn) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.dustyRose.withValues(
                                  alpha: 0.14,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'You',
                                style: AppTextStyles.caption.copyWith(
                                  color: AppColors.dustyRose,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Full local date and time
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                color: AppColors.softIvory,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.divider),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.schedule_rounded,
                    size: 18,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      entry.formattedFullDateTime(),
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontSize: 13.5,
                        color: AppColors.charcoal,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Optional note
            if (entry.note.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                'Note',
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.softIvory,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Text(
                  entry.note,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.charcoal,
                    height: 1.5,
                  ),
                ),
              ),
            ],

            const SizedBox(height: 20),

            // Actions
            if (isOwn) ...[
              OutlinedButton.icon(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                label: const Text('Delete History Entry'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: BorderSide(
                    color: AppColors.error.withValues(alpha: 0.45),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }
}
