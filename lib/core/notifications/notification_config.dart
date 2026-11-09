class NotificationConfig {
  NotificationConfig._();

  /// Paste the Web Push certificate key from
  /// Firebase Console -> Project settings -> Cloud Messaging -> Web configuration.
  ///
  /// While empty, web push stays disabled and the app runs without errors.
  static const String webVapidKey = '';

  static bool get webPushEnabled => webVapidKey.isNotEmpty;
}
