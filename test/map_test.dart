import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:rayna_app/features/map/providers/map_providers.dart';

void main() {
  group('Map Providers Tests', () {
    test('default map type is MapType.normal', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(mapTypeProvider), equals(MapType.normal));
    });

    test('can toggle map type to satellite and back', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(mapTypeProvider.notifier).state = MapType.satellite;
      expect(container.read(mapTypeProvider), equals(MapType.satellite));

      container.read(mapTypeProvider.notifier).state = MapType.normal;
      expect(container.read(mapTypeProvider), equals(MapType.normal));
    });

    test('camera follow mode defaults to true', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(isCameraFollowModeProvider), isTrue);

      container.read(isCameraFollowModeProvider.notifier).state = false;
      expect(container.read(isCameraFollowModeProvider), isFalse);
    });
  });
}

