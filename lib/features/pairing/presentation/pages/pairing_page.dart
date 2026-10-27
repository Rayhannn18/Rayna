import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/closer_button.dart';
import '../../../../shared/widgets/closer_text_field.dart';
import '../../data/pairing_service.dart';
import '../../providers/pairing_providers.dart';

class PairingPage extends ConsumerStatefulWidget {
  const PairingPage({super.key});

  @override
  ConsumerState<PairingPage> createState() => _PairingPageState();
}

class _PairingPageState extends ConsumerState<PairingPage> {
  final _codeController = TextEditingController();
  String? _myCode;
  String? _error;
  bool _loading = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _createCode() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final code = await ref.read(pairingServiceProvider).createPairingCode();
      if (mounted) setState(() => _myCode = code);
    } catch (error) {
      if (mounted) setState(() => _error = _message(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _join() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(pairingServiceProvider).joinPair(_codeController.text);
      if (mounted) context.go(AppRoutes.home);
    } catch (error) {
      if (mounted) setState(() => _error = _message(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _message(Object error) {
    if (error is PairingException) return error.message;
    if (error is FirebaseException && error.code == 'unavailable') {
      return 'Connection to Firebase was interrupted. Please try again.';
    }
    return error.toString().replaceFirst('Exception: ', '');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go(AppRoutes.home),
        ),
        title: Text('Find your partner', style: AppTextStyles.h3),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text('Connect with your person', style: AppTextStyles.h2),
          const SizedBox(height: 8),
          Text(
            'Share a code with your partner to create your private space together.',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 32),
          _CodeCard(code: _myCode),
          const SizedBox(height: 16),
          CloserButton(
            label: _myCode == null ? 'Generate my code' : 'Refresh code',
            icon: Icons.key_rounded,
            isLoading: _loading,
            onPressed: _createCode,
          ),
          const SizedBox(height: 32),
          const Divider(),
          const SizedBox(height: 24),
          Text('Have a partner code?', style: AppTextStyles.h3),
          const SizedBox(height: 12),
          CloserTextField(
            hintText: '6-character code',
            controller: _codeController,
            textCapitalization: TextCapitalization.characters,
            prefixIcon: const Icon(Icons.link_rounded),
            onChanged: (_) => setState(() => _error = null),
          ),
          const SizedBox(height: 16),
          CloserButton(
            label: 'Join partner',
            outlined: true,
            isLoading: _loading,
            onPressed: _join,
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(_error!, style: const TextStyle(color: AppColors.error)),
          ],
        ],
      ),
    );
  }
}

class _CodeCard extends StatelessWidget {
  const _CodeCard({required this.code});
  final String? code;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.softSage,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Text('Your pairing code', style: AppTextStyles.bodyMedium),
          const SizedBox(height: 12),
          Text(
            code ?? '------',
            style: AppTextStyles.h1.copyWith(letterSpacing: 5),
          ),
          const SizedBox(height: 8),
          Text('Share this code privately.', style: AppTextStyles.caption),
        ],
      ),
    );
  }
}
