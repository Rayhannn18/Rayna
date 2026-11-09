import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../data/pairing_service.dart';
import '../../providers/pairing_providers.dart';

class PendingRequestsPage extends ConsumerWidget {
  const PendingRequestsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requests = ref.watch(incomingRequestsProvider);

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        leading: IconButton(
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              context.go(AppRoutes.pairing);
            }
          },
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: Text('Connection Requests', style: AppTextStyles.h3),
        centerTitle: true,
      ),
      body: requests.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.dustyRose),
        ),
        error: (error, _) => _StateMessage(
          icon: Icons.cloud_off_outlined,
          title: 'Unable to load requests',
          message: 'Please check your connection and try again.',
        ),
        data: (snapshot) {
          if (snapshot.docs.isEmpty) {
            return const _StateMessage(
              icon: Icons.inbox_outlined,
              title: 'No pending requests',
              message:
                  'When your partner searches your username and connects, their invitation will appear here.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            itemCount: snapshot.docs.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final doc = snapshot.docs[index];
              final data = doc.data();
              final name = data['fromDisplayName'] as String? ?? 'Rayna user';
              final username = data['fromUsername'] as String? ?? '';

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
                            Text(name, style: AppTextStyles.labelLarge),
                            const SizedBox(height: 2),
                            Text(
                              '@$username',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Decline',
                        onPressed: () => _respond(context, ref, doc.id, false),
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
                        onPressed: () => _respond(context, ref, doc.id, true),
                        icon: const Icon(
                          Icons.favorite_rounded,
                          color: AppColors.white,
                        ),
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.dustyRose,
                        ),
                      ),
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

  Future<void> _respond(
    BuildContext context,
    WidgetRef ref,
    String requestId,
    bool accept,
  ) async {
    try {
      final service = ref.read(pairingServiceProvider);
      if (accept) {
        await service.acceptRequest(requestId);
        if (context.mounted) {
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
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Request declined.')));
        }
      }
    } on PairingException catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.message),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Action could not be completed: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }
}

class _StateMessage extends StatelessWidget {
  const _StateMessage({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

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
        ],
      ),
    ),
  );
}
