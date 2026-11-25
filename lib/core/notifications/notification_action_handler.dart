import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../router/app_router.dart';

/// Standard notification action identifiers shared across Android local
/// notification buttons, background callbacks, and foreground handlers.
class NotificationActionIds {
  NotificationActionIds._();

  // Moment quick reactions (max 3 visible actions on Android lock screen)
  static const String reactLove = 'react_love';
  static const String reactHaha = 'react_haha';
  static const String reactFire = 'react_fire';

  // Mood check-in quick responses
  static const String moodLove = 'mood_love';
  static const String moodHug = 'mood_hug';
  static const String moodCheckIn = 'mood_checkin';

  // Speed alert quick warning actions
  static const String speedCareful = 'speed_careful';
  static const String speedSlowDown = 'speed_slow_down';
  static const String speedOpenMap = 'speed_open_map';

  static String? reactionEmojiFor(String actionId) {
    switch (actionId) {
      case reactLove:
        return '❤️';
      case reactHaha:
        return '😂';
      case reactFire:
        return '🔥';
      default:
        return null;
    }
  }

  static String? reactionLabelFor(String actionId) {
    switch (actionId) {
      case reactLove:
        return 'Love';
      case reactHaha:
        return 'Haha';
      case reactFire:
        return 'Fire';
      default:
        return null;
    }
  }

  static String? moodResponseMessageFor(String actionId) {
    switch (actionId) {
      case moodLove:
        return 'Sent you love ❤️';
      case moodHug:
        return 'Sent you a warm hug 🫂';
      case moodCheckIn:
        return 'Checking in on you 💬';
      default:
        return null;
    }
  }

  static String? speedResponseMessageFor(String actionId) {
    switch (actionId) {
      case speedCareful:
        return 'Please be careful out there ❤️';
      case speedSlowDown:
        return 'Please slow down. I want you to stay safe. 🛑';
      default:
        return null;
    }
  }
}

/// Centralized handler for notification taps and quick actions across
/// foreground, background, and terminated states.
class NotificationActionHandler {
  NotificationActionHandler({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    this.onNavigate,
  }) : _firestore = firestore,
       _auth = auth;

  final FirebaseFirestore? _firestore;
  final FirebaseAuth? _auth;
  final void Function(String route)? onNavigate;

  FirebaseFirestore get _db => _firestore ?? FirebaseFirestore.instance;
  FirebaseAuth get _firebaseAuth => _auth ?? FirebaseAuth.instance;

  /// In-memory deduplication set to prevent duplicate navigation/writes when
  /// both `getInitialMessage` and `onMessageOpenedApp` fire for the same event.
  final Set<String> _handledEventKeys = <String>{};

  /// Resolves the target GoRouter path for a notification payload.
  static String? resolveRoute(Map<String, dynamic> data, {String? actionId}) {
    if (actionId == NotificationActionIds.speedOpenMap) {
      return AppRoutes.map;
    }
    if (actionId == NotificationActionIds.moodCheckIn) {
      return AppRoutes.chat;
    }

    final momentId = (data['momentId'] as String?)?.trim();
    if (momentId != null && momentId.isNotEmpty) {
      return '/moments/$momentId';
    }

    final type = (data['type'] as String?)?.trim();
    switch (type) {
      case 'chat':
      case 'message':
        return AppRoutes.chat;
      case 'mood':
      case 'mood_response':
        return AppRoutes.mood;
      case 'pairing_request':
      case 'connection_request':
      case 'pairing':
        return AppRoutes.pendingRequests;
      case 'request_accepted':
        return AppRoutes.home;
      case 'speed_alert':
      case 'speed_alert_response':
      case 'location_sharing':
        return AppRoutes.map;
      default:
        return null;
    }
  }

  /// Handles either a direct notification tap (`actionId == null`) or a quick
  /// action button click (`actionId != null`).
  Future<void> handle({
    required Map<String, dynamic> data,
    String? actionId,
    bool allowNavigation = true,
  }) async {
    if (data.isEmpty && (actionId == null || actionId.isEmpty)) return;

    final eventId = (data['eventId'] as String?)?.trim() ?? '';
    final dedupeKey = eventId.isNotEmpty
        ? '$eventId::${actionId ?? 'open'}'
        : '';
    if (dedupeKey.isNotEmpty && _handledEventKeys.contains(dedupeKey)) {
      return;
    }
    if (dedupeKey.isNotEmpty) {
      _handledEventKeys.add(dedupeKey);
      if (_handledEventKeys.length > 100) {
        _handledEventKeys.remove(_handledEventKeys.first);
      }
    }

    // 1. Moment Quick Reaction
    if (actionId != null &&
        NotificationActionIds.reactionEmojiFor(actionId) != null) {
      await _recordMomentReaction(data: data, actionId: actionId);
      return;
    }

    // 2. Mood Quick Response
    if (actionId == NotificationActionIds.moodLove ||
        actionId == NotificationActionIds.moodHug ||
        actionId == NotificationActionIds.moodCheckIn) {
      await _recordMoodResponse(data: data, actionId: actionId!);
      if (actionId == NotificationActionIds.moodCheckIn && allowNavigation) {
        _navigate(AppRoutes.chat);
      }
      return;
    }

    // 3. Speed Alert Quick Warning Response
    if (actionId == NotificationActionIds.speedCareful ||
        actionId == NotificationActionIds.speedSlowDown) {
      await _recordSpeedAlertResponse(data: data, actionId: actionId!);
      return;
    }

    // 4. Navigation / Deep Link
    if (allowNavigation) {
      final route = resolveRoute(data, actionId: actionId);
      if (route != null) {
        _navigate(route);
      }
    }
  }

