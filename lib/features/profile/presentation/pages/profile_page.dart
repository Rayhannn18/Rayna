import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../features/auth/providers/auth_providers.dart';
import '../../../../core/notifications/notification_providers.dart';
import '../../../pairing/data/pairing_service.dart';
import '../../../pairing/providers/pairing_providers.dart';
import '../../../../shared/widgets/user_avatar.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = FirebaseAuth.instance.currentUser;
    final data =
        ref.watch(currentUserDocumentProvider).valueOrNull?.data() ??
        <String, dynamic>{};
    final paired = (data['activePairId'] as String?)?.isNotEmpty == true;
    final displayName =
        data['displayName'] as String? ?? user?.displayName ?? 'Rayna user';
    final username = data['username'] as String? ?? '';
    final bio = data['bio'] as String? ?? '';

    return PopScope(
      canPop: context.canPop(),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          context.go(AppRoutes.home);
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        leading: IconButton(
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(AppRoutes.home);
            }
          },
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Back',
        ),
        title: Text('My Profile', style: AppTextStyles.h3),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: () => context.push(AppRoutes.editProfile),
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit Profile',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        children: [
          // ── User Header ─────────────────────────────────────────────────
          Center(
            child: GestureDetector(
              onTap: () => context.push(AppRoutes.editProfile),
              child: UserAvatar(
                photoUrl: data['photoURL'] as String? ?? user?.photoURL,
                name: displayName,
                radius: 46,
                borderWidth: 2.5,
                borderColor: AppColors.dustyRose.withValues(alpha: 0.35),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Center(
            child: Text(
              displayName,
              style: AppTextStyles.h2.copyWith(fontSize: 22),
            ),
          ),
          if (username.isNotEmpty) ...[
            const SizedBox(height: 2),
            Center(
              child: Text(
                '@$username',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.dustyRose,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          if (bio.isNotEmpty) ...[
            const SizedBox(height: 10),
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  bio,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),

          // ── Quick Edit Action Button ────────────────────────────────────
          OutlinedButton.icon(
            onPressed: () => context.push(AppRoutes.editProfile),
            icon: const Icon(Icons.edit_note_rounded, size: 20),
            label: const Text('Edit Profile & Bio'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              side: const BorderSide(color: AppColors.divider),
            ),
          ),
          const SizedBox(height: 24),

          // ── Information & Settings Card ─────────────────────────────────
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(color: AppColors.divider),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(
                    Icons.email_outlined,
                    color: AppColors.dustyRose,
                  ),
                  title: const Text('Email Address'),
                  subtitle: Text(user?.email ?? 'Unavailable'),
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: Icon(
                    paired
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    color: paired
                        ? AppColors.dustyRose
                        : AppColors.textSecondary,
                  ),
                  title: const Text('Couple Space Status'),
                  subtitle: Text(
                    paired ? 'Connected with partner' : 'Not yet connected',
                  ),
                  trailing: !paired
                      ? TextButton(
                          onPressed: () => context.push(AppRoutes.pairing),
                          child: const Text('Find Partner'),
                        )
                      : null,
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: const Icon(
                    Icons.notifications_outlined,
                    color: AppColors.dustyRose,
                  ),
                  title: const Text('Notification Settings'),
                  trailing: const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.textSecondary,
                  ),
                  onTap: () => context.push(AppRoutes.notificationSettings),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Danger / Disconnect Zone ────────────────────────────────────
          if (paired) ...[
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: BorderSide(color: AppColors.error.withValues(alpha: 0.3)),
              ),
              child: ListTile(
                leading: const Icon(
                  Icons.link_off_rounded,
                  color: AppColors.error,
                ),
                title: const Text(
                  'Disconnect from Partner',
                  style: TextStyle(color: AppColors.error),
                ),
                subtitle: const Text('Leave current couple space'),
                onTap: () => _leave(context, ref),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // ── Sign Out Button ─────────────────────────────────────────────
          ElevatedButton.icon(
            onPressed: () async {
              final shouldLogout = await showDialog<bool>(
                context: context,
                builder: (c) => AlertDialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  title: const Text('Sign Out'),
                  content: const Text(
                    'Are you sure you want to sign out from Rayna?',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(c, false),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(c, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.dustyRose,
                      ),
                      child: const Text('Sign Out'),
                    ),
                  ],
                ),
              );

              if (shouldLogout == true && context.mounted) {
                await ref.read(notificationServiceProvider).unregisterDevice();
                await ref.read(authServiceProvider).signOut();
                if (context.mounted) context.go(AppRoutes.onboarding);
              }
            },
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Sign Out'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.warmGray.withValues(alpha: 0.4),
              foregroundColor: AppColors.charcoal,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    ),
  );
}

  Future<void> _leave(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Leave Partner?'),
        content: const Text(
          'This disconnects your shared private space. Shared moments and history will no longer be accessible together.',
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
              foregroundColor: AppColors.white,
            ),
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;
    try {
      await ref.read(pairingServiceProvider).leavePair();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Disconnected from partner space.'),
            backgroundColor: AppColors.info,
          ),
        );
      }
    } on PairingException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: AppColors.error),
        );
      }
    }
  }
}
