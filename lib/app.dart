import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/providers/auth_providers.dart';
import 'core/notifications/notification_providers.dart';

/// Root widget of the Rayna application.
class RaynaApp extends ConsumerWidget {
  const RaynaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(authStateProvider, (previous, next) {
      appRouter.refresh();
      if (next.value != null) {
        ref.read(notificationServiceProvider).initialize();
      }
    });

    return MaterialApp.router(
      title: 'Rayna',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: appRouter,
    );
  }
}

/// Backward compatibility alias for [RaynaApp].
typedef CloserApp = RaynaApp;
