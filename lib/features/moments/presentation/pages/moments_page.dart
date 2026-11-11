import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../pairing/providers/pairing_providers.dart';
import '../../providers/moments_providers.dart';

class MomentsPage extends ConsumerStatefulWidget {
  const MomentsPage({super.key});

  @override
  ConsumerState<MomentsPage> createState() => _MomentsPageState();
}

class _MomentsPageState extends ConsumerState<MomentsPage> {
  String _formatTimestamp(Timestamp? ts) {
    if (ts == null) return '';
    final date = ts.toDate();
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${date.day}/${date.month}/${date.year}';
  }

  Future<void> _confirmAndDeleteMoment(
    BuildContext context,
    String pairId,
    String momentId,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Moment?'),
        content: const Text(
          'This photo will be removed from your shared timeline.',
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

    if (confirmed == true && mounted) {
      try {
        await ref
            .read(momentsServiceProvider)
            .deleteMoment(pairId: pairId, momentId: momentId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Moment deleted successfully'),
              backgroundColor: AppColors.dustyRose,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  Widget _buildMomentImage(String url, {BoxFit fit = BoxFit.cover}) {
    if (url.startsWith('data:image')) {
      try {
        final commaIndex = url.indexOf(',');
        final base64Str =
            commaIndex != -1 ? url.substring(commaIndex + 1) : url;
        final bytes = base64Decode(base64Str);
        return Image.memory(
          bytes,
          fit: fit,
          errorBuilder: (context, error, stackTrace) => const SizedBox(
            height: 180,
            child: Center(
              child: Icon(Icons.broken_image_rounded,
                  color: AppColors.textSecondary),
            ),
          ),
        );
      } catch (_) {
        return const SizedBox(
          height: 180,
          child: Center(
            child: Icon(Icons.broken_image_rounded,
                color: AppColors.textSecondary),
          ),
        );
      }
    }

    return Image.network(
      url,
      fit: fit,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return const SizedBox(
          height: 220,
          child: Center(
            child: CircularProgressIndicator(color: AppColors.dustyRose),
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) => const SizedBox(
        height: 180,
        child: Center(
          child:
              Icon(Icons.broken_image_rounded, color: AppColors.textSecondary),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userDoc = ref.watch(currentUserDocumentProvider);
    final currentUid = ref.read(momentsServiceProvider).uid;
    final pair = userDoc.valueOrNull?.data()?['activePairId'] as String?;

    if (pair == null || pair.isEmpty) {
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
              final downloadUrl = data['downloadUrl'] as String?;
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
                          PopupMenuButton<String>(
                            icon: const Icon(
                              Icons.more_horiz_rounded,
                              size: 20,
                              color: AppColors.textSecondary,
                            ),
                            onSelected: (value) {
                              if (value == 'view') {
                                context.go('/moments/${doc.id}');
                              } else if (value == 'delete') {
                                _confirmAndDeleteMoment(context, pair, doc.id);
                              }
                            },
                            itemBuilder: (context) => [
                              if (isReady)
                                const PopupMenuItem(
                                  value: 'view',
                                  child: Row(
                                    children: [
                                      Icon(Icons.visibility_outlined, size: 18),
                                      SizedBox(width: 8),
                                      Text('View Details'),
                                    ],
                                  ),
                                ),
                              if (isMe)
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Row(
                                    children: [
                                      Icon(Icons.delete_outline_rounded,
                                          size: 18, color: AppColors.error),
                                      SizedBox(width: 8),
                                      Text('Delete Moment',
                                          style: TextStyle(color: AppColors.error)),
                                    ],
                                  ),
                                ),
                            ],
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
                            ? (downloadUrl != null && downloadUrl.isNotEmpty
                                ? _buildMomentImage(downloadUrl)
                                : FutureBuilder<String>(
                                    future: ref
                                        .read(momentsServiceProvider)
                                        .downloadUrl(
                                            data['storagePath'] as String),
                                    builder: (context, image) {
                                      if (image.connectionState ==
                                          ConnectionState.waiting) {
                                        return const Center(
                                          child: SizedBox(
                                            height: 220,
                                            child: Center(
                                              child:
                                                  CircularProgressIndicator(
                                                color: AppColors.dustyRose,
                                              ),
                                            ),
                                          ),
                                        );
                                      }
                                      if (image.hasData) {
                                        return _buildMomentImage(image.data!);
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
                                  ))
                            : Container(
                                height: 180,
                                padding: const EdgeInsets.all(16),
                                color: AppColors.warmGray.withValues(
                                  alpha: 0.35,
                                ),
                                child: Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(
                                        Icons.cloud_off_rounded,
                                        color: AppColors.error,
                                        size: 34,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Upload incomplete or failed',
                                        style: AppTextStyles.bodySmall.copyWith(
                                          color: AppColors.charcoal,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      if (isMe)
                                        OutlinedButton.icon(
                                          onPressed: () =>
                                              _confirmAndDeleteMoment(
                                                  context, pair, doc.id),
                                          icon: const Icon(
                                              Icons.delete_outline_rounded,
                                              size: 16),
                                          label: const Text('Delete'),
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: AppColors.error,
                                            side: const BorderSide(
                                                color: AppColors.error),
                                            visualDensity:
                                                VisualDensity.compact,
                                          ),
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
