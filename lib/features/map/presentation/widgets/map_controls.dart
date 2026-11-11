import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../providers/map_providers.dart';

/// Floating map control pill with zoom, map type, and centering actions.
class MapFloatingControls extends ConsumerWidget {
  const MapFloatingControls({
    super.key,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onCenterUser,
    required this.onFitBoth,
    this.hasPartnerLocation = false,
    this.isTrailVisible = true,
    this.onToggleTrail,
  });

  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onCenterUser;
  final VoidCallback onFitBoth;
  final bool hasPartnerLocation;
  final bool isTrailVisible;
  final VoidCallback? onToggleTrail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentMapType = ref.watch(mapTypeProvider);
    final isSatellite = currentMapType == MapType.satellite;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Map Type Toggle (Satellite vs Normal)
        _buildGlassButton(
          tooltip: isSatellite ? 'Normal Map' : 'Satellite View',
          icon: isSatellite ? Icons.map_rounded : Icons.satellite_alt_rounded,
          isActive: isSatellite,
          onTap: () {
            ref.read(mapTypeProvider.notifier).state =
                isSatellite ? MapType.normal : MapType.satellite;
          },
        ),
        const SizedBox(height: 10),

        // Movement Trail Toggle
        if (onToggleTrail != null) ...[
          _buildGlassButton(
            tooltip: isTrailVisible ? 'Hide Movement Trail' : 'Show Movement Trail',
            icon: Icons.route_rounded,
            isActive: isTrailVisible,
            onTap: onToggleTrail!,
          ),
          const SizedBox(height: 10),
        ],

        // Fit Both Partners (if partner location available)
        if (hasPartnerLocation) ...[
          _buildGlassButton(
            tooltip: 'View Both of Us',
            icon: Icons.people_alt_rounded,
            onTap: onFitBoth,
          ),
          const SizedBox(height: 10),
        ],

        // My Location Button
        _buildGlassButton(
          tooltip: 'Center on Me',
          icon: Icons.my_location_rounded,
          onTap: onCenterUser,
        ),
        const SizedBox(height: 10),

        // Zoom Controls Group
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: AppColors.charcoal.withValues(alpha: 0.10),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.white.withValues(alpha: 0.88),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: AppColors.white.withValues(alpha: 0.9),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildIconButton(
                      icon: Icons.add_rounded,
                      tooltip: 'Zoom In',
                      onTap: onZoomIn,
                    ),
                    Container(
                      height: 1,
                      width: 24,
                      color: AppColors.divider.withValues(alpha: 0.6),
                    ),
                    _buildIconButton(
                      icon: Icons.remove_rounded,
                      tooltip: 'Zoom Out',
                      onTap: onZoomOut,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGlassButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    bool isActive = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppColors.charcoal.withValues(alpha: 0.10),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Material(
            color: isActive
                ? AppColors.dustyRose
                : AppColors.white.withValues(alpha: 0.88),
            child: InkWell(
              onTap: onTap,
              child: Tooltip(
                message: tooltip,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Icon(
                    icon,
                    size: 20,
                    color: isActive ? AppColors.white : AppColors.charcoal,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Icon(icon, size: 20, color: AppColors.charcoal),
        ),
      ),
    );
  }
}

