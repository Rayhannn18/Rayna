import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../mood/providers/mood_providers.dart';
import '../../../pairing/providers/pairing_providers.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userDoc = ref.watch(currentUserDocumentProvider);
    final data = userDoc.valueOrNull?.data() ?? {};
    final paired = (data['activePairId'] as String?)?.isNotEmpty == true;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(
          'Rayna',
          style: AppTextStyles.h3.copyWith(color: AppColors.dustyRose),
        ),
        actions: [
          if (paired)
            IconButton(
              onPressed: () => context.go(AppRoutes.chat),
              icon: const Icon(Icons.chat_bubble_outline_rounded),
              tooltip: 'Chat with Partner',
            ),
          IconButton(
            onPressed: () => context.go(AppRoutes.profile),
            icon: const Icon(Icons.person_outline_rounded),
            tooltip: 'Profile',
          ),
        ],
      ),
      body: _buildBody(context, ref),
    );
  }

  Widget _buildBody(BuildContext context, WidgetRef ref) {
    final document = ref.watch(currentUserDocumentProvider);

    return document.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppColors.dustyRose),
      ),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Unable to load account: $e',
            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.error),
            textAlign: TextAlign.center,
          ),
        ),
      ),
      data: (snapshot) {
        final data = snapshot.data() ?? <String, dynamic>{};
        final name = data['displayName'] as String? ?? 'there';
        final pairId = data['activePairId'] as String?;
        final paired = pairId != null && pairId.isNotEmpty;

        return ListView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 110),
          children: [
            Text(
              paired ? 'Welcome back, $name' : 'Hi, $name',
              style: AppTextStyles.h2,
            ),
            const SizedBox(height: 6),
            Text(
              paired
                  ? 'Your private couple space is connected.'
                  : 'Connect with your partner to start sharing moments.',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 24),

            // ── Connection Status / Partner Card ───────────────────────────
            if (!paired)
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22),
                  side: const BorderSide(color: AppColors.divider),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(18),
                  leading: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.dustyRose.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.favorite_outline_rounded,
                      color: AppColors.dustyRose,
                    ),
                  ),
                  title: Text(
                    'Connect with Partner',
                    style: AppTextStyles.labelLarge,
                  ),
                  subtitle: Text(
                    'Use a quick pairing code or search their username.',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  trailing: const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.textSecondary,
                  ),
                  onTap: () => context.go(AppRoutes.pairing),
                ),
              )
            else ...[
              // ── Partner Moods Live Widget ────────────────────────────────
              _CoupleMoodCard(pairId: pairId),
              const SizedBox(height: 24),
            ],

            // ── Quick Access Actions ───────────────────────────────────────
            Text(
              'Quick Actions',
              style: AppTextStyles.labelLarge.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),

            if (paired) ...[
              _ActionCard(
                icon: Icons.chat_bubble_outline_rounded,
                title: 'Couple Chat',
                subtitle: 'Send a private sweet message to your partner',
                onTap: () => context.go(AppRoutes.chat),
              ),
              const SizedBox(height: 12),
            ],

            _ActionCard(
              icon: Icons.camera_alt_outlined,
              title: 'Share a photo',
              subtitle: 'Capture and share a daily moment',
              onTap: () => context.go(AppRoutes.sendPhoto),
            ),
            const SizedBox(height: 12),
            _ActionCard(
              icon: Icons.photo_library_outlined,
              title: 'Moments Timeline',
              subtitle: 'View your shared photos and memories',
              onTap: () => context.go(AppRoutes.moments),
            ),
            const SizedBox(height: 12),
            _ActionCard(
              icon: Icons.favorite_outline_rounded,
              title: 'Mood Check-in',
              subtitle: 'Update how you are feeling right now',
              onTap: () => context.go(AppRoutes.mood),
            ),
          ],
        );
      },
    );
  }
}

class _CoupleMoodCard extends ConsumerWidget {
  const _CoupleMoodCard({required this.pairId});

  final String pairId;

  String _getEmoji(String mood) {
    switch (mood.toLowerCase()) {
      case 'happy':
        return '😊';
      case 'love':
        return '🥰';
      case 'calm':
        return '😌';
      case 'excited':
        return '✨';
      case 'missing you':
        return '🥺';
      case 'tired':
        return '🥱';
      case 'sad':
        return '😢';
      case 'stressed':
        return '😮‍💨';
      default:
        return '💖';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final moodsAsync = ref.watch(pairMoodsStreamProvider(pairId));
    final myUid = FirebaseAuth.instance.currentUser?.uid;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: const BorderSide(color: AppColors.divider),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.favorite_rounded,
                      color: AppColors.dustyRose,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text('Today\'s Emotions', style: AppTextStyles.labelLarge),
                  ],
                ),
                TextButton(
                  onPressed: () => context.go(AppRoutes.mood),
                  child: Text(
                    'Check In',
                    style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.dustyRose,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            moodsAsync.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.dustyRose,
                  ),
                ),
              ),
              error: (_, _) => Text(
                'Unable to load moods.',
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.error),
              ),
              data: (snapshot) {
                final docs = snapshot.docs;
                if (docs.isEmpty) {
                  return Text(
                    'No mood shared today yet. Tap Check In to let your partner know how you feel.',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  );
                }

                Map<String, dynamic>? myMood;
                Map<String, dynamic>? partnerMood;

                for (final doc in docs) {
                  final data = doc.data();
                  if (data['uid'] == myUid) {
                    myMood = data;
                  } else {
                    partnerMood = data;
                  }
                }

                return Row(
                  children: [
                    Expanded(
                      child: _MoodBubble(
                        title: 'You',
                        mood: myMood?['mood'] as String?,
                        note: myMood?['note'] as String?,
                        emoji: _getEmoji(myMood?['mood'] as String? ?? ''),
                        isPartner: false,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _MoodBubble(
                        title:
                            partnerMood?['displayName'] as String? ?? 'Partner',
                        mood: partnerMood?['mood'] as String?,
                        note: partnerMood?['note'] as String?,
                        emoji: _getEmoji(partnerMood?['mood'] as String? ?? ''),
                        isPartner: true,
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _MoodBubble extends StatelessWidget {
  const _MoodBubble({
    required this.title,
    required this.mood,
    required this.note,
    required this.emoji,
    required this.isPartner,
  });

  final String title;
  final String? mood;
  final String? note;
  final String emoji;
  final bool isPartner;

  @override
  Widget build(BuildContext context) {
    final hasMood = mood != null && mood!.isNotEmpty;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isPartner
            ? AppColors.softSage.withValues(alpha: 0.35)
            : AppColors.warmGray.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.textSecondary,
              fontSize: 11,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          if (hasMood) ...[
            Row(
              children: [
                Text(emoji, style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    mood!,
                    style: AppTextStyles.labelLarge.copyWith(
                      color: AppColors.charcoal,
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            if (note != null && note!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                note!,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ] else ...[
            Text(
              'Not shared yet',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.divider),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.warmGray.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: AppColors.dustyRose, size: 22),
        ),
        title: Text(title, style: AppTextStyles.labelLarge),
        subtitle: Text(
          subtitle,
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        trailing: const Icon(
          Icons.chevron_right_rounded,
          color: AppColors.textSecondary,
        ),
        onTap: onTap,
      ),
    );
  }
}
