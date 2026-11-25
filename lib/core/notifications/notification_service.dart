import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../firebase_options.dart';
import 'notification_action_handler.dart';
import 'notification_preferences.dart';

/// Top-level background entry point for Android notification action buttons
/// tapped while the app is in the background or terminated.
@pragma('vm:entry-point')
Future<void> notificationTapBackground(NotificationResponse response) async {
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;
    final data = jsonDecode(payload) as Map<String, dynamic>;
    final handler = NotificationActionHandler();
    await handler.handle(
      data: data,
      actionId: response.actionId,
      allowNavigation: false,
    );
  } catch (e) {
    debugPrint('Background notification action error: $e');
  }
}

/// Top-level background FCM entry point for data-first push messages.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
    // Only render locally when the FCM message is data-only (no `notification`
    // block) to prevent Android double-display.
    if (message.notification == null && message.data.isNotEmpty) {
      final service = NotificationService();
      await service.initializeLocalOnly();
      await service.displayNotificationFromData(message.data);
    }
  } catch (e) {
    debugPrint('Background FCM display warning: $e');
  }
}

/// Centralized Smart Notification Service for Rayna.
///
/// Manages:
/// - 7 dedicated Android notification channels
/// - Rich Moment notifications (`BigPictureStyleInformation`) + Quick Reactions
/// - Mood Check-In notifications + Quick Responses
/// - High-priority Speed Alert notifications + Quick Safety Warnings
/// - User notification preferences & lock-screen privacy
/// - Foreground, background, and terminated action/deep-link routing
class NotificationService {
  NotificationService({
    FirebaseMessaging? messaging,
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    FlutterLocalNotificationsPlugin? localNotifications,
    this.onNavigate,
  }) : _messaging = messaging,
       _auth = auth,
       _firestore = firestore,
       _localNotifications = localNotifications {
    _actionHandler = NotificationActionHandler(
      firestore: _firestore,
      auth: _auth,
      onNavigate: onNavigate,
    );
  }

  final void Function(String route)? onNavigate;

  final FirebaseMessaging? _messaging;
  final FirebaseAuth? _auth;
  final FirebaseFirestore? _firestore;
  final FlutterLocalNotificationsPlugin? _localNotifications;
  late final NotificationActionHandler _actionHandler;

  FirebaseMessaging get messaging => _messaging ?? FirebaseMessaging.instance;
  FirebaseAuth get auth => _auth ?? FirebaseAuth.instance;
  FirebaseFirestore get firestore => _firestore ?? FirebaseFirestore.instance;
  FlutterLocalNotificationsPlugin get localNotifications =>
      _localNotifications ?? FlutterLocalNotificationsPlugin();

  StreamSubscription<String>? _tokenSubscription;
  StreamSubscription<RemoteMessage>? _messageSubscription;
  StreamSubscription<RemoteMessage>? _openedSubscription;
  bool initialized = false;
  bool _localInitialized = false;

  // ── 7 Dedicated Android Notification Channels ─────────────────────────────
  static const AndroidNotificationChannel generalChannel =
      AndroidNotificationChannel(
        'rayna_general',
        'Rayna General',
        description: 'General updates and activity notifications from Rayna.',
        importance: Importance.defaultImportance,
      );

  static const AndroidNotificationChannel momentsChannel =
      AndroidNotificationChannel(
        'rayna_moments',
        'Shared Moments',
        description:
            'Rich photo notifications when your partner shares a moment.',
        importance: Importance.high,
      );

  static const AndroidNotificationChannel moodsChannel =
      AndroidNotificationChannel(
        'rayna_moods',
        'Mood Check-Ins',
        description: 'Live mood check-in updates and quick responses.',
        importance: Importance.high,
      );

  static const AndroidNotificationChannel messagesChannel =
      AndroidNotificationChannel(
        'rayna_messages',
        'Partner Messages',
        description: 'Private chat messages from your partner.',
        importance: Importance.high,
      );

  static const AndroidNotificationChannel pairingChannel =
      AndroidNotificationChannel(
        'rayna_pairing',
        'Pairing & Requests',
        description: 'Connection requests and partner pairing confirmations.',
        importance: Importance.high,
      );

  static const AndroidNotificationChannel reactionsChannel =
      AndroidNotificationChannel(
        'rayna_reactions',
        'Reactions & Responses',
        description: 'Quick reactions on your moments and mood responses.',
        importance: Importance.defaultImportance,
      );

  static const AndroidNotificationChannel
  speedAlertsChannel = AndroidNotificationChannel(
    'rayna_speed_alerts',
    'Speed Safety Alerts',
    description:
        'High-priority safety alerts when partner location speed reaches 80 km/h.',
    importance: Importance.max,
  );

