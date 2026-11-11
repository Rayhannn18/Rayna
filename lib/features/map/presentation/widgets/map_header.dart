import 'dart:ui';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

/// Floating top bar on the map showing partner connectivity and live sharing status.
class MapHeaderBar extends StatelessWidget {
  const MapHeaderBar({
    super.key,
    required this.paired,
    this.partnerName,
    this.isSharingLocation = false,
    this.isPartnerSharing = false,
  });

  final bool paired;
  final String? partnerName;
  final bool isSharingLocation;
  final bool isPartnerSharing;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.charcoal.withValues(alpha: 0.12),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.white.withValues(alpha: 0.90),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.white.withValues(alpha: 0.95)),
            ),
            child: Row(
              children: [
                // Heart Avatar / Partner Icon
                CircleAvatar(
                  radius: 18,
                  backgroundColor: AppColors.dustyRose.withValues(alpha: 0.16),
                  child: Icon(
                    paired ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    color: AppColors.dustyRose,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),

                // Title & Subtitle Status
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Text(
                            paired
                                ? (partnerName != null ? 'With $partnerName' : 'Couple Space')
                                : 'Rayna Live Location',
                            style: AppTextStyles.labelLarge.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 6),
                          _buildLiveIndicator(),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        paired
                            ? (isPartnerSharing
                                ? 'Your partner is sharing location'
                                : 'Together, even from afar')
                            : 'Connect with your partner to share',
                        style: AppTextStyles.bodySmall.copyWith(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

                // Sharing Indicator Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: isSharingLocation
                        ? AppColors.success.withValues(alpha: 0.14)
                        : AppColors.warmGray.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isSharingLocation
                            ? Icons.my_location_rounded
                            : Icons.location_off_rounded,
                        size: 13,
                        color: isSharingLocation
                            ? AppColors.success
                            : AppColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isSharingLocation ? 'Sharing' : 'Paused',
                        style: AppTextStyles.bodySmall.copyWith(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isSharingLocation
                              ? AppColors.success
                              : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLiveIndicator() {
    return Container(
      width: 7,
      height: 7,
      decoration: BoxDecoration(
        color: paired && isPartnerSharing ? AppColors.success : AppColors.dustyRose,
        shape: BoxShape.circle,
      ),
    );
  }
}

