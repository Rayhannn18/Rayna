import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../data/mood_config.dart';
import '../../data/mood_history_model.dart';

enum _CardMenuAction { viewDetails, delete }

/// Compact, minimalist Mood History card modeled after the reference layout:
/// circular mood emoji on the left, category + "Mood, User" in the center,
/// and 3-dot options + local timestamp on the right.
class MoodHistoryCard extends StatelessWidget {
  const MoodHistoryCard({
    super.key,
    required this.entry,
    required this.currentUid,
    required this.onTap,
    required this.onDelete,
  });

  final MoodHistoryEntry entry;
  final String? currentUid;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final isOwn = entry.isOwnedBy(currentUid);
    final circleColor = MoodConfig.circleColorFor(entry.mood);

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 8),
            child: child,
          ),
        );
      },
      child: Material(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          splashColor: AppColors.dustyRose.withValues(alpha: 0.08),
          highlightColor: AppColors.warmGray.withValues(alpha: 0.25),
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: AppColors.divider.withValues(alpha: 0.85),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.charcoal.withValues(alpha: 0.035),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // ── A. Circular Mood Emoji ──────────────────────────────
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: circleColor,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    entry.emoji,
                    style: const TextStyle(fontSize: 24, height: 1.1),
                  ),
                ),
                const SizedBox(width: 14),

                // ── B & C. Category, "Mood, User", and optional note ────
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        entry.category,
                        style: AppTextStyles.labelLarge.copyWith(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.charcoal,
                          height: 1.25,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        entry.subtitle(currentUid: currentUid),
                        style: AppTextStyles.bodyMedium.copyWith(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary,
                          height: 1.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (entry.note.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          entry.note,
                          style: AppTextStyles.bodySmall.copyWith(
                            fontSize: 12,
                            color: AppColors.textHint,
                            height: 1.3,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 6),

                // ── D & E. More Options (top-right) & Local Time ────────
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PopupMenuButton<_CardMenuAction>(
                      tooltip: 'More options',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 148),
                      iconSize: 19,
                      icon: const Icon(
                        Icons.more_vert_rounded,
                        color: AppColors.textSecondary,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      color: AppColors.white,
                      elevation: 3,
                      onSelected: (action) {
                        switch (action) {
                          case _CardMenuAction.viewDetails:
                            onTap();
                          case _CardMenuAction.delete:
                            if (isOwn) onDelete();
                        }
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem<_CardMenuAction>(
                          value: _CardMenuAction.viewDetails,
                          child: Row(
                            children: [
                              const Icon(
                                Icons.info_outline_rounded,
                                size: 18,
                                color: AppColors.charcoal,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'View Details',
                                style: AppTextStyles.bodyMedium.copyWith(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isOwn)
                          PopupMenuItem<_CardMenuAction>(
                            value: _CardMenuAction.delete,
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.delete_outline_rounded,
                                  size: 18,
                                  color: AppColors.error,
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  'Delete',
                                  style: AppTextStyles.bodyMedium.copyWith(
                                    color: AppColors.error,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Text(
                        entry.formattedTime(),
                        style: AppTextStyles.caption.copyWith(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
