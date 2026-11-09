import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/onboarding_page.dart';
import '../../features/auth/presentation/pages/register_page.dart';
import '../../features/home/presentation/pages/home_page.dart';
import '../../features/home/presentation/widgets/main_shell_scaffold.dart';
import '../../features/messages/presentation/pages/chat_page.dart';
import '../../features/moments/presentation/pages/moment_detail_page.dart';
import '../../features/moments/presentation/pages/moments_page.dart';
import '../../features/moments/presentation/pages/send_photo_page.dart';
import '../../features/mood/presentation/pages/mood_page.dart';
import '../../features/notifications/presentation/pages/notification_settings_page.dart';
import '../../features/pairing/presentation/pages/pairing_page.dart';
import '../../features/pairing/presentation/pages/pending_requests_page.dart';
import '../../features/profile/presentation/pages/edit_profile_page.dart';
import '../../features/profile/presentation/pages/profile_page.dart';

/// Named route paths used throughout the app.
class AppRoutes {
  AppRoutes._();

  static const String onboarding = '/onboarding';
  static const String login = '/login';
  static const String register = '/register';
  static const String home = '/';
  static const String profile = '/profile';
  static const String editProfile = '/profile/edit';
  static const String pairing = '/pairing';
  static const String pendingRequests = '/pending-requests';
  static const String moments = '/moments';
  static const String sendPhoto = '/send';
  static const String momentDetail = '/moments/:momentId';
  static const String mood = '/mood';
  static const String chat = '/chat';
  static const String notificationSettings = '/notification-settings';
}

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'root',
);

/// Application router configuration with StatefulShellRoute for glass navigation.
final GoRouter appRouter = GoRouter(
  navigatorKey: rootNavigatorKey,
  initialLocation: AppRoutes.onboarding,
  debugLogDiagnostics: true,
  redirect: (BuildContext context, GoRouterState state) {
    if (Firebase.apps.isEmpty) return null;

    final isSignedIn = FirebaseAuth.instance.currentUser != null;
    final isAuthRoute =
        state.matchedLocation == AppRoutes.onboarding ||
        state.matchedLocation == AppRoutes.login ||
        state.matchedLocation == AppRoutes.register;

    if (isSignedIn && isAuthRoute) return AppRoutes.home;
    if (!isSignedIn && !isAuthRoute) {
      return AppRoutes.onboarding;
    }
    return null;
  },
  routes: <RouteBase>[
    // ── Primary 4-Tab Shell with Floating Glass Bottom Navigation Bar ───────
    StatefulShellRoute.indexedStack(
      builder:
          (
            BuildContext context,
            GoRouterState state,
            StatefulNavigationShell navigationShell,
          ) {
            return MainShellScaffold(navigationShell: navigationShell);
          },
      branches: <StatefulShellBranch>[
        // Tab 0: Home Dashboard
        StatefulShellBranch(
          routes: <RouteBase>[
            GoRoute(
              path: AppRoutes.home,
              name: 'home',
              builder: (BuildContext context, GoRouterState state) =>
                  const HomePage(),
            ),
          ],
        ),

        // Tab 1: Shared Moments
        StatefulShellBranch(
          routes: <RouteBase>[
            GoRoute(
              path: AppRoutes.moments,
              name: 'moments',
              builder: (BuildContext context, GoRouterState state) =>
                  const MomentsPage(),
            ),
          ],
        ),

        // Tab 2: Send Photo
        StatefulShellBranch(
          routes: <RouteBase>[
            GoRoute(
              path: AppRoutes.sendPhoto,
              name: 'sendPhoto',
              builder: (BuildContext context, GoRouterState state) =>
                  const SendPhotoPage(),
            ),
          ],
        ),

        // Tab 3: Mood Tracker
        StatefulShellBranch(
          routes: <RouteBase>[
            GoRoute(
              path: AppRoutes.mood,
              name: 'mood',
              builder: (BuildContext context, GoRouterState state) =>
                  const MoodPage(),
            ),
          ],
        ),
      ],
    ),

    // ── Full-screen Authentication Routes ──────────────────────────────────
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: AppRoutes.onboarding,
      name: 'onboarding',
      builder: (BuildContext context, GoRouterState state) =>
          const OnboardingPage(),
    ),
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: AppRoutes.login,
      name: 'login',
      builder: (BuildContext context, GoRouterState state) => const LoginPage(),
    ),
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: AppRoutes.register,
      name: 'register',
      builder: (BuildContext context, GoRouterState state) =>
          const RegisterPage(),
    ),

    // ── Full-screen Secondary & Detail Routes ──────────────────────────────
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: AppRoutes.profile,
      name: 'profile',
      builder: (BuildContext context, GoRouterState state) =>
          const ProfilePage(),
    ),
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: AppRoutes.editProfile,
      name: 'editProfile',
      builder: (BuildContext context, GoRouterState state) =>
          const EditProfilePage(),
    ),
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: AppRoutes.pairing,
      name: 'pairing',
      builder: (BuildContext context, GoRouterState state) =>
          const PairingPage(),
    ),
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: AppRoutes.pendingRequests,
      name: 'pendingRequests',
      builder: (BuildContext context, GoRouterState state) =>
          const PendingRequestsPage(),
    ),
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: AppRoutes.momentDetail,
      name: 'momentDetail',
      builder: (BuildContext context, GoRouterState state) {
        final momentId = state.pathParameters['momentId']!;
        return MomentDetailPage(momentId: momentId);
      },
    ),
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: AppRoutes.chat,
      name: 'chat',
      builder: (BuildContext context, GoRouterState state) => const ChatPage(),
    ),
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: AppRoutes.notificationSettings,
      name: 'notificationSettings',
      builder: (BuildContext context, GoRouterState state) =>
          const NotificationSettingsPage(),
    ),
  ],
);
