import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/notifications/notification_providers.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../pairing/providers/pairing_providers.dart';

class NotificationSettingsPage extends ConsumerStatefulWidget {
  const NotificationSettingsPage({super.key});

  @override
  ConsumerState<NotificationSettingsPage> createState() =>
      _NotificationSettingsPageState();
}

class _NotificationSettingsPageState
    extends ConsumerState<NotificationSettingsPage> {
  bool _isSendingTest = false;

  Future<void> _updateSetting(String key, dynamic value) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'notificationSettings': {key: value},
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error updating notification setting: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final userDoc =
        ref.watch(currentUserDocumentProvider).valueOrNull?.data() ?? {};
    final settings =
        (userDoc['notificationSettings'] as Map<String, dynamic>?) ?? {};

    final moments = settings['moments'] as bool? ?? true;
    final messages = settings['messages'] as bool? ?? true;
    final mood = settings['mood'] as bool? ?? true;
    final dailyReminder = settings['dailyReminder'] as bool? ?? false;
    final randomReminder = settings['randomReminder'] as bool? ?? false;
    final previews = settings['previews'] as bool? ?? false;

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        leading: IconButton(
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              context.go(AppRoutes.profile);
            }
          },
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Back',
        ),
        title: Text('Notification Settings', style: AppTextStyles.h3),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
          // ── Section 1: Partner Activity ──────────────────────────────────
          _buildSectionHeader('Partner Activity', Icons.favorite_rounded),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: const BorderSide(color: AppColors.warmGray),
            ),
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(
                    Icons.photo_library_outlined,
                    color: AppColors.dustyRose,
                  ),
                  title: const Text('Shared Moments'),
                  subtitle: const Text(
                    'Get notified immediately when your partner shares a moment',
                  ),
                  value: moments,
                  activeThumbColor: AppColors.dustyRose,
                  onChanged: (val) => _updateSetting('moments', val),
                ),
                const Divider(height: 1, indent: 56),
                SwitchListTile(
                  secondary: const Icon(
                    Icons.chat_bubble_outline_rounded,
                    color: AppColors.dustyRose,
                  ),
                  title: const Text('Chat Messages'),
                  subtitle: const Text(
                    'Receive alerts for new incoming messages from partner',
                  ),
                  value: messages,
                  activeThumbColor: AppColors.dustyRose,
                  onChanged: (val) => _updateSetting('messages', val),
                ),
                const Divider(height: 1, indent: 56),
                SwitchListTile(
                  secondary: const Icon(
                    Icons.mood_rounded,
                    color: AppColors.dustyRose,
                  ),
                  title: const Text('Mood Updates'),
                  subtitle: const Text(
                    'Know when your partner updates how they are feeling',
                  ),
                  value: mood,
                  activeThumbColor: AppColors.dustyRose,
                  onChanged: (val) => _updateSetting('mood', val),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── Section 2: Privacy ───────────────────────────────────────────
          _buildSectionHeader(
            'Privacy & Lock Screen',
            Icons.lock_outline_rounded,
          ),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: const BorderSide(color: AppColors.warmGray),
            ),
            child: SwitchListTile(
              secondary: const Icon(
                Icons.visibility_outlined,
                color: AppColors.dustyRose,
              ),
              title: const Text('Show Photo Previews'),
              subtitle: const Text(
                'When disabled, photo thumbnails stay hidden on lock screen for couples privacy',
              ),
              value: previews,
              activeThumbColor: AppColors.dustyRose,
              onChanged: (val) async {
                await _updateSetting('previews', val);
                try {
                  await FirebaseMessaging.instance
                      .setForegroundNotificationPresentationOptions(
                        alert: val,
                        badge: true,
                        sound: true,
                      );
                } catch (_) {}
              },
            ),
          ),
          const SizedBox(height: 24),

          // ── Section 3: Connection Reminders ──────────────────────────────
          _buildSectionHeader('Connection Reminders', Icons.alarm_rounded),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: const BorderSide(color: AppColors.warmGray),
            ),
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(
                    Icons.nightlight_round,
                    color: AppColors.dustyRose,
                  ),
                  title: const Text('Daily Connection Reminder'),
                  subtitle: const Text(
                    'A gentle 8:00 PM reminder to share a moment together',
                  ),
                  value: dailyReminder,
                  activeThumbColor: AppColors.dustyRose,
                  onChanged: (val) async {
                    await _updateSetting('dailyReminder', val);
                    if (val) {
                      await ref
                          .read(localReminderServiceProvider)
                          .scheduleDailyReminder(hour: 20, minute: 0);
                    } else {
                      await ref
                          .read(localReminderServiceProvider)
                          .cancelDailyReminder();
                    }
                  },
                ),
                const Divider(height: 1, indent: 56),
                SwitchListTile(
                  secondary: const Icon(
                    Icons.shuffle_rounded,
                    color: AppColors.dustyRose,
                  ),
                  title: const Text('Random Spontaneous Prompts'),
                  subtitle: const Text(
                    'Surprise prompt during the day to take a photo for your partner',
                  ),
                  value: randomReminder,
                  activeThumbColor: AppColors.dustyRose,
                  onChanged: (val) async {
                    await _updateSetting('randomReminder', val);
                    if (val) {
                      await ref
                          .read(localReminderServiceProvider)
                          .scheduleRandomReminder();
                    } else {
                      await ref
                          .read(localReminderServiceProvider)
                          .cancelReminder();
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── Section 4: Testing & Diagnostics ─────────────────────────────
          _buildSectionHeader(
            'Diagnostics & Testing',
            Icons.notifications_active_outlined,
          ),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: const BorderSide(color: AppColors.warmGray),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Test Notification Delivery',
                    style: AppTextStyles.h3.copyWith(fontSize: 16),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Tap below to verify that notification banners, sound, and deep linking are functioning on your device.',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isSendingTest
                          ? null
                          : () async {
                              setState(() => _isSendingTest = true);
                              try {
                                await ref
                                    .read(localReminderServiceProvider)
                                    .showTestNotification();
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Test notification dispatched! Check your notification bar.',
                                      ),
                                      backgroundColor: AppColors.dustyRose,
                                      duration: Duration(seconds: 3),
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Failed to send test: $e'),
                                      backgroundColor: AppColors.error,
                                    ),
                                  );
                                }
                              } finally {
                                if (mounted) {
                                  setState(() => _isSendingTest = false);
                                }
                              }
                            },
                      icon: _isSendingTest
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.send_rounded),
                      label: Text(
                        _isSendingTest
                            ? 'Sending...'
                            : 'Send Test Notification',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.dustyRose,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.dustyRose),
          const SizedBox(width: 8),
          Text(
            title,
            style: AppTextStyles.h3.copyWith(
              fontSize: 14,
              color: AppColors.textSecondary,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}
