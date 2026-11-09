import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../router/app_router.dart';

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
       _localNotifications = localNotifications;

  final void Function(String route)? onNavigate;

  final FirebaseMessaging? _messaging;
  final FirebaseAuth? _auth;
  final FirebaseFirestore? _firestore;
  final FlutterLocalNotificationsPlugin? _localNotifications;

  FirebaseMessaging get messaging => _messaging ?? FirebaseMessaging.instance;
  FirebaseAuth get auth => _auth ?? FirebaseAuth.instance;
  FirebaseFirestore get firestore => _firestore ?? FirebaseFirestore.instance;
  FlutterLocalNotificationsPlugin get localNotifications =>
      _localNotifications ?? FlutterLocalNotificationsPlugin();

  StreamSubscription<String>? _tokenSubscription;
  StreamSubscription<RemoteMessage>? _messageSubscription;
  StreamSubscription<RemoteMessage>? _openedSubscription;
  bool initialized = false;

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

  Future<void> initialize() async {
    if (initialized || kIsWeb) return;
    initialized = true;

    // 1. Initialize local notification display for foreground pushes & deep links
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
              handlePayload(data);
            } catch (_) {}
          }
        },
      );

      final androidPlugin = localNotifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (androidPlugin != null) {
        await androidPlugin.createNotificationChannel(alertsChannel);
        await androidPlugin.createNotificationChannel(remindersChannel);
      }
    } catch (e) {
      debugPrint('Local notifications initialization warning: $e');
    }

    // 2. Set background message callback
    try {
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    } catch (e) {
      debugPrint('Background message setup warning: $e');
    }

    // 3. Request push notification permissions
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

    // 4. Foreground push messages listener
    _messageSubscription = FirebaseMessaging.onMessage.listen((
      RemoteMessage message,
    ) {
      _showForegroundNotification(message);
    });

    // 5. Open from background or terminated state
    _openedSubscription = FirebaseMessaging.onMessageOpenedApp.listen((
      RemoteMessage message,
    ) {
      handlePayload(message.data);
    });

    try {
      final initial = await messaging.getInitialMessage();
      if (initial != null) {
        handlePayload(initial.data);
      }
    } catch (e) {
      debugPrint('FCM initial message check error: $e');
    }
  }

  /// Display a heads-up local notification when an FCM message arrives in the foreground.
  Future<void> _showForegroundNotification(RemoteMessage message) async {
    try {
      final notification = message.notification;
      final title = notification?.title ?? message.data['title'] ?? 'Rayna';
      final body =
          notification?.body ?? message.data['body'] ?? 'New partner update';
      final payload = jsonEncode(message.data);

      const androidDetails = AndroidNotificationDetails(
        'rayna_alerts',
        'Rayna Alerts',
        channelDescription:
            'Notifications for moments, moods, and partner messages.',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@drawable/ic_launcher_foreground',
      );
      const details = NotificationDetails(android: androidDetails);

      final id = message.messageId.hashCode;
      await localNotifications.show(id, title, body, details, payload: payload);
    } catch (e) {
      debugPrint('Foreground notification display error: $e');
    }
  }

  /// Route deep links based on push payload data.
  void handlePayload(Map<String, dynamic> data) {
    if (data.isEmpty) return;

    void navigate(String route) {
      if (onNavigate != null) {
        onNavigate!(route);
      } else {
        appRouter.go(route);
      }
    }

    final momentId = data['momentId'] as String?;
    if (momentId != null && momentId.isNotEmpty) {
      navigate('/moments/$momentId');
      return;
    }

    final type = data['type'] as String?;
    switch (type) {
      case 'chat':
      case 'message':
        navigate('/chat');
        break;
      case 'mood':
        navigate('/mood');
        break;
      case 'pairing_request':
      case 'pairing':
        navigate('/pairing/requests');
        break;
      default:
        break;
    }
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

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Background payload processing is intentionally data-first.
  // Sensitive images or private moment links are never rendered directly from raw push payloads.
}
