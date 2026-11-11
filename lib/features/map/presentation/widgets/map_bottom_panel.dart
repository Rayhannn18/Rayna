import 'dart:ui';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

/// Floating bottom information panel displaying live distance and battery status
/// for both partners in an ultra-clean, compact card.
class MapBottomInfoPanel extends StatelessWidget {
  const MapBottomInfoPanel({
    super.key,
    required this.paired,
    this.partnerName,
    this.distanceKm,
    this.partnerBatteryLevel,
    this.isPartnerCharging = false,
    this.myBatteryLevel,
    this.isMyCharging = false,
    this.lastLocationUpdate,
    this.isSharingLocation = true,
    this.isSharingBattery = true,
    this.onToggleLocationSharing,
    this.onToggleBatterySharing,
    required this.onConnectPartner,
  });

  final bool paired;
  final String? partnerName;
  final double? distanceKm;
  final int? partnerBatteryLevel;
  final bool isPartnerCharging;
  final int? myBatteryLevel;
  final bool isMyCharging;
  final String? lastLocationUpdate;
  final bool isSharingLocation;
  final bool isSharingBattery;
  final VoidCallback? onToggleLocationSharing;
  final VoidCallback? onToggleBatterySharing;
  final VoidCallback onConnectPartner;

  @override
  Widget build(BuildContext context) {
    if (!paired) {
      return _buildUnpairedCard(context);
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.charcoal.withValues(alpha: 0.10),
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
              color: AppColors.white.withValues(alpha: 0.94),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.white.withValues(alpha: 0.95)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Top Row: Distance & Partner Header ────────────────────────
                Row(
                  children: [
                    CircleAvatar(
                      radius: 17,
                      backgroundColor: AppColors.dustyRose.withValues(alpha: 0.18),
                      child: Text(
                        (partnerName?.isNotEmpty == true ? partnerName![0] : 'P')
                            .toUpperCase(),
                        style: AppTextStyles.h3.copyWith(
                          color: AppColors.dustyRose,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            partnerName ?? 'Partner',
                            style: AppTextStyles.labelLarge.copyWith(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            lastLocationUpdate != null
                                ? 'Updated $lastLocationUpdate'
                                : 'Awaiting live signal',
                            style: AppTextStyles.bodySmall.copyWith(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Distance Pill
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.dustyRose.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: AppColors.dustyRose.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.near_me_rounded,
                            size: 13,
                            color: AppColors.dustyRose,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            distanceKm != null
                                ? '${distanceKm!.toStringAsFixed(1)} km'
                                : '-- km',
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.dustyRose,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                const Divider(height: 1, color: AppColors.divider),
                const SizedBox(height: 8),

                // ── Bottom Row: Battery Statuses ─────────────────────────────
                Row(
                  children: [
                    // Partner Battery
                    Expanded(
                      child: _buildBatteryTile(
                        label: partnerName ?? 'Partner',
                        level: partnerBatteryLevel,
                        isCharging: isPartnerCharging,
                        isPartner: true,
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 28,
                      color: AppColors.divider.withValues(alpha: 0.8),
                    ),
                    // My Battery
                    Expanded(
                      child: _buildBatteryTile(
                        label: 'You',
                        level: myBatteryLevel,
                        isCharging: isMyCharging,
                        isPartner: false,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBatteryTile({
    required String label,
    required int? level,
    required bool isCharging,
    required bool isPartner,
  }) {
    final hasData = level != null;
    final isLow = hasData && level <= 19;

    IconData battIcon;
    if (isCharging) {
      battIcon = Icons.battery_charging_full_rounded;
    } else if (!hasData) {
      battIcon = Icons.battery_unknown_rounded;
    } else if (level >= 80) {
      battIcon = Icons.battery_full_rounded;
    } else if (level >= 50) {
      battIcon = Icons.battery_5_bar_rounded;
    } else if (level >= 20) {
      battIcon = Icons.battery_3_bar_rounded;
    } else {
      battIcon = Icons.battery_alert_rounded;
    }

    Color iconColor;
    if (isCharging) {
      iconColor = AppColors.success;
    } else if (isLow) {
      iconColor = AppColors.error;
    } else {
      iconColor = AppColors.charcoal;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          Icon(battIcon, size: 20, color: iconColor),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTextStyles.bodySmall.copyWith(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
              Row(
                children: [
                  Text(
                    hasData ? '$level%' : '--',
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w700,
                      color: isLow ? AppColors.error : AppColors.charcoal,
                      fontSize: 13,
                    ),
                  ),
                  if (isCharging) ...[
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.bolt_rounded,
                      size: 13,
                      color: AppColors.success,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUnpairedCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AppColors.charcoal.withValues(alpha: 0.10),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.white.withValues(alpha: 0.94),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppColors.white.withValues(alpha: 0.95)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: AppColors.dustyRose.withValues(alpha: 0.14),
                  child: const Icon(
                    Icons.favorite_rounded,
                    color: AppColors.dustyRose,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Pair with your partner',
                        style: AppTextStyles.labelLarge.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        'See live distance and battery status',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: onConnectPartner,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.dustyRose,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text('Connect', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