  void _navigate(String route) {
    if (onNavigate != null) {
      onNavigate!(route);
    } else {
      appRouter.go(route);
    }
  }

  /// Idempotently saves a quick reaction to `pairs/{pairId}/moments/{momentId}/reactions/{uid}`.
  /// Uses the responder's UID as the document ID so repeated callbacks never create duplicates.
  Future<void> _recordMomentReaction({
    required Map<String, dynamic> data,
    required String actionId,
  }) async {
    try {
      final user = _firebaseAuth.currentUser;
      final pairId = (data['pairId'] as String?)?.trim() ?? '';
      final momentId = (data['momentId'] as String?)?.trim() ?? '';
      final emoji = NotificationActionIds.reactionEmojiFor(actionId);
      final label = NotificationActionIds.reactionLabelFor(actionId);
      if (user == null ||
          pairId.isEmpty ||
          momentId.isEmpty ||
          emoji == null ||
          label == null) {
        return;
      }

      await _db
          .collection('pairs')
          .doc(pairId)
          .collection('moments')
          .doc(momentId)
          .collection('reactions')
          .doc(user.uid)
          .set({
            'uid': user.uid,
            'displayName': user.displayName ?? 'Partner',
            'emoji': emoji,
            'label': label,
            'actionId': actionId,
            'momentId': momentId,
            'pairId': pairId,
            'eventId': data['eventId'] ?? '',
            'createdAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error saving moment quick reaction: $e');
    }
  }

  /// Idempotently saves a quick mood response to
  /// `pairs/{pairId}/moodHistory/{moodHistoryId}/responses/{uid}_{actionId}`.
  Future<void> _recordMoodResponse({
    required Map<String, dynamic> data,
    required String actionId,
  }) async {
    try {
      final user = _firebaseAuth.currentUser;
      final pairId = (data['pairId'] as String?)?.trim() ?? '';
      final moodHistoryId = (data['moodHistoryId'] as String?)?.trim() ?? '';
      final message = NotificationActionIds.moodResponseMessageFor(actionId);
      if (user == null ||
          pairId.isEmpty ||
          moodHistoryId.isEmpty ||
          message == null) {
        return;
      }

      final responseId = '${user.uid}_$actionId';
      await _db
          .collection('pairs')
          .doc(pairId)
          .collection('moodHistory')
          .doc(moodHistoryId)
          .collection('responses')
          .doc(responseId)
          .set({
            'uid': user.uid,
            'displayName': user.displayName ?? 'Partner',
            'actionId': actionId,
            'message': message,
            'moodHistoryId': moodHistoryId,
            'targetUid': data['senderUid'] ?? '',
            'pairId': pairId,
            'createdAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error saving mood quick response: $e');
    }
  }

  /// Idempotently saves a safety warning response to
  /// `pairs/{pairId}/speedAlerts/{alertId}/responses/{uid}_{actionId}`.
  Future<void> _recordSpeedAlertResponse({
    required Map<String, dynamic> data,
    required String actionId,
  }) async {
    try {
      final user = _firebaseAuth.currentUser;
      final pairId = (data['pairId'] as String?)?.trim() ?? '';
      final alertId = (data['speedAlertId'] as String?)?.trim() ?? '';
      final message = NotificationActionIds.speedResponseMessageFor(actionId);
      if (user == null ||
          pairId.isEmpty ||
          alertId.isEmpty ||
          message == null) {
        return;
      }

      final responseId = '${user.uid}_$actionId';
      await _db
          .collection('pairs')
          .doc(pairId)
          .collection('speedAlerts')
          .doc(alertId)
          .collection('responses')
          .doc(responseId)
          .set({
            'uid': user.uid,
            'displayName': user.displayName ?? 'Partner',
            'actionId': actionId,
            'message': message,
            'speedAlertId': alertId,
            'targetUid': data['senderUid'] ?? '',
            'pairId': pairId,
            'createdAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error saving speed alert response: $e');
    }
  }
}
