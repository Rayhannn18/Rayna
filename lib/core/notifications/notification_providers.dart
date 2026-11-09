import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'notification_service.dart';
import 'local_reminder_service.dart';

final notificationServiceProvider = Provider<NotificationService>((ref) {
  final service = NotificationService();
  ref.onDispose(service.dispose);
  return service;
});

final localReminderServiceProvider = Provider<LocalReminderService>((ref) {
  final service = LocalReminderService();
  ref.onDispose(service.cancelReminder);
  return service;
});
