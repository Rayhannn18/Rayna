import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../auth/providers/auth_providers.dart';
import '../../../pairing/providers/pairing_providers.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = FirebaseAuth.instance.currentUser;
    final displayName = user?.displayName?.trim();
    final initials = displayName != null && displayName.isNotEmpty
        ? displayName.substring(0, 1).toUpperCase()
        : '?';
    final userDocument = ref.watch(currentUserDocumentProvider);
    final profileData = userDocument.valueOrNull?.data();
    final partnerUsername = profileData?['partnerUsername'] as String?;
    final isPaired =
        (profileData?['partnerUid'] as String?)?.isNotEmpty == true;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go(AppRoutes.home),
        ),
        title: Text('Profile', style: AppTextStyles.h3),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Center(
            child: CircleAvatar(
              radius: 44,
              backgroundColor: AppColors.softSage,
              child: Text(
                initials,
                style: AppTextStyles.h2.copyWith(color: AppColors.charcoal),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              displayName?.isNotEmpty == true ? displayName! : 'Closer user',
              style: AppTextStyles.h3,
            ),
          ),
          const SizedBox(height: 6),
          Center(
            child: Text(
              user?.email ?? 'No email available',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(height: 32),
          _InfoTile(
            icon: Icons.verified_user_outlined,
            label: 'Account ID',
            value: user?.uid ?? 'Unavailable',
          ),
          const SizedBox(height: 12),
          _InfoTile(
            icon: Icons.email_outlined,
            label: 'Email',
            value: user?.email ?? 'Unavailable',
          ),
          const SizedBox(height: 12),
          _InfoTile(
            icon: Icons.favorite_outline_rounded,
            label: 'Partner',
            value: isPaired ? partnerUsername ?? 'Connected' : 'Not connected',
          ),
          const SizedBox(height: 32),
          if (isPaired)
            OutlinedButton.icon(
              onPressed: () => _confirmLeave(context, ref),
              icon: const Icon(Icons.link_off_rounded),
              label: const Text('Leave partner'),
            ),
          if (isPaired) const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () async {
              await ref.read(authServiceProvider).signOut();
              if (context.mounted) context.go(AppRoutes.onboarding);
            },
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Sign out'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmLeave(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave partner?'),
        content: const Text(
          'This will disconnect both accounts. You can pair again later.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      await ref.read(pairingServiceProvider).leavePair();
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.dustyRose),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTextStyles.caption),
                const SizedBox(height: 4),
                Text(value, style: AppTextStyles.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
