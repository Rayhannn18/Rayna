import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../pairing/providers/pairing_providers.dart';
import '../../providers/moments_providers.dart';

class MomentDetailPage extends ConsumerWidget {
  const MomentDetailPage({super.key, required this.momentId});

  final String momentId;

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final dt = timestamp.toDate();
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else {
      return '${dt.day}/${dt.month}/${dt.year}';
    }
  }

  Future<void> _handleDelete(
    BuildContext context,
    WidgetRef ref,
    String pairId,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Moment?'),
        content: const Text(
          'This will permanently delete this photo and caption from your shared space.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(c, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        await ref
            .read(momentsServiceProvider)
            .deleteMoment(pairId: pairId, momentId: momentId);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Moment deleted.'),
              backgroundColor: AppColors.info,
            ),
          );
          Navigator.of(context).pop();
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Delete failed: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pairId =
        ref
                .watch(currentUserDocumentProvider)
                .valueOrNull
                ?.data()?['activePairId']
            as String?;
    final currentUid = FirebaseAuth.instance.currentUser?.uid;

    if (pairId == null || pairId.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Moment')),
        body: const Center(child: Text('No active pair found.')),
      );
    }

    final momentStream = ref
        .read(momentsServiceProvider)
        .momentStream(pairId: pairId, momentId: momentId);

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: momentStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: AppColors.dustyRose),
            ),
          );
        }

        if (snapshot.hasError || !snapshot.hasData || !snapshot.data!.exists) {
          return Scaffold(
            appBar: AppBar(title: const Text('Moment')),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.broken_image_outlined,
                      size: 56,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(height: 16),
                    Text('Moment unavailable', style: AppTextStyles.h3),
                    const SizedBox(height: 8),
                    const Text('This photo may have been removed.'),
                  ],
                ),
              ),
            ),
          );
        }

        final data = snapshot.data!.data()!;
        final caption = data['caption'] as String? ?? '';
        final senderName = data['senderName'] as String? ?? 'Partner';
        final senderUid = data['senderUid'] as String?;
        final isOwner = senderUid == currentUid;
        final storagePath = data['storagePath'] as String?;
        final timeString = _formatTimestamp(data['createdAt'] as Timestamp?);

        return Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            foregroundColor: Colors.white,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: Text(
              isOwner ? 'Your Moment' : "$senderName's Moment",
              style: AppTextStyles.h3.copyWith(color: Colors.white),
            ),
            actions: [
              if (isOwner)
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    color: Colors.white70,
                  ),
                  tooltip: 'Delete moment',
                  onPressed: () => _handleDelete(context, ref, pairId),
                ),
            ],
          ),
          body: Column(
            children: [
              Expanded(
                child: storagePath != null && storagePath.isNotEmpty
                    ? FutureBuilder<String>(
                        future: ref
                            .read(momentsServiceProvider)
                            .downloadUrl(storagePath),
                        builder: (context, urlSnapshot) {
                          if (urlSnapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                              child: CircularProgressIndicator(
                                color: AppColors.dustyRose,
                              ),
                            );
                          }
                          if (urlSnapshot.hasError || !urlSnapshot.hasData) {
                            return const Center(
                              child: Icon(
                                Icons.broken_image,
                                color: Colors.white54,
                                size: 56,
                              ),
                            );
                          }
                          return InteractiveViewer(
                            minScale: 0.8,
                            maxScale: 4.0,
                            child: Center(
                              child: Image.network(
                                urlSnapshot.data!,
                                fit: BoxFit.contain,
                              ),
                            ),
                          );
                        },
                      )
                    : const Center(
                        child: Icon(Icons.broken_image, color: Colors.white54),
                      ),
              ),

              // ── Caption & Timestamp Footer ──────────────────────────────
              if (caption.isNotEmpty || timeString.isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 20,
                  ),
                  color: Colors.black87,
                  child: SafeArea(
                    top: false,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (caption.isNotEmpty)
                          Text(
                            caption,
                            style: AppTextStyles.bodyLarge.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Text(
                              senderName,
                              style: AppTextStyles.labelSmall.copyWith(
                                color: AppColors.dustyRose,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (timeString.isNotEmpty) ...[
                              const Text(
                                ' · ',
                                style: TextStyle(color: Colors.white54),
                              ),
                              Text(
                                timeString,
                                style: AppTextStyles.labelSmall.copyWith(
                                  color: Colors.white54,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
