import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/auth_service.dart';
import '../../providers/auth_providers.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/rayna_button.dart';
import '../../../../shared/widgets/rayna_text_field.dart';

class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtl = TextEditingController();
  final _usernameCtl = TextEditingController();
  final _emailCtl = TextEditingController();
  final _passCtl = TextEditingController();
  final _confirmCtl = TextEditingController();
  bool _obscurePass = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameCtl.dispose();
    _usernameCtl.dispose();
    _emailCtl.dispose();
    _passCtl.dispose();
    _confirmCtl.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    setState(() => _errorMessage = null);
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      await ref
          .read(authServiceProvider)
          .register(
            displayName: _nameCtl.text,
            username: _usernameCtl.text,
            email: _emailCtl.text,
            password: _passCtl.text,
          );
      if (mounted) context.go(AppRoutes.home);
    } on UsernameAlreadyTakenException {
      if (mounted) {
        setState(() {
          _errorMessage =
              'Username "@${_usernameCtl.text.trim()}" is already taken. Please choose another.';
        });
      }
    } on FirebaseAuthException catch (error) {
      if (mounted) {
        setState(() {
          _errorMessage = _authErrorMessage(error);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Registration could not be completed: $e';
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _authErrorMessage(FirebaseAuthException error) {
    switch (error.code) {
      case 'email-already-in-use':
        return 'An account with this email address already exists.';
      case 'invalid-email':
        return 'The email address is badly formatted.';
      case 'weak-password':
        return 'Password is too weak. Please use a stronger password.';
      case 'operation-not-allowed':
        return 'Email/password registration is not enabled in Firebase.';
      default:
        return error.message ?? 'Registration failed. Please try again.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Form(key: _formKey, child: _buildFormColumn()),
        ),
      ),
    );
  }

  Column _buildFormColumn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        _buildBackButton(),
        const SizedBox(height: 32),
        Text('Create account', style: AppTextStyles.h2),
        const SizedBox(height: 8),
        Text(
          'Start your journey to feel closer.',
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 28),
        if (_errorMessage != null) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppColors.error.withValues(alpha: 0.25),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  color: AppColors.error,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _errorMessage!,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.error,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
        _buildNameField(),
        const SizedBox(height: 16),
        _buildUsernameField(),
        const SizedBox(height: 16),
        _buildEmailField(),
        const SizedBox(height: 16),
        _buildPasswordField(),
        const SizedBox(height: 16),
        _buildConfirmField(),
        const SizedBox(height: 32),
        RaynaButton(
          label: 'Create Account',
          isLoading: _isLoading,
          onPressed: _handleRegister,
        ),
        const SizedBox(height: 16),
        Center(
          child: TextButton(
            onPressed: () => context.go(AppRoutes.login),
            child: Text.rich(
              TextSpan(
                text: 'Already have an account? ',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
                children: [
                  TextSpan(
                    text: 'Sign In',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.dustyRose,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildBackButton() {
    return IconButton(
      onPressed: () => context.go(AppRoutes.onboarding),
      icon: const Icon(Icons.arrow_back_rounded),
      tooltip: 'Back',
    );
  }

  Widget _buildNameField() {
    return RaynaTextField(
      hintText: 'Display Name',
      controller: _nameCtl,
      keyboardType: TextInputType.name,
      textInputAction: TextInputAction.next,
      prefixIcon: const Icon(Icons.person_outline_rounded, size: 20),
      validator: (v) {
        if (v == null || v.trim().isEmpty) return 'Display name is required.';
        if (v.trim().length < 2) return 'Must be at least 2 characters.';
        return null;
      },
    );
  }

  Widget _buildUsernameField() {
    return RaynaTextField(
      hintText: 'Unique Username (e.g. alexa)',
      controller: _usernameCtl,
      textInputAction: TextInputAction.next,
      prefixIcon: const Icon(Icons.alternate_email_rounded, size: 20),
      validator: (value) {
        final username = value?.trim() ?? '';
        if (username.isEmpty) return 'Username is required.';
        if (!RegExp(r'^[a-zA-Z0-9_.]{3,20}$').hasMatch(username)) {
          return 'Use 3–20 letters, numbers, dots, or underscores.';
        }
        return null;
      },
    );
  }

  Widget _buildEmailField() {
    return RaynaTextField(
      hintText: 'Email',
      controller: _emailCtl,
      keyboardType: TextInputType.emailAddress,
      textInputAction: TextInputAction.next,
      prefixIcon: const Icon(Icons.email_outlined, size: 20),
      validator: (v) {
        if (v == null || v.trim().isEmpty) return 'Email is required.';
        final re = RegExp(r'^[\w\.\-]+@[\w\-]+\.\w{2,}$');
        if (!re.hasMatch(v.trim())) return 'Enter a valid email.';
        return null;
      },
    );
  }

  Widget _buildPasswordField() {
    return RaynaTextField(
      hintText: 'Password',
      controller: _passCtl,
      obscureText: _obscurePass,
      textInputAction: TextInputAction.next,
      prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
      suffixIcon: IconButton(
        icon: Icon(
          _obscurePass
              ? Icons.visibility_off_outlined
              : Icons.visibility_outlined,
          size: 20,
        ),
        onPressed: () => setState(() => _obscurePass = !_obscurePass),
      ),
      validator: (v) {
        if (v == null || v.isEmpty) return 'Password is required.';
        if (v.length < 6) return 'Must be at least 6 characters.';
        return null;
      },
    );
  }

  Widget _buildConfirmField() {
    return RaynaTextField(
      hintText: 'Confirm Password',
      controller: _confirmCtl,
      obscureText: _obscureConfirm,
      textInputAction: TextInputAction.done,
      prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
      suffixIcon: IconButton(
        icon: Icon(
          _obscureConfirm
              ? Icons.visibility_off_outlined
              : Icons.visibility_outlined,
          size: 20,
        ),
        onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
      ),
      validator: (v) {
        if (v == null || v.isEmpty) return 'Please confirm your password.';
        if (v != _passCtl.text) return 'Passwords do not match.';
        return null;
      },
    );
  }
}
