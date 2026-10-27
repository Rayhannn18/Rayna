import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../pairing/providers/pairing_providers.dart';

/// Home page shell — the main screen after authentication.
///
/// Contains a bottom navigation bar with four tabs: Home, Moments, Send, Mood.
/// Individual tab contents are placeholders — they will be implemented in
/// later stages.
class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  int _currentIndex = 0;

  final List<_TabItem> _tabs = const [
    _TabItem(icon: Icons.home_rounded, label: 'Home'),
    _TabItem(icon: Icons.photo_library_outlined, label: 'Moments'),
    _TabItem(icon: Icons.camera_alt_rounded, label: 'Send'),
    _TabItem(icon: Icons.emoji_emotions_outlined, label: 'Mood'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ── App Bar ──────────────────────────────────────────────────────
      appBar: AppBar(
        title: Text(
          'Closer',
          style: AppTextStyles.h3.copyWith(color: AppColors.dustyRose),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline_rounded),
            tooltip: 'Profile',
            onPressed: () => context.go(AppRoutes.profile),
          ),
        ],
      ),

      // ── Body ────────────────────────────────────────────────────────
      body: _buildTabContent(_currentIndex),

      // ── Bottom navigation ───────────────────────────────────────────
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.divider, width: 0.5)),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          items: _tabs
              .map(
                (tab) => BottomNavigationBarItem(
                  icon: Icon(tab.icon),
                  label: tab.label,
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  Widget _buildTabContent(int index) {
    switch (index) {
      case 0:
        return _HomeTab();
      case 1:
        return _MomentsTab(onOpen: () => context.go(AppRoutes.moments));
      case 2:
        return _QuickTab(
          title: 'Send',
          icon: Icons.send_rounded,
          onOpen: () => context.go(AppRoutes.messages),
        );
      case 3:
        return _QuickTab(
          title: 'Mood',
          icon: Icons.emoji_emotions_outlined,
          onOpen: () => context.go(AppRoutes.mood),
        );
      default:
        return _HomeTab();
    }
  }
}

// ── Home tab ────────────────────────────────────────────────────────────
class _HomeTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userDocument = ref.watch(currentUserDocumentProvider);

    return userDocument.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _HomeStatus(
        title: 'Could not load your profile',
        message: 'Check your connection and try again.',
        action: TextButton(
          onPressed: () => ref.invalidate(currentUserDocumentProvider),
          child: const Text('Retry'),
        ),
      ),
      data: (snapshot) {
        final data = snapshot.data() ?? <String, dynamic>{};
        final partnerUsername = data['partnerUsername'] as String?;
        final displayName = data['displayName'] as String?;
        final isPaired = (data['partnerUid'] as String?)?.isNotEmpty == true;

        return _HomeStatus(
          title: isPaired
              ? 'Connected with ${partnerUsername ?? 'your partner'}'
              : 'Hi ${displayName ?? 'there'}',
          message: isPaired
              ? 'Your private space is ready. Start sharing moments together.'
              : 'Connect with your partner to start sharing moments together.',
          icon: isPaired
              ? Icons.favorite_rounded
              : Icons.favorite_border_rounded,
          action: isPaired
              ? null
              : ElevatedButton(
                  onPressed: () => context.go(AppRoutes.pairing),
                  child: const Text('Find Partner'),
                ),
        );
      },
    );
  }
}

class _HomeStatus extends StatelessWidget {
  const _HomeStatus({
    required this.title,
    required this.message,
    this.icon = Icons.favorite_border_rounded,
    this.action,
  });

  final String title;
  final String message;
  final IconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: AppColors.warmGray.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 40, color: AppColors.dustyRose),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: AppTextStyles.h3.copyWith(color: AppColors.textPrimary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            if (action != null) ...[
              const SizedBox(height: 32),
              SizedBox(width: 200, child: action),
            ],
          ],
        ),
      ),
    );
  }
}

class _MomentsTab extends StatelessWidget {
  const _MomentsTab({required this.onOpen});
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(
          Icons.photo_library_outlined,
          size: 48,
          color: AppColors.dustyRose,
        ),
        const SizedBox(height: 16),
        Text('Moments', style: AppTextStyles.h3),
        const SizedBox(height: 8),
        Text(
          'Share little pieces of your day.',
          style: AppTextStyles.bodySmall,
        ),
        const SizedBox(height: 20),
        ElevatedButton(onPressed: onOpen, child: const Text('Open Moments')),
      ],
    ),
  );
}

class _QuickTab extends StatelessWidget {
  const _QuickTab({
    required this.title,
    required this.icon,
    required this.onOpen,
  });
  final String title;
  final IconData icon;
  final VoidCallback onOpen;
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 48, color: AppColors.dustyRose),
        const SizedBox(height: 16),
        Text(title, style: AppTextStyles.h3),
        const SizedBox(height: 20),
        ElevatedButton(onPressed: onOpen, child: Text('Open $title')),
      ],
    ),
  );
}

// ── Generic placeholder for tabs not yet implemented ────────────────────
class _PlaceholderTab extends StatelessWidget {
  const _PlaceholderTab({required this.title, required this.icon});

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 48, color: AppColors.textHint),
          const SizedBox(height: 16),
          Text(
            title,
            style: AppTextStyles.h3.copyWith(color: AppColors.textHint),
          ),
          const SizedBox(height: 8),
          Text('Coming soon', style: AppTextStyles.bodySmall),
        ],
      ),
    );
  }
}

// ── Helper ──────────────────────────────────────────────────────────────
class _TabItem {
  const _TabItem({required this.icon, required this.label});
  final IconData icon;
  final String label;
}
