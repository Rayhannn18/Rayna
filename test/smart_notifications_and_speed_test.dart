import 'package:flutter_test/flutter_test.dart';
import 'package:rayna_app/core/notifications/notification_action_handler.dart';
import 'package:rayna_app/core/notifications/notification_preferences.dart';
import 'package:rayna_app/core/notifications/notification_service.dart';
import 'package:rayna_app/core/router/app_router.dart';
import 'package:rayna_app/features/map/services/speed_monitor_service.dart';
import 'package:rayna_app/features/pairing/data/pairing_service.dart';

void main() {
  group('Phase 1 — Pairing username normalization', () {
    test('strips leading @, trims whitespace, and lowercases consistently', () {
      expect(PairingService.normalizeUsername('  @Krisna  '), equals('krisna'));
      expect(
        PairingService.normalizeUsername('@@Rayhan_18'),
        equals('rayhan_18'),
      );
      expect(PairingService.normalizeUsername('   '), equals(''));
    });
  });

  group('Phase 3–6 — Smart Notification Preferences & Routing', () {
    test(
      'respects master toggle, per-category toggles, and lock-screen privacy',
      () {
        const defaults = NotificationPreferences();
        expect(defaults.allowsType('moment'), isTrue);
        expect(defaults.allowsType('speed_alert'), isTrue);
        expect(defaults.canShowMomentImage, isTrue);

        const masterOff = NotificationPreferences(allEnabled: false);
        expect(masterOff.allowsType('moment'), isFalse);
        expect(masterOff.allowsType('speed_alert'), isFalse);

        const privateLock = NotificationPreferences(
          lockScreenPhotoPreview: true,
          hideContentOnLockScreen: true,
        );
        expect(privateLock.canShowMomentImage, isFalse);

        const noSpeed = NotificationPreferences(speedAlerts: false);
        expect(noSpeed.allowsType('speed_alert'), isFalse);
        expect(noSpeed.allowsType('mood'), isTrue);
      },
    );

    test(
      'resolves all 7 dedicated Android notification channels correctly',
      () {
        expect(
          NotificationService.channelForType('moment').id,
          equals('rayna_moments'),
        );
        expect(
          NotificationService.channelForType('mood').id,
          equals('rayna_moods'),
        );
        expect(
          NotificationService.channelForType('message').id,
          equals('rayna_messages'),
        );
        expect(
          NotificationService.channelForType('connection_request').id,
          equals('rayna_pairing'),
        );
        expect(
          NotificationService.channelForType('moment_reaction').id,
          equals('rayna_reactions'),
        );
        expect(
          NotificationService.channelForType('speed_alert').id,
          equals('rayna_speed_alerts'),
        );
        expect(
          NotificationService.channelForType('other').id,
          equals('rayna_general'),
        );
      },
    );

    test('Central NotificationActionHandler routes all notification types', () {
      expect(
        NotificationActionHandler.resolveRoute({
          'type': 'moment',
          'momentId': 'm_42',
        }),
        equals('/moments/m_42'),
      );
      expect(
        NotificationActionHandler.resolveRoute({'type': 'connection_request'}),
        equals(AppRoutes.pendingRequests),
      );
      expect(
        NotificationActionHandler.resolveRoute({'type': 'request_accepted'}),
        equals(AppRoutes.home),
      );
      expect(
        NotificationActionHandler.resolveRoute({'type': 'mood'}),
        equals(AppRoutes.mood),
      );
      expect(
        NotificationActionHandler.resolveRoute({'type': 'message'}),
        equals(AppRoutes.chat),
      );
      expect(
        NotificationActionHandler.resolveRoute({'type': 'speed_alert'}),
        equals(AppRoutes.map),
      );
      expect(
        NotificationActionHandler.resolveRoute({
          'type': 'speed_alert',
        }, actionId: NotificationActionIds.speedOpenMap),
        equals(AppRoutes.map),
      );
      expect(
        NotificationActionHandler.resolveRoute({
          'type': 'mood',
        }, actionId: NotificationActionIds.moodCheckIn),
        equals(AppRoutes.chat),
      );
    });
  });

  group('Phase 7 — Speed Alert 80 km/h State Machine & Hysteresis', () {
    SpeedSample sampleAt(double kmh, DateTime ts, {double accuracy = 10.0}) {
      return SpeedSample(
        speedMetersPerSecond: kmh / 3.6,
        accuracyMeters: accuracy,
        timestamp: ts,
      );
    }

    test('60 km/h and 79 km/h never trigger speed alert', () {
      final monitor = SpeedMonitorService();
      final t0 = DateTime(2026, 11, 25, 16, 0, 0);

      for (int sec = 0; sec <= 20; sec += 5) {
        final t = t0.add(Duration(seconds: sec));
        final res60 = monitor.evaluate(
          sampleAt(60, t),
          isSharingLocation: true,
          isSpeedAlertEnabled: true,
          now: t,
        );
        expect(res60.shouldTriggerAlert, isFalse);
      }

      for (int sec = 25; sec <= 45; sec += 5) {
        final t = t0.add(Duration(seconds: sec));
        final res79 = monitor.evaluate(
          sampleAt(79, t),
          isSharingLocation: true,
          isSpeedAlertEnabled: true,
          now: t,
        );
        expect(res79.shouldTriggerAlert, isFalse);
      }
    });

    test(
      'brief 80 km/h spike (<10s) does not trigger; sustained >=10s triggers once',
      () {
        final monitor = SpeedMonitorService();
        final t0 = DateTime(2026, 11, 25, 16, 0, 0);

        // 0s: 84 km/h -> warning only
        var res = monitor.evaluate(
          sampleAt(84, t0),
          isSharingLocation: true,
          isSpeedAlertEnabled: true,
          now: t0,
        );
        expect(res.shouldTriggerAlert, isFalse);
        expect(res.state, equals(SpeedAlertState.speedWarning));

        // 5s: 84 km/h -> still under 10s
        final t5 = t0.add(const Duration(seconds: 5));
        res = monitor.evaluate(
          sampleAt(84, t5),
          isSharingLocation: true,
          isSpeedAlertEnabled: true,
          now: t5,
        );
        expect(res.shouldTriggerAlert, isFalse);

        // 11s: 100 km/h -> sustained >= 10s -> triggers alert ONCE
        final t11 = t0.add(const Duration(seconds: 11));
        res = monitor.evaluate(
          sampleAt(100, t11),
          isSharingLocation: true,
          isSpeedAlertEnabled: true,
          now: t11,
        );
        expect(res.shouldTriggerAlert, isTrue);
        expect(res.state, equals(SpeedAlertState.alertSent));

        // 16s: 102 km/h -> already alertSent, must NOT repeat
        final t16 = t0.add(const Duration(seconds: 16));
        res = monitor.evaluate(
          sampleAt(102, t16),
          isSharingLocation: true,
          isSpeedAlertEnabled: true,
          now: t16,
        );
        expect(res.shouldTriggerAlert, isFalse);
        expect(res.state, equals(SpeedAlertState.alertSent));

        // 20s..31s: drops below 70 km/h consistently -> resets to speedBackToNormal
        final t20 = t0.add(const Duration(seconds: 20));
        monitor.evaluate(
          sampleAt(62, t20),
          isSharingLocation: true,
          isSpeedAlertEnabled: true,
          now: t20,
        );
        final t31 = t0.add(const Duration(seconds: 31));
        res = monitor.evaluate(
          sampleAt(58, t31),
          isSharingLocation: true,
          isSpeedAlertEnabled: true,
          now: t31,
        );
        expect(res.state, equals(SpeedAlertState.speedBackToNormal));
      },
    );

    test('rejects stale GPS, poor accuracy (>25m), and disabled sharing', () {
      final monitor = SpeedMonitorService();
      final now = DateTime(2026, 11, 25, 16, 10, 0);

      // Stale GPS (60s old)
      final staleRes = monitor.evaluate(
        sampleAt(95, now.subtract(const Duration(seconds: 60))),
        isSharingLocation: true,
        isSpeedAlertEnabled: true,
        now: now,
      );
      expect(staleRes.shouldTriggerAlert, isFalse);
      expect(staleRes.state, equals(SpeedAlertState.locationStale));

      // Poor accuracy (45m > 25m)
      final poorAccRes = monitor.evaluate(
        sampleAt(95, now, accuracy: 45.0),
        isSharingLocation: true,
        isSpeedAlertEnabled: true,
        now: now,
      );
      expect(poorAccRes.shouldTriggerAlert, isFalse);

      // Sharing disabled
      final disabledRes = monitor.evaluate(
        sampleAt(95, now),
        isSharingLocation: false,
        isSpeedAlertEnabled: true,
        now: now,
      );
      expect(disabledRes.shouldTriggerAlert, isFalse);
      expect(disabledRes.state, equals(SpeedAlertState.sharingDisabled));
    });
  });
}
