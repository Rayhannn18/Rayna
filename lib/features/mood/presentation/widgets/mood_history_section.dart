import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../auth/providers/auth_providers.dart';
import '../../data/mood_history_model.dart';
import '../../data/mood_service.dart';
import '../../providers/mood_providers.dart';
import 'mood_history_card.dart';
import 'mood_history_detail_sheet.dart';
import 'mood_history_filter.dart';

/// Real-time Mood History section embedded inside [MoodPage].
///
/// Handles paired/unpaired state, filtering (All / My Mood / Partner),
/// offline cache indication, loading skeleton, empty state, error recovery,
/// detail sheet, owner-only deletion, and incremental pagination.
class MoodHistorySection extends ConsumerWidget {
  const MoodHistorySection({
    super.key,
    required this.pairId,
    required this.isUserDocLoading,
  });

  final String? pairId;
  final bool isUserDocLoading;

  Future<void> _confirmAndDelete({
    required BuildContext context,
    required WidgetRef ref,
    required String pairId,
    required MoodHistoryEntry entry,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete Mood Entry?', style: AppTextStyles.h3),
        content: Text(
          'This will remove this check-in from your history. Your current mood will stay intact.',
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      await ref
          .read(moodServiceProvider)
          .deleteHistoryEntry(pairId: pairId, historyId: entry.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Mood history entry deleted.'),
            backgroundColor: AppColors.dustyRose,
          ),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not delete this mood entry. Please try again.',
            ),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activePairId = pairId?.trim();
    final hasPair = activePairId != null && activePairId.isNotEmpty;
    final selectedFilter = ref.watch(moodHistoryFilterProvider);
    final currentUid = ref.watch(authStateProvider).valueOrNull?.uid;

    if (isUserDocLoading && !hasPair) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(count: null),
          const SizedBox(height: 14),
          const _MoodHistorySkeleton(),
        ],
      );
    }

    if (!hasPair) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(count: 0),
          const SizedBox(height: 14),
          const _UnpairedHistoryCard(),
        ],
      );
    }

    final filteredAsync = ref.watch(filteredMoodHistoryProvider(activePairId));
    final allAsync = ref.watch(moodHistoryEntriesProvider(activePairId));
    final isFromCache = ref.watch(moodHistoryIsFromCacheProvider(activePairId));
    final currentLimit = ref.watch(moodHistoryLimitProvider(activePairId));

    final displayedCount = filteredAsync.valueOrNull?.length;
    final totalFetchedCount = allAsync.valueOrNull?.length ?? 0;
    final canLoadMore = totalFetchedCount >= currentLimit;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(count: displayedCount),
        const SizedBox(height: 12),

        // Filter bar: All | My Mood | Partner
        MoodHistoryFilterBar(
          selected: selectedFilter,
          onChanged: (next) {
            ref.read(moodHistoryFilterProvider.notifier).state = next;
          },
        ),

        // Subtle offline cache banner when serving cached Firestore data
        if (isFromCache) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.warmGray.withValues(alpha: 0.65),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.cloud_off_rounded,
                  size: 15,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Offline — showing cached mood history. Data may not be up to date.',
                    style: AppTextStyles.bodySmall.copyWith(
                      fontSize: 11.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 14),

        filteredAsync.when(
          loading: () => const _MoodHistorySkeleton(),
          error: (_, _) => _MoodHistoryErrorCard(
            onRetry: () =>
                ref.invalidate(moodHistorySnapshotProvider(activePairId)),
          ),
          data: (entries) {
            if (entries.isEmpty) {
              return _MoodHistoryEmptyState(filter: selectedFilter);
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: entries.length,
                  itemBuilder: (context, index) {
                    final entry = entries[index];
                    return Padding(
                      padding: EdgeInsets.only(
                        bottom: index == entries.length - 1 ? 0 : 10,
                      ),
                      child: MoodHistoryCard(
                        key: ValueKey(entry.id),
                        entry: entry,
                        currentUid: currentUid,
                        onTap: () => showMoodHistoryDetailSheet(
                          context: context,
                          entry: entry,
                          currentUid: currentUid,
                          onRequestDelete: () => _confirmAndDelete(
                            context: context,
                            ref: ref,
                            pairId: activePairId,
                            entry: entry,
                          ),
                        ),
                        onDelete: () => _confirmAndDelete(
                          context: context,
                          ref: ref,
                          pairId: activePairId,
                          entry: entry,
                        ),
                      ),
                    );
                  },
                ),
                if (canLoadMore) ...[
                  const SizedBox(height: 14),
                  Center(
                    child: OutlinedButton(
                      onPressed: () {
                        ref
                                .read(
                                  moodHistoryLimitProvider(
                                    activePairId,
                                  ).notifier,
                                )
                                .state =
                            currentLimit + MoodService.defaultHistoryLimit;
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.dustyRose,
                        side: BorderSide(
                          color: AppColors.dustyRose.withValues(alpha: 0.45),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text('Load Older History'),
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildHeader({required int? count}) {
    return Row(
      children: [
        Text(
          'Mood History',
          style: AppTextStyles.h3.copyWith(
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (count != null) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.dustyRose.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$count',
              style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.dustyRose,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _MoodHistoryEmptyState extends StatelessWidget {
  const _MoodHistoryEmptyState({required this.filter});

  final MoodHistoryFilter filter;

  @override
  Widget build(BuildContext context) {
    final subtitle = switch (filter) {
      MoodHistoryFilter.all => 'Your mood check-ins will appear here.',
      MoodHistoryFilter.myMood => 'Your own mood check-ins will appear here.',
      MoodHistoryFilter.partner =>
        "Your partner's mood check-ins will appear here.",
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.divider.withValues(alpha: 0.85)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.dustyRose.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.favorite_border_rounded,
              color: AppColors.dustyRose,
              size: 24,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'No mood history yet',
            style: AppTextStyles.labelLarge.copyWith(
              fontSize: 15,
              color: AppColors.charcoal,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _UnpairedHistoryCard extends StatelessWidget {
  const _UnpairedHistoryCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.divider.withValues(alpha: 0.85)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppColors.warmGray.withValues(alpha: 0.7),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.link_rounded,
              color: AppColors.textSecondary,
              size: 22,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Connect with your partner first',
            style: AppTextStyles.labelLarge.copyWith(fontSize: 15),
          ),
          const SizedBox(height: 4),
          Text(
            'Once paired, you and your partner can share and view mood history together.',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _MoodHistoryErrorCard extends StatelessWidget {
  const _MoodHistoryErrorCard({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.25)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_rounded, size: 32, color: AppColors.error),
          const SizedBox(height: 10),
          Text(
            'Unable to load mood history',
            style: AppTextStyles.labelLarge.copyWith(fontSize: 15),
          ),
          const SizedBox(height: 4),
          Text(
            'Please check your connection and try again.',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Try Again'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.dustyRose,
              side: const BorderSide(color: AppColors.dustyRose),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MoodHistorySkeleton extends StatelessWidget {
  const _MoodHistorySkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(3, (index) {
        return Padding(
          padding: EdgeInsets.only(bottom: index == 2 ? 0 : 10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: AppColors.divider.withValues(alpha: 0.7),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.warmGray.withValues(alpha: 0.65),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 72,
                        height: 14,
                        decoration: BoxDecoration(
                          color: AppColors.warmGray.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: 132,
                        height: 12,
                        decoration: BoxDecoration(
                          color: AppColors.warmGray.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 46,
                  height: 11,
                  decoration: BoxDecoration(
                    color: AppColors.warmGray.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}