  // Legacy channels preserved for backward compatibility
  static const AndroidNotificationChannel alertsChannel =
      AndroidNotificationChannel(
        'rayna_alerts',
        'Rayna Alerts',
        description: 'Notifications for moments, moods, and partner messages.',
        importance: Importance.high,
      );

  static const AndroidNotificationChannel remindersChannel =
      AndroidNotificationChannel(
        'rayna_reminders',
        'Rayna Reminders',
        description: 'Gentle reminders to share moments with your partner.',
        importance: Importance.defaultImportance,
      );

  static const List<AndroidNotificationChannel> allChannels = [
    generalChannel,
    momentsChannel,
    moodsChannel,
    messagesChannel,
    pairingChannel,
    reactionsChannel,
    speedAlertsChannel,
    alertsChannel,
    remindersChannel,
  ];

  /// Lightweight local-only initialization (safe for background isolate).
  Future<void> initializeLocalOnly() async {
    if (_localInitialized || kIsWeb) return;
    _localInitialized = true;

    try {
      const androidSettings = AndroidInitializationSettings(
        '@drawable/ic_launcher_foreground',
      );
      const initSettings = InitializationSettings(android: androidSettings);
      await localNotifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          final payload = response.payload;
          if (payload != null && payload.isNotEmpty) {
            try {
              final data = jsonDecode(payload) as Map<String, dynamic>;
              _actionHandler.handle(data: data, actionId: response.actionId);
            } catch (_) {}
          }
        },
        onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
      );

