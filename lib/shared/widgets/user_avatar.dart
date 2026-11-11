import 'dart:convert';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

/// Reusable circular avatar widget for users and partners in Rayna.
/// Supports both network URLs, data URIs (base64 fallback), and initials.
class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    this.photoUrl,
    required this.name,
    this.radius = 24.0,
    this.borderColor,
    this.borderWidth = 0.0,
    this.backgroundColor,
  });

  final String? photoUrl;
  final String name;
  final double radius;
  final Color? borderColor;
  final double borderWidth;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final effectiveBgColor = backgroundColor ??
        (borderColor != null
            ? borderColor!.withValues(alpha: 0.15)
            : AppColors.dustyRose.withValues(alpha: 0.15));

    final initial = name.isNotEmpty
        ? name.substring(0, 1).toUpperCase()
        : '♥';

    Widget avatarContent;

    if (photoUrl != null && photoUrl!.isNotEmpty) {
      if (photoUrl!.startsWith('data:image')) {
        try {
          final commaIndex = photoUrl!.indexOf(',');
          final base64Str =
              commaIndex != -1 ? photoUrl!.substring(commaIndex + 1) : photoUrl!;
          final bytes = base64Decode(base64Str);
          avatarContent = Image.memory(
            bytes,
            fit: BoxFit.cover,
            width: radius * 2,
            height: radius * 2,
            errorBuilder: (_, _, _) => _buildInitials(initial),
          );
        } catch (_) {
          avatarContent = _buildInitials(initial);
        }
      } else {
        avatarContent = Image.network(
          photoUrl!,
          fit: BoxFit.cover,
          width: radius * 2,
          height: radius * 2,
          errorBuilder: (_, _, _) => _buildInitials(initial),
        );
      }
    } else {
      avatarContent = _buildInitials(initial);
    }

    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: effectiveBgColor,
        border: borderWidth > 0 && borderColor != null
            ? Border.all(color: borderColor!, width: borderWidth)
            : null,
      ),
      child: ClipOval(child: avatarContent),
    );
  }

  Widget _buildInitials(String initial) {
    return Center(
      child: Text(
        initial,
        style: AppTextStyles.h2.copyWith(
          color: borderColor ?? AppColors.dustyRose,
          fontSize: radius * 0.85,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

