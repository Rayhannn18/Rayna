import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/closer_button.dart';

/// Onboarding page — the first screen users see.
///
/// Introduces the Closer concept and provides entry points to login /
/// register.
class OnboardingPage extends StatelessWidget {
  const OnboardingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 32),

              // ── Illustration placeholder ────────────────────────────
              Container(
                width: size.width * 0.42,
                height: size.width * 0.42,
                decoration: BoxDecoration(
                  color: AppColors.warmGray.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.favorite_rounded,
                  size: 64,
                  color: AppColors.dustyRose,
                ),
              ),

              const SizedBox(height: 40),

              // ── Title ───────────────────────────────────────────────
              Text(
                'Closer',
                style: AppTextStyles.h1.copyWith(
                  color: AppColors.dustyRose,
                  fontSize: 40,
                  letterSpacing: -0.5,
                ),
              ),

              const SizedBox(height: 12),

              // ── Subtitle ────────────────────────────────────────────
              Text(
                'Feel close, even when you\'re far apart.',
                style: AppTextStyles.bodyLarge.copyWith(
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 48),

              // ── Buttons ─────────────────────────────────────────────
              CloserButton(
                label: 'Get Started',
                onPressed: () => context.go(AppRoutes.register),
              ),

              const SizedBox(height: 12),

              CloserButton(
                label: 'I already have an account',
                outlined: true,
                onPressed: () => context.go(AppRoutes.login),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
