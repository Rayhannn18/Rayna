/// Strongly-typed notification preferences stored under
/// `users/{uid}.notificationSettings`.
class NotificationPreferences {
  const NotificationPreferences({
    this.allEnabled = true,
    this.moments = true,
    this.mood = true,
    this.messages = true,
    this.pairing = true,
    this.reactions = true,
    this.speedAlerts = true,
    this.lockScreenPhotoPreview = true,
    this.hideContentOnLockScreen = false,
    this.sound = true,
    this.vibration = true,
    this.dailyReminder = false,
    this.randomReminder = false,
  });

  final bool allEnabled;
  final bool moments;
  final bool mood;
  final bool messages;
  final bool pairing;
  final bool reactions;
  final bool speedAlerts;
  final bool lockScreenPhotoPreview;
  final bool hideContentOnLockScreen;
  final bool sound;
  final bool vibration;
  final bool dailyReminder;
  final bool randomReminder;

  factory NotificationPreferences.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const NotificationPreferences();
    return NotificationPreferences(
      allEnabled: map['allEnabled'] as bool? ?? true,
      moments: map['moments'] as bool? ?? true,
      mood: map['mood'] as bool? ?? true,
      messages: map['messages'] as bool? ?? true,
      pairing: map['pairing'] as bool? ?? true,
      reactions: map['reactions'] as bool? ?? true,
      speedAlerts: map['speedAlerts'] as bool? ?? true,
      lockScreenPhotoPreview:
          map['lockScreenPhotoPreview'] as bool? ??
          map['previews'] as bool? ??
          true,
      hideContentOnLockScreen: map['hideContentOnLockScreen'] as bool? ?? false,
      sound: map['sound'] as bool? ?? true,
      vibration: map['vibration'] as bool? ?? true,
      dailyReminder: map['dailyReminder'] as bool? ?? false,
      randomReminder: map['randomReminder'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
    'allEnabled': allEnabled,
    'moments': moments,
    'mood': mood,
    'messages': messages,
    'pairing': pairing,
    'reactions': reactions,
    'speedAlerts': speedAlerts,
    'lockScreenPhotoPreview': lockScreenPhotoPreview,
    'previews': lockScreenPhotoPreview,
    'hideContentOnLockScreen': hideContentOnLockScreen,
    'sound': sound,
    'vibration': vibration,
    'dailyReminder': dailyReminder,
    'randomReminder': randomReminder,
  };

  /// Returns `true` if notifications of [type] should be displayed.
  bool allowsType(String? type) {
    if (!allEnabled) return false;
    switch (type) {
      case 'moment':
        return moments;
      case 'mood':
      case 'mood_response':
        return mood;
      case 'chat':
      case 'message':
        return messages;
      case 'pairing':
      case 'pairing_request':
      case 'connection_request':
      case 'request_accepted':
        return pairing;
      case 'reaction':
      case 'moment_reaction':
        return reactions;
      case 'speed_alert':
      case 'speed_alert_response':
        return speedAlerts;
      default:
        return true;
    }
  }

  /// Whether a Moment notification may show its photo thumbnail/BigPicture.
  bool get canShowMomentImage =>
      lockScreenPhotoPreview && !hideContentOnLockScreen;
}
