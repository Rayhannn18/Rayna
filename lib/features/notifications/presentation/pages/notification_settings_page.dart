import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/notifications/notification_preferences.dart';
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
  String? _sendingTestType;

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

  Future<void> _sendTest(String type, NotificationPreferences prefs) async {
    if (_sendingTestType != null) return;
    setState(() => _sendingTestType = type);
    try {
      await ref
          .read(notificationServiceProvider)
          .showTestSmartNotification(type: type, preferences: prefs);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Test notification dispatched! Check your notification shade.',
            ),
            backgroundColor: AppColors.dustyRose,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send test: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sendingTestType = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final userDoc =
        ref.watch(currentUserDocumentProvider).valueOrNull?.data() ?? {};
    final prefs = NotificationPreferences.fromMap(
      userDoc['notificationSettings'] as Map<String, dynamic>?,
    );

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        leading: IconButton(
          onPressed: () {
            if (context.canPop()) {
              context.pop();
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
          // ── Master Toggle ────────────────────────────────────────────────
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: const BorderSide(color: AppColors.warmGray),
            ),
            child: SwitchListTile(
              secondary: const Icon(
                Icons.notifications_active_rounded,
                color: AppColors.dustyRose,
              ),
              title: Text(
                'Enable All Notifications',
                style: AppTextStyles.labelLarge,
              ),
              subtitle: const Text(
                'Master switch for all Rayna partner alerts and reminders',
              ),
              value: prefs.allEnabled,
              activeThumbColor: AppColors.dustyRose,
              onChanged: (val) => _updateSetting('allEnabled', val),
            ),
          ),
          const SizedBox(height: 22),

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
                  title: const Text('Moment Notifications'),
                  subtitle: const Text(
                    'Get notified when your partner shares a new photo moment',
                  ),
                  value: prefs.moments,
                  activeThumbColor: AppColors.dustyRose,
                  onChanged: prefs.allEnabled
                      ? (val) => _updateSetting('moments', val)
                      : null,
                ),
                const Divider(height: 1, indent: 56),
                SwitchListTile(
                  secondary: const Icon(
                    Icons.mood_rounded,
                    color: AppColors.dustyRose,
                  ),
                  title: const Text('Mood Notifications'),
                  subtitle: const Text(
                    'Know when your partner checks in their mood or sends a response',
                  ),
                  value: prefs.mood,
                  activeThumbColor: AppColors.dustyRose,
                  onChanged: prefs.allEnabled
                      ? (val) => _updateSetting('mood', val)
                      : null,
                ),
                const Divider(height: 1, indent: 56),
                SwitchListTile(
                  secondary: const Icon(
                    Icons.chat_bubble_outline_rounded,
                    color: AppColors.dustyRose,
                  ),
                  title: const Text('Message Notifications'),
                  subtitle: const Text(
                    'Receive alerts for new incoming private chat messages',
                  ),
                  value: prefs.messages,
                  activeThumbColor: AppColors.dustyRose,
                  onChanged: prefs.allEnabled
                      ? (val) => _updateSetting('messages', val)
                      : null,
                ),
                const Divider(height: 1, indent: 56),
                SwitchListTile(
                  secondary: const Icon(
                    Icons.link_rounded,
                    color: AppColors.dustyRose,
                  ),
                  title: const Text('Pairing Notifications'),
                  subtitle: const Text(
                    'Alerts for incoming connection requests and acceptances',
                  ),
                  value: prefs.pairing,
                  activeThumbColor: AppColors.dustyRose,
                  onChanged: prefs.allEnabled
                      ? (val) => _updateSetting('pairing', val)
                      : null,
                ),
                const Divider(height: 1, indent: 56),
                SwitchListTile(
                  secondary: const Icon(
                    Icons.favorite_outline_rounded,
                    color: AppColors.dustyRose,
                  ),
                  title: const Text('Reaction Notifications'),
                  subtitle: const Text(
                    'Know when your partner reacts to your shared moments',
                  ),
                  value: prefs.reactions,
                  activeThumbColor: AppColors.dustyRose,
                  onChanged: prefs.allEnabled
                      ? (val) => _updateSetting('reactions', val)
                      : null,
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),

          // ── Section 2: Safety & Speed Alerts ─────────────────────────────
          _buildSectionHeader('Safety & Speed Alerts', Icons.speed_rounded),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: const BorderSide(color: AppColors.warmGray),
            ),
            child: SwitchListTile(
              secondary: const Icon(
                Icons.warning_amber_rounded,
                color: AppColors.dustyRose,
              ),
              title: const Text('Speed Alerts (80 km/h)'),
              subtitle: const Text(
                'Notify partner when GPS location speed stays at 80 km/h or above',
              ),
              value: prefs.speedAlerts,
              activeThumbColor: AppColors.dustyRose,
              onChanged: prefs.allEnabled
                  ? (val) => _updateSetting('speedAlerts', val)
                  : null,
            ),
          ),
          const SizedBox(height: 22),

          // ── Section 3: Lock Screen, Sound & Vibration ────────────────────
          _buildSectionHeader(
            'Lock Screen, Sound & Privacy',
            Icons.lock_outline_rounded,
          ),
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
                    Icons.visibility_outlined,
                    color: AppColors.dustyRose,
                  ),
                  title: const Text('Show Photo Preview on Lock Screen'),
                  subtitle: const Text(
                    'Display Moment photo preview when supported by your Android lock screen',
                  ),
                  value: prefs.lockScreenPhotoPreview,
                  activeThumbColor: AppColors.dustyRose,
                  onChanged: prefs.allEnabled
                      ? (val) async {
                          await _updateSetting('lockScreenPhotoPreview', val);
                          await _updateSetting('previews', val);
                          try {
                            await FirebaseMessaging.instance
                                .setForegroundNotificationPresentationOptions(
                                  alert: val,
                                  badge: true,
                                  sound: prefs.sound,
                                );
                          } catch (_) {}
                        }
                      : null,
                ),
                const Divider(height: 1, indent: 56),
                SwitchListTile(
                  secondary: const Icon(
                    Icons.privacy_tip_outlined,
                    color: AppColors.dustyRose,
                  ),
                  title: const Text('Hide Content on Lock Screen'),
                  subtitle: const Text(
                    'Mask photo previews and message text for extra couple privacy',
                  ),
                  value: prefs.hideContentOnLockScreen,
                  activeThumbColor: AppColors.dustyRose,
                  onChanged: prefs.allEnabled
                      ? (val) => _updateSetting('hideContentOnLockScreen', val)
                      : null,
                ),
                const Divider(height: 1, indent: 56),
                SwitchListTile(
                  secondary: const Icon(
                    Icons.volume_up_outlined,
                    color: AppColors.dustyRose,
                  ),
                  title: const Text('Notification Sound'),
                  value: prefs.sound,
                  activeThumbColor: AppColors.dustyRose,
                  onChanged: prefs.allEnabled
                      ? (val) => _updateSetting('sound', val)
                      : null,
                ),
                const Divider(height: 1, indent: 56),
                SwitchListTile(
                  secondary: const Icon(
                    Icons.vibration_rounded,
                    color: AppColors.dustyRose,
                  ),
                  title: const Text('Vibration'),
                  value: prefs.vibration,
                  activeThumbColor: AppColors.dustyRose,
                  onChanged: prefs.allEnabled
                      ? (val) => _updateSetting('vibration', val)
                      : null,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Text(
              'Note: Final lock screen appearance and photo preview visibility always respect your Android OS and device privacy settings.',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
                fontSize: 11.5,
              ),
            ),
          ),
          const SizedBox(height: 22),

          // ── Section 4: Connection Reminders ──────────────────────────────
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
                  value: prefs.dailyReminder,
                  activeThumbColor: AppColors.dustyRose,
                  onChanged: prefs.allEnabled
                      ? (val) async {
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
                        }
                      : null,
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
                  value: prefs.randomReminder,
                  activeThumbColor: AppColors.dustyRose,
                  onChanged: prefs.allEnabled
                      ? (val) async {
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
                        }
                      : null,
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),

          // ── Section 5: Test Notifications ────────────────────────────────
          _buildSectionHeader(
            'Test Notifications',
            Icons.notifications_none_rounded,
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
                    'Preview on Your Device',
                    style: AppTextStyles.h3.copyWith(fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Test Moment, Mood, and Speed Alert notifications locally without sending anything to your partner.',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildTestChip(
                        label: 'Test Moment',
                        icon: Icons.photo_camera_outlined,
                        type: 'moment',
                        prefs: prefs,
                      ),
                      _buildTestChip(
                        label: 'Test Mood',
                        icon: Icons.mood_rounded,
                        type: 'mood',
                        prefs: prefs,
                      ),
                      _buildTestChip(
                        label: 'Test Speed Alert',
                        icon: Icons.speed_rounded,
                        type: 'speed_alert',
                        prefs: prefs,
                      ),
                    ],
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

  Widget _buildTestChip({
    required String label,
    required IconData icon,
    required String type,
    required NotificationPreferences prefs,
  }) {
    final isLoading = _sendingTestType == type;
    return OutlinedButton.icon(
      onPressed: _sendingTestType != null ? null : () => _sendTest(type, prefs),
      icon: isLoading
          ? const SizedBox(
              width: 15,
              height: 15,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.dustyRose,
              ),
            )
          : Icon(icon, size: 17),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.dustyRose,
        side: BorderSide(color: AppColors.dustyRose.withValues(alpha: 0.45)),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
