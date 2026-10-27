import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/onboarding_page.dart';
import '../../features/auth/presentation/pages/register_page.dart';
import '../../features/home/presentation/pages/home_page.dart';
import '../../features/profile/presentation/pages/profile_page.dart';
import '../../features/pairing/presentation/pages/pairing_page.dart';
import '../../features/moments/presentation/pages/moments_page.dart';
import '../../features/mood/presentation/pages/mood_page.dart';
import '../../features/messages/presentation/pages/messages_page.dart';

/// Named route paths used throughout the app.
class AppRoutes {
  AppRoutes._();

  static const String onboarding = '/onboarding';
  static const String login = '/login';
  static const String register = '/register';
  static const String home = '/';
  static const String profile = '/profile';
  static const String pairing = '/pairing';
  static const String moments = '/moments';
  static const String mood = '/mood';
  static const String messages = '/messages';
}

/// Application router configuration.
///
/// Initial location is [AppRoutes.onboarding] because Firebase Auth is not
/// configured yet. Once auth is wired up, the initial route will be determined
/// dynamically based on auth state.
final GoRouter appRouter = GoRouter(
  initialLocation: AppRoutes.onboarding,
  debugLogDiagnostics: true,
  redirect: (BuildContext context, GoRouterState state) {
    // Firebase Web is intentionally skipped until Web credentials are added.
    if (Firebase.apps.isEmpty) return null;

    final isSignedIn = FirebaseAuth.instance.currentUser != null;
    final isAuthRoute =
        state.matchedLocation == AppRoutes.onboarding ||
        state.matchedLocation == AppRoutes.login ||
        state.matchedLocation == AppRoutes.register;

    if (isSignedIn && isAuthRoute) return AppRoutes.home;
    if (!isSignedIn && state.matchedLocation == AppRoutes.home) {
      return AppRoutes.onboarding;
    }
    return null;
  },
  routes: <RouteBase>[
    GoRoute(
      path: AppRoutes.onboarding,
      name: 'onboarding',
      builder: (BuildContext context, GoRouterState state) =>
          const OnboardingPage(),
    ),
    GoRoute(
      path: AppRoutes.login,
      name: 'login',
      builder: (BuildContext context, GoRouterState state) => const LoginPage(),
    ),
    GoRoute(
      path: AppRoutes.register,
      name: 'register',
      builder: (BuildContext context, GoRouterState state) =>
          const RegisterPage(),
    ),
    GoRoute(
      path: AppRoutes.home,
      name: 'home',
      builder: (BuildContext context, GoRouterState state) => const HomePage(),
    ),
    GoRoute(
      path: AppRoutes.profile,
      name: 'profile',
      builder: (BuildContext context, GoRouterState state) =>
          const ProfilePage(),
    ),
    GoRoute(
      path: AppRoutes.pairing,
      name: 'pairing',
      builder: (BuildContext context, GoRouterState state) =>
          const PairingPage(),
    ),
    GoRoute(
      path: AppRoutes.moments,
      name: 'moments',
      builder: (_, __) => const MomentsPage(),
    ),
    GoRoute(
      path: AppRoutes.mood,
      name: 'mood',
      builder: (_, __) => const MoodPage(),
    ),
    GoRoute(
      path: AppRoutes.messages,
      name: 'messages',
      builder: (_, __) => const MessagesPage(),
    ),
  ],
);
