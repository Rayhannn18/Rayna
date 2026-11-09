import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:rayna_app/app.dart';

void main() {
  testWidgets('Rayna app renders onboarding page', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: RaynaApp()));

    // The onboarding page should show the app name and entry buttons.
    expect(find.text('Rayna'), findsOneWidget);
    expect(find.text('Get Started'), findsOneWidget);
    expect(find.text('I already have an account'), findsOneWidget);
  });
}
