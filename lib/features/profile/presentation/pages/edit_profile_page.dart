import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/rayna_button.dart';
import '../../../../shared/widgets/rayna_text_field.dart';
import '../../../../shared/widgets/user_avatar.dart';
import '../../../auth/providers/auth_providers.dart';
import '../../../pairing/providers/pairing_providers.dart';

/// Page allowing the authenticated user to edit their profile details and photo.
class EditProfilePage extends ConsumerStatefulWidget {
  const EditProfilePage({super.key});

  @override
  ConsumerState<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends ConsumerState<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();

  late final TextEditingController _nameController;
  late final TextEditingController _bioController;

  Uint8List? _newAvatarBytes;
  String? _currentPhotoUrl;
  bool _removePhoto = false;

  bool _isLoading = false;
  bool _initialized = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _bioController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  void _populateInitialData(Map<String, dynamic> data) {
    if (!_initialized) {
      _nameController.text = data['displayName'] as String? ?? '';
      _bioController.text = data['bio'] as String? ?? '';
      _currentPhotoUrl = data['photoURL'] as String?;
      _initialized = true;
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 75,
      );
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        setState(() {
          _newAvatarBytes = bytes;
          _removePhoto = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to select image: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _showPhotoOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text(
                'Change Profile Photo',
                style: AppTextStyles.h3.copyWith(fontSize: 18),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: AppColors.softIvory,
                  child: Icon(Icons.camera_alt_outlined, color: AppColors.dustyRose),
                ),
                title: const Text('Take a Photo'),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: AppColors.softIvory,
                  child: Icon(Icons.photo_library_outlined, color: AppColors.dustyRose),
                ),
                title: const Text('Choose from Gallery'),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.gallery);
                },
              ),
              if (_newAvatarBytes != null ||
                  (_currentPhotoUrl != null && !_removePhoto))
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.error.withValues(alpha: 0.12),
                    child: const Icon(Icons.delete_outline_rounded,
                        color: AppColors.error),
                  ),
                  title: const Text(
                    'Remove Photo',
                    style: TextStyle(color: AppColors.error),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    setState(() {
                      _newAvatarBytes = null;
                      _removePhoto = true;
                    });
                  },
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleSave() async {
    setState(() => _errorMessage = null);
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final authService = ref.read(authServiceProvider);
      String? uploadedPhotoUrl;

      // 1. Upload new avatar if selected
      if (_newAvatarBytes != null) {
        uploadedPhotoUrl =
            await authService.uploadProfilePhoto(_newAvatarBytes!);
      }

      // 2. Update profile document in Firestore and FirebaseAuth
      await authService.updateProfile(
        displayName: _nameController.text.trim(),
        bio: _bioController.text.trim(),
        photoUrl: uploadedPhotoUrl,
        removePhoto: _removePhoto,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
        if (context.canPop()) {
          context.pop();
        } else {
          context.go(AppRoutes.profile);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to update profile: $e';
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final userDoc = ref.watch(currentUserDocumentProvider);
    final data = userDoc.valueOrNull?.data() ?? <String, dynamic>{};
    _populateInitialData(data);

    final username = data['username'] as String? ?? '';
    final displayName = _nameController.text.trim();

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        title: Text('Edit Profile', style: AppTextStyles.h3),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(AppRoutes.profile);
            }
          },
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 12),

                // ── Interactive Profile Avatar with Camera Badge ───────────
                Center(
                  child: Stack(
                    children: [
                      GestureDetector(
                        onTap: _showPhotoOptions,
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.dustyRose.withValues(alpha: 0.35),
                              width: 3,
                            ),
                          ),
                          child: _newAvatarBytes != null
                              ? ClipOval(
                                  child: Image.memory(
                                    _newAvatarBytes!,
                                    width: 100,
                                    height: 100,
                                    fit: BoxFit.cover,
                                  ),
                                )
                              : UserAvatar(
                                  photoUrl:
                                      _removePhoto ? null : _currentPhotoUrl,
                                  name: displayName.isNotEmpty
                                      ? displayName
                                      : 'You',
                                  radius: 50,
                                ),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: _showPhotoOptions,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.dustyRose,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white,
                                width: 2.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.15),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.camera_alt_rounded,
                              size: 18,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: _showPhotoOptions,
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('Change Photo'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.dustyRose,
                    textStyle: AppTextStyles.labelMedium,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '@$username',
                  style: AppTextStyles.labelMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 24),

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

                // ── Form Fields ────────────────────────────────────────────
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Display Name', style: AppTextStyles.labelLarge),
                ),
                const SizedBox(height: 8),
                RaynaTextField(
                  hintText: 'Your display name',
                  controller: _nameController,
                  prefixIcon: const Icon(Icons.badge_outlined, size: 20),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Display name is required.';
                    }
                    if (v.trim().length < 2) {
                      return 'Must be at least 2 characters.';
                    }
                    if (v.trim().length > 30) {
                      return 'Must be at most 30 characters.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Bio (Optional)', style: AppTextStyles.labelLarge),
                ),
                const SizedBox(height: 8),
                RaynaTextField(
                  hintText: 'Share a sweet note with your partner...',
                  controller: _bioController,
                  maxLines: 3,
                  prefixIcon: const Icon(Icons.notes_rounded, size: 20),
                  validator: (v) {
                    if (v != null && v.trim().length > 160) {
                      return 'Bio must be at most 160 characters.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 32),

                // ── Save Button ────────────────────────────────────────────
                RaynaButton(
                  label: 'Save Changes',
                  onPressed: _handleSave,
                  isLoading: _isLoading,
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
