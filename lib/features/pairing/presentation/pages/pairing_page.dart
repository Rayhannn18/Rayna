import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/rayna_button.dart';
import '../../../../shared/widgets/rayna_text_field.dart';
import '../../data/pairing_service.dart';
import '../../providers/pairing_providers.dart';

class PairingPage extends ConsumerStatefulWidget {
  const PairingPage({super.key});

  @override
  ConsumerState<PairingPage> createState() => _PairingPageState();
}

class _PairingPageState extends ConsumerState<PairingPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  // Code Tab controllers
  final _codeController = TextEditingController();
  bool _connectingCode = false;
  bool _generatingCode = false;
  String? _codeError;

  // Username Tab controllers
  final _usernameController = TextEditingController();
  Map<String, dynamic>? _foundUser;
  String? _usernameError;
  bool _searching = false;
  bool _sending = false;
  bool _requestSent = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _codeController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  // ── Pairing Code Actions ─────────────────────────────────────────────────

  Future<void> _generateCode() async {
    setState(() {
      _generatingCode = true;
      _codeError = null;
    });

    try {
      final code = await ref.read(pairingServiceProvider).generatePairingCode();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('New pairing code generated: $code'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } on PairingException catch (e) {
      if (mounted) setState(() => _codeError = e.message);
    } catch (e) {
      if (mounted) setState(() => _codeError = e.toString());
    } finally {
      if (mounted) setState(() => _generatingCode = false);
    }
  }

  Future<void> _connectWithCode() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      setState(() => _codeError = 'Please enter a 6-character code.');
      return;
    }

    setState(() {
      _connectingCode = true;
      _codeError = null;
    });

    try {
      await ref.read(pairingServiceProvider).connectWithPairingCode(code);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Connected! Welcome to your private space.'),
            backgroundColor: AppColors.success,
          ),
        );
        context.go(AppRoutes.home);
      }
    } on PairingException catch (e) {
      if (mounted) setState(() => _codeError = e.message);
    } catch (e) {
      if (mounted) setState(() => _codeError = e.toString());
    } finally {
      if (mounted) setState(() => _connectingCode = false);
    }
  }

  // ── Username Search Actions ──────────────────────────────────────────────

  Future<void> _searchUsername() async {
    final username = _usernameController.text.trim();
    if (username.isEmpty) return;
    setState(() {
      _searching = true;
      _usernameError = null;
      _foundUser = null;
      _requestSent = false;
    });
    try {
      final result = await ref
          .read(pairingServiceProvider)
          .searchUsername(username);
      if (mounted) {
        setState(() {
          _foundUser = result;
          if (result == null) {
            _usernameError = 'No user found with username "@$username".';
          }
        });
      }
    } catch (e) {
      if (mounted) setState(() => _usernameError = e.toString());
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _sendRequest() async {
    final uid = _foundUser?['uid'] as String?;
    if (uid == null) return;
    setState(() {
      _sending = true;
      _usernameError = null;
    });
    try {
      await ref.read(pairingServiceProvider).sendConnectionRequest(uid);
      if (mounted) setState(() => _requestSent = true);
    } on PairingException catch (e) {
      if (mounted) setState(() => _usernameError = e.message);
    } catch (e) {
      if (mounted) setState(() => _usernameError = e.toString());
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final incomingRequests = ref.watch(incomingRequestsProvider);
    final requestCount = incomingRequests.valueOrNull?.docs.length ?? 0;

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              context.go(AppRoutes.home);
            }
          },
        ),
        title: Text('Connect with Partner', style: AppTextStyles.h3),
        centerTitle: true,
        actions: [
          Stack(
            alignment: Alignment.center,
            children: [
              TextButton.icon(
                onPressed: () => context.go(AppRoutes.pendingRequests),
                icon: const Icon(Icons.inbox_rounded, size: 20),
                label: const Text('Requests'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.dustyRose,
                ),
              ),
              if (requestCount > 0)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: AppColors.error,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      '$requestCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.dustyRose,
          labelColor: AppColors.dustyRose,
          unselectedLabelColor: AppColors.textSecondary,
          labelStyle: AppTextStyles.labelLarge,
          tabs: const [
            Tab(text: 'Pairing Code'),
            Tab(text: 'Search Username'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildPairingCodeTab(), _buildSearchUsernameTab()],
      ),
    );
  }

  // ── Tab 1: Pairing Code ──────────────────────────────────────────────────

  Widget _buildPairingCodeTab() {
    final userDoc = ref.watch(currentUserDocumentProvider);
    final currentCode =
        userDoc.valueOrNull?.data()?['pairingCode'] as String? ?? '';

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      children: [
        // ── Card 1: Your Code ──────────────────────────────────────────────
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: const BorderSide(color: AppColors.divider),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.key_rounded,
                      color: AppColors.dustyRose,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Your Unique Pairing Code',
                      style: AppTextStyles.labelLarge,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Share this code with your partner to connect instantly.',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 18),
                if (currentCode.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.dustyRose.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.dustyRose.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Text(
                      currentCode.split('').join('  '),
                      style: AppTextStyles.h1.copyWith(
                        color: AppColors.dustyRose,
                        letterSpacing: 4,
                        fontSize: 28,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: currentCode));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Pairing code copied to clipboard!',
                              ),
                              backgroundColor: AppColors.success,
                            ),
                          );
                        },
                        icon: const Icon(Icons.copy_rounded, size: 18),
                        label: const Text('Copy Code'),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.dustyRose),
                        ),
                      ),
                      const SizedBox(width: 12),
                      TextButton.icon(
                        onPressed: _generatingCode ? null : _generateCode,
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text('New Code'),
                      ),
                    ],
                  ),
                ] else ...[
                  RaynaButton(
                    label: 'Generate Pairing Code',
                    icon: Icons.auto_awesome_rounded,
                    isLoading: _generatingCode,
                    onPressed: _generateCode,
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 28),

        // ── Card 2: Enter Partner Code ─────────────────────────────────────
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: const BorderSide(color: AppColors.divider),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.favorite_rounded,
                      color: AppColors.dustyRose,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "Enter Partner's Code",
                      style: AppTextStyles.labelLarge,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Paste or type the 6-character code your partner sent you.',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _codeController,
                  textCapitalization: TextCapitalization.characters,
                  maxLength: 6,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.h2.copyWith(
                    letterSpacing: 6,
                    color: AppColors.charcoal,
                  ),
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: 'e.g. 7X9K2P',
                    hintStyle: TextStyle(
                      letterSpacing: 2,
                      color: AppColors.textHint.withValues(alpha: 0.6),
                      fontSize: 18,
                    ),
                    filled: true,
                    fillColor: AppColors.inputFill,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: AppColors.divider),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(
                        color: AppColors.dustyRose,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
                if (_codeError != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    _codeError!,
                    style: const TextStyle(
                      color: AppColors.error,
                      fontSize: 13,
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                RaynaButton(
                  label: 'Connect with Partner',
                  icon: Icons.link_rounded,
                  isLoading: _connectingCode,
                  onPressed: _connectWithCode,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Tab 2: Search Username ───────────────────────────────────────────────

  Widget _buildSearchUsernameTab() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      children: [
        Text('Find by Username', style: AppTextStyles.h2),
        const SizedBox(height: 6),
        Text(
          'Search for your partner by their unique @username.',
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 20),
        RaynaTextField(
          hintText: 'Enter username (e.g. alexa)',
          controller: _usernameController,
          prefixIcon: const Icon(Icons.alternate_email_rounded),
          textInputAction: TextInputAction.search,
          onChanged: (_) => setState(() {
            _usernameError = null;
            _foundUser = null;
            _requestSent = false;
          }),
        ),
        const SizedBox(height: 14),
        RaynaButton(
          label: 'Search User',
          icon: Icons.search_rounded,
          isLoading: _searching,
          onPressed: _searchUsername,
        ),
        if (_usernameError != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  color: AppColors.error,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _usernameError!,
                    style: const TextStyle(
                      color: AppColors.error,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        if (_foundUser != null) ...[
          const SizedBox(height: 24),
          _UserCard(
            displayName: _foundUser!['displayName'] as String? ?? '',
            username: _foundUser!['username'] as String? ?? '',
            requestSent: _requestSent,
            sending: _sending,
            onSendRequest: _sendRequest,
          ),
        ],
      ],
    );
  }
}

class _UserCard extends StatelessWidget {
  const _UserCard({
    required this.displayName,
    required this.username,
    required this.requestSent,
    required this.sending,
    required this.onSendRequest,
  });

  final String displayName;
  final String username;
  final bool requestSent;
  final bool sending;
  final VoidCallback onSendRequest;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.softSage.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.softSage),
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 34,
            backgroundColor: AppColors.dustyRose.withValues(alpha: 0.2),
            child: Text(
              displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
              style: AppTextStyles.h1.copyWith(
                color: AppColors.dustyRose,
                fontSize: 26,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(displayName, style: AppTextStyles.h3),
          const SizedBox(height: 2),
          Text(
            '@$username',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 18),
          if (requestSent)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.check_circle_rounded,
                    color: AppColors.success,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Connection Request Sent!',
                    style: AppTextStyles.labelMedium.copyWith(
                      color: AppColors.success,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            )
          else
            RaynaButton(
              label: 'Send Connection Request',
              icon: Icons.favorite_outline_rounded,
              isLoading: sending,
              onPressed: onSendRequest,
            ),
        ],
      ),
    );
  }
}
