import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../providers/moments_providers.dart';
import '../../../pairing/providers/pairing_providers.dart';

class MomentsPage extends ConsumerWidget {
  const MomentsPage({super.key});

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final dt = timestamp.toDate();
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 1) {
      return 'Just now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    } else {
      return '${dt.day}/${dt.month}/${dt.year}';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserDocumentProvider).valueOrNull?.data();
    final pair = user?['activePairId'] as String?;
    final currentUid = FirebaseAuth.instance.currentUser?.uid;

    if (pair == null || pair.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text('Shared Moments', style: AppTextStyles.h3),
          centerTitle: true,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.favorite_border_rounded,
                  size: 56,
                  color: AppColors.dustyRose.withValues(alpha: 0.6),
                ),
                const SizedBox(height: 16),
                Text('No Partner Connected', style: AppTextStyles.h3),
                const SizedBox(height: 8),
                Text(
                  'Connect with your partner first to start seeing and sharing private moments.',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () => context.go(AppRoutes.pairing),
                  icon: const Icon(Icons.link_rounded),
                  label: const Text('Connect Partner'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.dustyRose,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final stream = ref.read(momentsServiceProvider).stream(pair);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text('Shared Moments', style: AppTextStyles.h3),
        centerTitle: true,
        leading: Navigator.of(context).canPop()
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
        actions: [
          IconButton(
            onPressed: () => context.go(AppRoutes.sendPhoto),
            icon: const Icon(Icons.camera_alt_outlined),
            tooltip: 'Share photo',
          ),
        ],
      ),
      body: StreamBuilder(
        stream: stream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                '${snapshot.error}',
                style: const TextStyle(color: AppColors.error),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.dustyRose),
            );
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.photo_library_outlined,
                      size: 54,
                      color: AppColors.dustyRose.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 16),
                    Text('No moments yet', style: AppTextStyles.h3),
                    const SizedBox(height: 8),
                    Text(
                      'Capture and share your first daily photo with your partner.',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () => context.go(AppRoutes.sendPhoto),
                      icon: const Icon(Icons.add_a_photo_outlined),
                      label: const Text('Share First Photo'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.dustyRose,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 110),
            itemCount: docs.length,
            separatorBuilder: (_, _) => const SizedBox(height: 20),
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data();
              final isReady =
                  data['storagePath'] is String && data['status'] == 'ready';
              final caption = data['caption'] as String? ?? '';
              final senderName = data['senderName'] as String? ?? 'Partner';
              final isMe = data['senderUid'] == currentUid;
              final timeString = _formatTimestamp(
                data['createdAt'] as Timestamp?,
              );

              return Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                  side: const BorderSide(color: AppColors.divider),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Card Header (Sender info & time) ───────────────────
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: AppColors.dustyRose.withValues(
                              alpha: 0.15,
                            ),
                            child: Text(
                              (isMe ? 'You' : senderName)[0].toUpperCase(),
                              style: AppTextStyles.labelSmall.copyWith(
                                color: AppColors.dustyRose,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isMe ? 'You' : senderName,
                                  style: AppTextStyles.labelLarge.copyWith(
                                    fontSize: 13,
                                  ),
                                ),
                                if (timeString.isNotEmpty)
                                  Text(
                                    timeString,
                                    style: AppTextStyles.bodySmall.copyWith(
                                      color: AppColors.textSecondary,
                                      fontSize: 11,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.more_horiz_rounded,
                              size: 20,
                              color: AppColors.textSecondary,
                            ),
                            onPressed: isReady
                                ? () => context.go('/moments/${doc.id}')
                                : null,
                          ),
                        ],
                      ),
                    ),

                    // ── Card Photo ─────────────────────────────────────────
                    GestureDetector(
                      onTap: isReady
                          ? () => context.go('/moments/${doc.id}')
                          : null,
                      child: Container(
                        width: double.infinity,
                        constraints: const BoxConstraints(maxHeight: 380),
                        color: AppColors.warmGray.withValues(alpha: 0.3),
                        child: isReady
                            ? FutureBuilder<String>(
                                future: ref
                                    .read(momentsServiceProvider)
                                    .downloadUrl(data['storagePath'] as String),
                                builder: (context, image) {
                                  if (image.connectionState ==
                                      ConnectionState.waiting) {
                                    return const Center(
                                      child: SizedBox(
                                        height: 220,
                                        child: Center(
                                          child: CircularProgressIndicator(
                                            color: AppColors.dustyRose,
                                          ),
                                        ),
                                      ),
                                    );
                                  }
                                  if (image.hasData) {
                                    return Image.network(
                                      image.data!,
                                      fit: BoxFit.cover,
                                    );
                                  }
                                  return const SizedBox(
                                    height: 180,
                                    child: Center(
                                      child: Icon(
                                        Icons.broken_image_rounded,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  );
                                },
                              )
                            : Container(
                                height: 180,
                                color: AppColors.warmGray.withValues(
                                  alpha: 0.4,
                                ),
                                child: const Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      CircularProgressIndicator(
                                        color: AppColors.dustyRose,
                                      ),
                                      SizedBox(height: 10),
                                      Text(
                                        'Uploading photo securely...',
                                        style: TextStyle(fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                      ),
                    ),

                    // ── Card Caption ───────────────────────────────────────
                    if (caption.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                        child: Text(
                          caption,
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.charcoal,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