      final androidPlugin = localNotifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (androidPlugin != null) {
        for (final channel in allChannels) {
          await androidPlugin.createNotificationChannel(channel);
        }
      }
    } catch (e) {
      debugPrint('Local notifications initialization warning: $e');
    }
  }

  Future<void> initialize() async {
    if (initialized || kIsWeb) return;
    initialized = true;

    await initializeLocalOnly();

    // Register background FCM handler
    try {
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    } catch (e) {
      debugPrint('Background message setup warning: $e');
    }

    // Request push notification permissions & sync FCM token
    try {
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        final token = await messaging.getToken();
        await _saveToken(token);
        _tokenSubscription = messaging.onTokenRefresh.listen(_saveToken);
      }
    } catch (e) {
      debugPrint('FCM permissions error: $e');
    }

    // Foreground push messages listener
    _messageSubscription = FirebaseMessaging.onMessage.listen((
      RemoteMessage message,
    ) {
      final mergedData = <String, dynamic>{
        ...message.data,
        if (message.notification?.title != null)
          'title': message.notification!.title,
        if (message.notification?.body != null)
          'body': message.notification!.body,
        if (message.notification?.android?.imageUrl != null)
          'imageUrl': message.notification!.android!.imageUrl,
        if (message.messageId != null && !message.data.containsKey('eventId'))
          'eventId': message.messageId,
      };
      displayNotificationFromData(mergedData);
    });

    // Open from background state
    _openedSubscription = FirebaseMessaging.onMessageOpenedApp.listen((
      RemoteMessage message,
    ) {
      handlePayload(message.data);
    });

    // Open from terminated state (both FCM and local notification launch details)
    try {
      final initial = await messaging.getInitialMessage();
      if (initial != null) {
        handlePayload(initial.data);
      }
      final launchDetails = await localNotifications
          .getNotificationAppLaunchDetails();
      if (launchDetails?.didNotificationLaunchApp == true &&
          launchDetails?.notificationResponse?.payload != null) {
        final data =
            jsonDecode(launchDetails!.notificationResponse!.payload!)
                as Map<String, dynamic>;
        await _actionHandler.handle(
          data: data,
          actionId: launchDetails.notificationResponse!.actionId,
        );
      }
    } catch (e) {
      debugPrint('Initial notification check error: $e');
    }
  }

  /// Fetches the signed-in user's notification preferences from Firestore.
  Future<NotificationPreferences> loadPreferences() async {
    try {
      final uid = auth.currentUser?.uid;
      if (uid == null) return const NotificationPreferences();
      final doc = await firestore.collection('users').doc(uid).get();
      final raw = doc.data()?['notificationSettings'] as Map<String, dynamic>?;
      return NotificationPreferences.fromMap(raw);
    } catch (_) {
      return const NotificationPreferences();
    }
  }

  /// Resolves which Android channel to use for a given notification [type].
  static AndroidNotificationChannel channelForType(String? type) {
    switch (type) {
      case 'moment':
        return momentsChannel;
      case 'mood':
      case 'mood_response':
        return moodsChannel;
      case 'chat':
      case 'message':
        return messagesChannel;
      case 'pairing':
      case 'pairing_request':
      case 'connection_request':
      case 'request_accepted':
        return pairingChannel;
      case 'reaction':
      case 'moment_reaction':
        return reactionsChannel;
      case 'speed_alert':
      case 'speed_alert_response':
        return speedAlertsChannel;
      default:
        return generalChannel;
    }
  }

  /// Builds rich local notification (including BigPictureStyle and Android
  /// interactive action buttons) while respecting user preferences & privacy.
  Future<void> displayNotificationFromData(
    Map<String, dynamic> data, {
    NotificationPreferences? overridePreferences,
  }) async {
    try {
      final prefs = overridePreferences ?? await loadPreferences();
      final type = (data['type'] as String?)?.trim() ?? 'general';
      if (!prefs.allowsType(type)) return;

      final channel = channelForType(type);
      final title = (data['title'] as String?)?.trim().isNotEmpty == true
          ? (data['title'] as String).trim()
          : 'Rayna';
      final rawBody = (data['body'] as String?)?.trim().isNotEmpty == true
          ? (data['body'] as String).trim()
          : 'New partner update';
      final body = prefs.hideContentOnLockScreen
          ? 'Open Rayna to view this private update.'
          : rawBody;

      // Optional BigPictureStyle for Moment notifications
      StyleInformation? styleInfo;
      final imageUrl = (data['imageUrl'] as String?)?.trim();
      if (type == 'moment' &&
          prefs.canShowMomentImage &&
          imageUrl != null &&
          imageUrl.isNotEmpty) {
        final imageBytes = await _downloadImageBytes(imageUrl);
        if (imageBytes != null) {
          final bitmap = ByteArrayAndroidBitmap(imageBytes);
          styleInfo = BigPictureStyleInformation(
            bitmap,
            largeIcon: bitmap,
            contentTitle: title,
            summaryText: body,
            hideExpandedLargeIcon: false,
          );
        }
      }
      styleInfo ??= BigTextStyleInformation(body, contentTitle: title);

      final actions = _buildActionsForType(type);
      final visibility = prefs.hideContentOnLockScreen
          ? NotificationVisibility.private
          : NotificationVisibility.public;

      final androidDetails = AndroidNotificationDetails(
        channel.id,
        channel.name,
        channelDescription: channel.description,
        importance: channel.importance,
        priority: type == 'speed_alert' ? Priority.max : Priority.high,
        icon: '@drawable/ic_launcher_foreground',
        playSound: prefs.sound,
        enableVibration: prefs.vibration,
        visibility: visibility,
        styleInformation: styleInfo,
        actions: actions,
        category: type == 'speed_alert'
            ? AndroidNotificationCategory.alarm
            : AndroidNotificationCategory.social,
      );

      final details = NotificationDetails(android: androidDetails);
      final eventKey = (data['eventId'] as String?) ?? '${type}_$title';
      final id = eventKey.hashCode & 0x7fffffff;

      await localNotifications.show(
        id,
        title,
        body,
        details,
        payload: jsonEncode(data),
      );
    } catch (e) {
      debugPrint('Notification display error: $e');
    }
  }

  List<AndroidNotificationAction>? _buildActionsForType(String type) {
    switch (type) {
      case 'moment':
        return const [
          AndroidNotificationAction(
            NotificationActionIds.reactLove,
            '❤️ Love',
            showsUserInterface: false,
            cancelNotification: true,
          ),
          AndroidNotificationAction(
            NotificationActionIds.reactHaha,
            '😂 Haha',
            showsUserInterface: false,
            cancelNotification: true,
          ),
          AndroidNotificationAction(
            NotificationActionIds.reactFire,
            '🔥 Fire',
            showsUserInterface: false,
            cancelNotification: true,
          ),
        ];
      case 'mood':
        return const [
          AndroidNotificationAction(
            NotificationActionIds.moodLove,
            '❤️ Send Love',
            showsUserInterface: false,
            cancelNotification: true,
          ),
          AndroidNotificationAction(
            NotificationActionIds.moodHug,
            '🫂 Give a Hug',
            showsUserInterface: false,
            cancelNotification: true,
          ),
          AndroidNotificationAction(
            NotificationActionIds.moodCheckIn,
            '💬 Check In',
            showsUserInterface: true,
            cancelNotification: true,
          ),
        ];
      case 'speed_alert':
        return const [
          AndroidNotificationAction(
            NotificationActionIds.speedCareful,
            '❤️ Be Careful',
            showsUserInterface: false,
            cancelNotification: true,
          ),
          AndroidNotificationAction(
            NotificationActionIds.speedSlowDown,
            '🛑 Slow Down',
            showsUserInterface: false,
            cancelNotification: true,
          ),
          AndroidNotificationAction(
            NotificationActionIds.speedOpenMap,
            '🗺 Open Map',
            showsUserInterface: true,
            cancelNotification: true,
          ),
        ];
      default:
        return null;
    }
  }

  /// Safely downloads image bytes for Moment BigPicture preview (6s timeout).
  /// Never throws; returns `null` on failure so text notification still renders.
  Future<Uint8List?> _downloadImageBytes(String url) async {
    if (url.startsWith('data:image')) {
      try {
        final comma = url.indexOf(',');
        final raw = comma != -1 ? url.substring(comma + 1) : url;
        return base64Decode(raw);
      } catch (_) {
        return null;
      }
    }
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      return null;
    }

    final client = HttpClient()..connectionTimeout = const Duration(seconds: 6);
    try {
      final request = await client
          .getUrl(Uri.parse(url))
          .timeout(const Duration(seconds: 6));
      final response = await request.close().timeout(
        const Duration(seconds: 6),
      );
      if (response.statusCode != HttpStatus.ok) return null;
      final chunks = <int>[];
      await for (final chunk in response) {
        chunks.addAll(chunk);
        // Hard cap at 2 MB for notification bitmap safety
        if (chunks.length > 2 * 1024 * 1024) return null;
      }
      return Uint8List.fromList(chunks);
    } catch (_) {
      return null;
    } finally {
      client.close(force: true);
    }
  }

  /// Dispatches a local test notification (Moment, Mood, or Speed Alert) so
  /// users can verify lock-screen appearance and quick actions on their device.
  Future<void> showTestSmartNotification({
    required String type,
    NotificationPreferences? preferences,
  }) async {
    await initializeLocalOnly();
    final eventId = 'test_${type}_${DateTime.now().millisecondsSinceEpoch}';
    final Map<String, dynamic> data;
    switch (type) {
      case 'moment':
        data = {
          'type': 'moment',
          'eventId': eventId,
          'title': 'Rayna · New Moment',
          'body': 'Your partner sent you a moment ❤️ "Wish you were here."',
        };
      case 'mood':
        data = {
          'type': 'mood',
          'eventId': eventId,
          'title': 'Rayna · Mood Update',
          'body':
              'Your partner is feeling Happy 😊 "Today has been a good day."',
        };
      case 'speed_alert':
        data = {
          'type': 'speed_alert',
          'eventId': eventId,
          'title': '⚠️ Rayna · Speed Alert',
          'body':
              "Your partner's location speed is detected at 84 km/h. Please remind them to slow down and stay safe.",
        };
      default:
        data = {
          'type': 'general',
          'eventId': eventId,
          'title': 'Rayna · Test Notification',
          'body':
              'Notifications, sound, and deep links are working smoothly ❤️',
        };
    }
    await displayNotificationFromData(data, overridePreferences: preferences);
  }

  /// Route deep links based on push payload data.
  void handlePayload(Map<String, dynamic> data) {
    _actionHandler.handle(data: data);
  }

  /// Save FCM device token into the user's private device registry.
  Future<void> _saveToken(String? token) async {
    try {
      final uid = auth.currentUser?.uid;
      if (uid == null || token == null || token.isEmpty) return;
      final deviceId = token.hashCode.abs().toString();
      await firestore
          .collection('users')
          .doc(uid)
          .collection('devices')
          .doc(deviceId)
          .set({
            'fcmToken': token,
            'platform': defaultTargetPlatform.name,
            'updatedAt': FieldValue.serverTimestamp(),
          });
    } catch (e) {
      debugPrint('Error saving FCM device token: $e');
    }
  }

  /// Unregister device token from Firestore when signing out.
  Future<void> unregisterDevice() async {
    try {
      final uid = auth.currentUser?.uid;
      if (uid == null) return;
      final token = await messaging.getToken();
      if (token == null || token.isEmpty) return;
      final deviceId = token.hashCode.abs().toString();
      await firestore
          .collection('users')
          .doc(uid)
          .collection('devices')
          .doc(deviceId)
          .delete();
    } catch (e) {
      debugPrint('Error unregistering device: $e');
    }
  }

  Future<void> dispose() async {
    await _tokenSubscription?.cancel();
    await _messageSubscription?.cancel();
    await _openedSubscription?.cancel();
  }
}
