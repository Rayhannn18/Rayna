import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../data/moments_service.dart';
import '../../providers/moments_providers.dart';

class MomentsPage extends ConsumerWidget {
  const MomentsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final moments = ref.watch(momentsProvider);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go(AppRoutes.home),
        ),
        title: Text('Moments', style: AppTextStyles.h3),
      ),
      body: moments.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Text(
            'Unable to load moments.\n$error',
            textAlign: TextAlign.center,
          ),
        ),
        data: (snapshot) => snapshot.docs.isEmpty
            ? const _EmptyMoments()
            : ListView.separated(
                padding: const EdgeInsets.all(20),
                itemCount: snapshot.docs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (_, index) =>
                    _MomentCard(data: snapshot.docs[index].data()),
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateMoment(context, ref),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New moment'),
      ),
    );
  }

  Future<void> _showCreateMoment(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    var sharing = false;
    final formKey = GlobalKey<FormState>();
    final created = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Share a moment'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            maxLines: 5,
            maxLength: 500,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'What are you feeling right now?',
            ),
            validator: (value) => value == null || value.trim().isEmpty
                ? 'Write something first.'
                : null,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: sharing
                ? null
                : () async {
                    if (!formKey.currentState!.validate()) return;
                    sharing = true;
                    try {
                      await ref
                          .read(momentsServiceProvider)
                          .createMoment(controller.text);
                      if (dialogContext.mounted) {
                        Navigator.pop(dialogContext, true);
                      }
                    } on MomentsException catch (error) {
                      if (dialogContext.mounted) {
                        ScaffoldMessenger.of(
                          dialogContext,
                        ).showSnackBar(SnackBar(content: Text(error.message)));
                      }
                    } catch (error) {
                      if (dialogContext.mounted) {
                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          SnackBar(content: Text('Share failed: $error')),
                        );
                      }
                    } finally {
                      sharing = false;
                    }
                  },
            child: sharing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Share'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (created == true && context.mounted)
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Moment shared.')));
  }
}

class _EmptyMoments extends StatelessWidget {
  const _EmptyMoments();
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.auto_awesome_rounded,
            size: 52,
            color: AppColors.dustyRose,
          ),
          const SizedBox(height: 20),
          Text('No moments yet', style: AppTextStyles.h3),
          const SizedBox(height: 8),
          Text(
            'Share a small thought and make the distance feel closer.',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    ),
  );
}

class _MomentCard extends StatelessWidget {
  const _MomentCard({required this.data});
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final timestamp = data['createdAt'];
    final createdAt = timestamp is Timestamp ? timestamp.toDate() : null;
    final author = data['authorName'] as String? ?? 'Closer user';
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 17,
                backgroundColor: AppColors.softSage,
                child: Text(author.substring(0, 1).toUpperCase()),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(author, style: AppTextStyles.labelMedium)),
              if (createdAt != null)
                Text(_formatTime(createdAt), style: AppTextStyles.caption),
            ],
          ),
          const SizedBox(height: 14),
          Text(data['text'] as String? ?? '', style: AppTextStyles.bodyLarge),
        ],
      ),
    );
  }

  String _formatTime(DateTime date) {
    final local = date.toLocal();
    return '${local.day}/${local.month} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }
}
