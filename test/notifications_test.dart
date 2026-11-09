import 'package:flutter_test/flutter_test.dart';
import 'package:rayna_app/core/notifications/notification_service.dart';

void main() {
  group('Notification System Tests', () {
    test('AndroidNotificationChannels have correct properties and IDs', () {
      expect(NotificationService.alertsChannel.id, equals('rayna_alerts'));
      expect(NotificationService.alertsChannel.name, equals('Rayna Alerts'));

      expect(
        NotificationService.remindersChannel.id,
        equals('rayna_reminders'),
      );
      expect(
        NotificationService.remindersChannel.name,
        equals('Rayna Reminders'),
      );
    });

    test('Payload routing for momentId navigates to moment detail route', () {
      String? navigatedRoute;
      final service = NotificationService(
        onNavigate: (r) => navigatedRoute = r,
      );
      service.handlePayload({'momentId': 'test_moment_456'});
      expect(navigatedRoute, equals('/moments/test_moment_456'));
    });

    test('Payload routing for chat navigates to chat route', () {
      String? navigatedRoute;
      final service = NotificationService(
        onNavigate: (r) => navigatedRoute = r,
      );
      service.handlePayload({'type': 'chat'});
      expect(navigatedRoute, equals('/chat'));
    });

    test('Payload routing for message navigates to chat route', () {
      String? navigatedRoute;
      final service = NotificationService(
        onNavigate: (r) => navigatedRoute = r,
      );
      service.handlePayload({'type': 'message'});
      expect(navigatedRoute, equals('/chat'));
    });

    test('Payload routing for mood navigates to mood route', () {
      String? navigatedRoute;
      final service = NotificationService(
        onNavigate: (r) => navigatedRoute = r,
      );
      service.handlePayload({'type': 'mood'});
      expect(navigatedRoute, equals('/mood'));
    });

    test('Payload routing for pairing request navigates to requests page', () {
      String? navigatedRoute;
      final service = NotificationService(
        onNavigate: (r) => navigatedRoute = r,
      );
      service.handlePayload({'type': 'pairing_request'});
      expect(navigatedRoute, equals('/pairing/requests'));
    });

    test('Empty payload handles gracefully without error', () {
      String? navigatedRoute;
      final service = NotificationService(
        onNavigate: (r) => navigatedRoute = r,
      );
      expect(() => service.handlePayload({}), returnsNormally);
      expect(navigatedRoute, isNull);
    });
  });
}
