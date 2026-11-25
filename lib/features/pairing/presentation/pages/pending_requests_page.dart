import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../data/pairing_service.dart';
import '../../providers/pairing_providers.dart';

class PendingRequestsPage extends ConsumerStatefulWidget {
  const PendingRequestsPage({super.key});

  @override
  ConsumerState<PendingRequestsPage> createState() =>
      _PendingRequestsPageState();
}

class _PendingRequestsPageState extends ConsumerState<PendingRequestsPage> {
  final Set<String> _processingIds = <String>{};

  String _formatRequestTime(Timestamp? ts) {
    if (ts == null) return 'Just now';
    final local = ts.toDate().toLocal();
    final diff = DateTime.now().difference(local);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${local.day}/${local.month}/${local.year}';
  }

  Future<void> _respond(String requestId, bool accept) async {
    if (_processingIds.contains(requestId)) return;
    setState(() => _processingIds.add(requestId));

    try {
      final service = ref.read(pairingServiceProvider);
      if (accept) {
        await service.acceptRequest(requestId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Connected! Your private space is ready.'),
              backgroundColor: AppColors.success,
            ),
          );
          context.go(AppRoutes.home);
        }
      } else {
        await service.rejectRequest(requestId);
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Request declined.')));
        }
      }
    } on PairingException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.message),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } on FirebaseException catch (error) {
      if (mounted) {
        final msg = error.code == 'permission-denied'
            ? 'Permission denied while updating this request. Please check Firestore rules.'
            : 'Could not complete action (${error.code}). Please try again.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: AppColors.error),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Action could not be completed. Please try again.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _processingIds.remove(requestId));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final requests = ref.watch(pendingIncomingRequestsProvider);
    final pendingCount = requests.valueOrNull?.length ?? 0;

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        leading: IconButton(
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(AppRoutes.pairing);
            }
          },
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Connection Requests', style: AppTextStyles.h3),
            if (pendingCount > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.dustyRose.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$pendingCount',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.dustyRose,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
        centerTitle: true,
      ),
      body: requests.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.dustyRose),
        ),
        error: (error, _) {
          final isPermissionDenied =
              error is FirebaseException && error.code == 'permission-denied';
          final isMissingIndex =
              error is FirebaseException && error.code == 'failed-precondition';

          final title = isPermissionDenied
              ? 'Access denied'
              : isMissingIndex
              ? 'Database index required'
              : 'Unable to load requests';
          final message = isPermissionDenied
              ? 'Your account does not have permission to read connection requests. Please ensure Firestore rules are published.'
              : isMissingIndex
              ? 'A Firestore index is required for this query. Please deploy firestore.indexes.json.'
              : 'Please check your internet connection and try again.';

          return _StateMessage(
            icon: isPermissionDenied
                ? Icons.lock_outline_rounded
                : Icons.cloud_off_outlined,
            title: title,
            message: message,
            onRetry: () => ref.invalidate(incomingRequestsProvider),
          );
        },
        data: (docs) {
          if (docs.isEmpty) {
            return const _StateMessage(
              icon: Icons.inbox_outlined,
              title: 'No pending requests',
              message:
                  'When your partner searches your username and connects, their invitation will appear here.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            itemCount: docs.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data();
              final name =
                  (data['fromDisplayName'] as String?)?.trim().isNotEmpty ==
                      true
                  ? (data['fromDisplayName'] as String).trim()
                  : 'Rayna user';
              final username = (data['fromUsername'] as String?)?.trim() ?? '';
              final timeLabel = _formatRequestTime(
                data['createdAt'] as Timestamp?,
              );
              final isBusy = _processingIds.contains(doc.id);

              return Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: const BorderSide(color: AppColors.divider),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: AppColors.dustyRose.withValues(
                          alpha: 0.15,
                        ),
                        child: Text(
                          name.isNotEmpty ? name[0].toUpperCase() : '?',
                          style: AppTextStyles.labelLarge.copyWith(
                            color: AppColors.dustyRose,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: AppTextStyles.labelLarge,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              username.isNotEmpty
                                  ? '@$username • $timeLabel'
                                  : timeLabel,
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.textSecondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      if (isBusy)
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.dustyRose,
                            ),
                          ),
                        )
                      else ...[
                        IconButton(
                          tooltip: 'Decline',
                          onPressed: () => _respond(doc.id, false),
                          icon: const Icon(
                            Icons.close_rounded,
                            color: AppColors.error,
                          ),
                          style: IconButton.styleFrom(
                            backgroundColor: AppColors.error.withValues(
                              alpha: 0.1,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          tooltip: 'Accept',
                          onPressed: () => _respond(doc.id, true),
                          icon: const Icon(
                            Icons.favorite_rounded,
                            color: AppColors.white,
                          ),
                          style: IconButton.styleFrom(
                            backgroundColor: AppColors.dustyRose,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _StateMessage extends StatelessWidget {
  const _StateMessage({
    required this.icon,
    required this.title,
    required this.message,
    this.onRetry,
  });

  final IconData icon;
  final String title;
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 56,
            color: AppColors.dustyRose.withValues(alpha: 0.6),
          ),
          const SizedBox(height: 16),
          Text(title, style: AppTextStyles.h3, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(
            message,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 18),
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
        ],
      ),
    ),
  );
}
