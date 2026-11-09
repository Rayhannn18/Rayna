import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../pairing/providers/pairing_providers.dart';
import '../../providers/moments_providers.dart';

class SendPhotoPage extends ConsumerStatefulWidget {
  const SendPhotoPage({super.key});

  @override
  ConsumerState<SendPhotoPage> createState() => _SendPhotoPageState();
}

class _SendPhotoPageState extends ConsumerState<SendPhotoPage> {
  final _captionController = TextEditingController();
  Uint8List? _previewBytes;
  bool _isUploading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    setState(() => _errorMessage = null);
    try {
      final picked = await ref
          .read(momentsServiceProvider)
          .pickImage(source: source);
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        setState(() {
          _previewBytes = bytes;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'Unable to access image: $e');
      }
    }
  }

  Future<void> _handleSend() async {
    final pair =
        ref
                .read(currentUserDocumentProvider)
                .valueOrNull
                ?.data()?['activePairId']
            as String?;

    if (pair == null || pair.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pair with your partner first.')),
      );
      return;
    }

    if (_previewBytes == null) {
      setState(() => _errorMessage = 'Please take or pick a photo first.');
      return;
    }

    setState(() {
      _isUploading = true;
      _errorMessage = null;
    });

    try {
      final userData = ref
          .read(currentUserDocumentProvider)
          .valueOrNull
          ?.data();
      final senderName = userData?['displayName'] as String?;

      await ref
          .read(momentsServiceProvider)
          .uploadBytes(
            pairId: pair,
            bytes: _previewBytes!,
            caption: _captionController.text,
            senderDisplayName: senderName,
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Moment shared with your partner!'),
            backgroundColor: AppColors.success,
          ),
        );
        // Clear state & navigate to Moments feed
        setState(() {
          _previewBytes = null;
          _captionController.clear();
        });
        context.go(AppRoutes.moments);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'Upload failed: $e');
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text('Share a Moment', style: AppTextStyles.h3),
        centerTitle: true,
        leading: Navigator.of(context).canPop()
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 110),
        children: [
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
            const SizedBox(height: 18),
          ],

          // ── Photo Preview Box / Placeholder ──────────────────────────────
          if (_previewBytes != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Stack(
                alignment: Alignment.topRight,
                children: [
                  Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(maxHeight: 340),
                    color: AppColors.charcoal,
                    child: Image.memory(_previewBytes!, fit: BoxFit.cover),
                  ),
                  Positioned(
                    top: 12,
                    right: 12,
                    child: CircleAvatar(
                      backgroundColor: Colors.black54,
                      child: IconButton(
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                        tooltip: 'Remove photo',
                        onPressed: _isUploading
                            ? null
                            : () {
                                setState(() {
                                  _previewBytes = null;
                                });
                              },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton.icon(
                  onPressed: _isUploading
                      ? null
                      : () => _pickImage(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt_outlined, size: 18),
                  label: const Text('Retake'),
                ),
                const SizedBox(width: 16),
                TextButton.icon(
                  onPressed: _isUploading
                      ? null
                      : () => _pickImage(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_outlined, size: 18),
                  label: const Text('Pick Other'),
                ),
              ],
            ),
          ] else ...[
            Container(
              height: 240,
              decoration: BoxDecoration(
                color: AppColors.warmGray.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.divider, width: 1.5),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.add_a_photo_outlined,
                    size: 52,
                    color: AppColors.dustyRose.withValues(alpha: 0.7),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Capture or Choose a Photo',
                    style: AppTextStyles.labelLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Photos are private to just the two of you.',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => _pickImage(ImageSource.camera),
                        icon: const Icon(Icons.camera_alt_rounded, size: 18),
                        label: const Text('Camera'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.dustyRose,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      OutlinedButton.icon(
                        onPressed: () => _pickImage(ImageSource.gallery),
                        icon: const Icon(Icons.photo_library_rounded, size: 18),
                        label: const Text('Gallery'),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.dustyRose),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),

          // ── Caption Input ────────────────────────────────────────────────
          Text('Caption (Optional)', style: AppTextStyles.labelLarge),
          const SizedBox(height: 8),
          TextField(
            controller: _captionController,
            maxLength: 500,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Add a sweet note or feeling about this moment...',
              filled: true,
              fillColor: AppColors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: const BorderSide(color: AppColors.divider),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: const BorderSide(color: AppColors.divider),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: const BorderSide(
                  color: AppColors.dustyRose,
                  width: 1.5,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // ── Send Button ──────────────────────────────────────────────────
          ElevatedButton(
            onPressed: (_previewBytes != null && !_isUploading)
                ? _handleSend
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.dustyRose,
              foregroundColor: AppColors.white,
              disabledBackgroundColor: AppColors.dustyRose.withValues(
                alpha: 0.35,
              ),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            child: _isUploading
                ? const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.white,
                        ),
                      ),
                      SizedBox(width: 12),
                      Text('Sharing with your partner...'),
                    ],
                  )
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.favorite_rounded, size: 20),
                      SizedBox(width: 8),
                      Text('Share Moment'),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
