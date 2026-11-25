import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/notifications/notification_providers.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/providers/auth_providers.dart';

/// Custom root back-button dispatcher that intercepts every Android system Back
/// press before GoRouter's shell/branch dispatchers can prematurely close the app.
class _RaynaBackButtonDispatcher extends RootBackButtonDispatcher {
  _RaynaBackButtonDispatcher(this.router);

  final GoRouter router;
  DateTime? _lastBackPressedAt;

  @override
  Future<bool> didPopRoute() async {
    // 1. Pop any active dialog, bottom sheet, or pushed route on the root navigator.
    final rootNav = rootNavigatorKey.currentState;
    if (rootNav != null && rootNav.canPop()) {
      await rootNav.maybePop();
      return true;
    }

    // 2. Pop GoRouter's own stack if available.
    if (router.canPop()) {
      router.pop();
      return true;
    }

    // 3. Navigate back to parent/home screen instead of closing the app.
    final location = router.routerDelegate.currentConfiguration.uri.path;
    if (location == AppRoutes.login || location == AppRoutes.register) {
      router.go(AppRoutes.onboarding);
      return true;
    }
    if (location != AppRoutes.home && location != AppRoutes.onboarding) {
      router.go(AppRoutes.home);
      return true;
    }

    // 4. On root Home/Onboarding screen, require double-back within 2 seconds to exit.
    final now = DateTime.now();
    if (_lastBackPressedAt == null ||
        now.difference(_lastBackPressedAt!) > const Duration(seconds: 2)) {
      _lastBackPressedAt = now;
      final ctx = rootNavigatorKey.currentContext;
      if (ctx != null && ctx.mounted) {
        ScaffoldMessenger.of(ctx)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text('Tekan sekali lagi untuk keluar aplikasi'),
              duration: Duration(seconds: 2),
            ),
          );
      }
      return true;
    }

    return false;
  }
}

final _raynaBackButtonDispatcher = _RaynaBackButtonDispatcher(appRouter);

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
      routeInformationProvider: appRouter.routeInformationProvider,
      routeInformationParser: appRouter.routeInformationParser,
      routerDelegate: appRouter.routerDelegate,
      backButtonDispatcher: _raynaBackButtonDispatcher,
    );
  }
}

/// Backward compatibility alias for [RaynaApp].
typedef CloserApp = RaynaApp;
