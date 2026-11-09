import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rayna_app/shared/widgets/glass_bottom_nav_bar.dart';

void main() {
  group('GlassBottomNavBar Widget Tests', () {
    testWidgets('renders all 4 navigation items correctly', (tester) async {
      int selectedIndex = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            bottomNavigationBar: GlassBottomNavBar(
              currentIndex: selectedIndex,
              onTap: (index) => selectedIndex = index,
            ),
          ),
        ),
      );

      // Verify all 4 labels are displayed
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Moments'), findsOneWidget);
      expect(find.text('Send'), findsOneWidget);
      expect(find.text('Mood'), findsOneWidget);

      // Verify active home icon
      expect(find.byIcon(Icons.home_rounded), findsOneWidget);
      // Inactive icons
      expect(find.byIcon(Icons.photo_library_outlined), findsOneWidget);
      expect(find.byIcon(Icons.camera_alt_outlined), findsOneWidget);
      expect(find.byIcon(Icons.favorite_outline_rounded), findsOneWidget);
    });

    testWidgets('triggers onTap callback when tapping an inactive item', (
      tester,
    ) async {
      int tappedIndex = -1;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            bottomNavigationBar: GlassBottomNavBar(
              currentIndex: 0,
              onTap: (index) => tappedIndex = index,
            ),
          ),
        ),
      );

      // Tap on 'Moments'
      await tester.tap(find.text('Moments'));
      await tester.pumpAndSettle();
      expect(tappedIndex, equals(1));

      // Tap on 'Send'
      await tester.tap(find.text('Send'));
      await tester.pumpAndSettle();
      expect(tappedIndex, equals(2));

      // Tap on 'Mood'
      await tester.tap(find.text('Mood'));
      await tester.pumpAndSettle();
      expect(tappedIndex, equals(3));
    });
  });
}
