import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/auth_service.dart';
import '../../providers/auth_providers.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/closer_button.dart';
import '../../../../shared/widgets/closer_text_field.dart';

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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Username is already taken.')),
        );
      }
    } on FirebaseAuthException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message ?? 'Unable to register.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
        const SizedBox(height: 40),
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
        CloserButton(
          label: 'Create Account',
          isLoading: _isLoading,
          onPressed: _handleRegister,
        ),
        const SizedBox(height: 16),
        _buildLoginLink(),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildBackButton() {
    return InkWell(
      onTap: () => context.go(AppRoutes.onboarding),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.inputFill,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(
          Icons.arrow_back_ios_new_rounded,
          size: 18,
          color: AppColors.charcoal,
        ),
      ),
    );
  }

  Widget _buildNameField() {
    return CloserTextField(
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
    return CloserTextField(
      hintText: 'Username',
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
    return CloserTextField(
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
    return CloserTextField(
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
    return CloserTextField(
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

  Widget _buildLoginLink() {
    return Center(
      child: TextButton(
        onPressed: () => context.go(AppRoutes.login),
        child: Text.rich(
          TextSpan(
            text: 'Already have an account? ',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
            children: [
              TextSpan(
                text: 'Sign In',
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.dustyRose,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
