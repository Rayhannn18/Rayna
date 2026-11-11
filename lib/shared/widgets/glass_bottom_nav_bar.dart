import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

/// Navigation item model for [GlassBottomNavBar].
class GlassNavItem {
  const GlassNavItem({
    required this.label,
    required this.selectedIcon,
    required this.unselectedIcon,
  });

  final String label;
  final IconData selectedIcon;
  final IconData unselectedIcon;
}

/// A modern floating glassmorphism navigation bar for the Rayna app.
///
/// Features:
/// - Frosted glass translucent backdrop filter (`BackdropFilter` with blur)
/// - Floating rounded pill geometry with subtle border and ambient shadow
/// - Smooth tab selection animation with active accent pill
/// - Haptic feedback on item selection
/// - Respects bottom [SafeArea]
class GlassBottomNavBar extends StatelessWidget {
  const GlassBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.items = defaultItems,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<GlassNavItem> items;

  static const List<GlassNavItem> defaultItems = [
    GlassNavItem(
      label: 'Home',
      selectedIcon: Icons.home_rounded,
      unselectedIcon: Icons.home_outlined,
    ),
    GlassNavItem(
      label: 'Moments',
      selectedIcon: Icons.photo_library_rounded,
      unselectedIcon: Icons.photo_library_outlined,
    ),
    GlassNavItem(
      label: 'Map',
      selectedIcon: Icons.map_rounded,
      unselectedIcon: Icons.map_outlined,
    ),
    GlassNavItem(
      label: 'Mood',
      selectedIcon: Icons.favorite_rounded,
      unselectedIcon: Icons.favorite_outline_rounded,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      left: false,
      right: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: AppColors.charcoal.withValues(alpha: 0.08),
                blurRadius: 24,
                offset: const Offset(0, 8),
                spreadRadius: 0,
              ),
              BoxShadow(
                color: AppColors.dustyRose.withValues(alpha: 0.06),
                blurRadius: 16,
                offset: const Offset(0, 2),
                spreadRadius: 0,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                height: 68,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.white.withValues(alpha: 0.78),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: AppColors.white.withValues(alpha: 0.65),
                    width: 1.2,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: List.generate(items.length, (index) {
                    final isSelected = index == currentIndex;
                    final item = items[index];

                    return Expanded(
                      child: _GlassNavItemWidget(
                        item: item,
                        isSelected: isSelected,
                        onTap: () {
                          if (!isSelected) {
                            HapticFeedback.selectionClick();
                            onTap(index);
                          }
                        },
                      ),
                    );
                  }),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GlassNavItemWidget extends StatelessWidget {
  const _GlassNavItemWidget({
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  final GlassNavItem item;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        splashColor: AppColors.dustyRose.withValues(alpha: 0.15),
        highlightColor: Colors.transparent,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.dustyRose.withValues(alpha: 0.14)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (child, animation) {
                  return ScaleTransition(scale: animation, child: child);
                },
                child: Icon(
                  isSelected ? item.selectedIcon : item.unselectedIcon,
                  key: ValueKey<bool>(isSelected),
                  size: 22,
                  color: isSelected
                      ? AppColors.dustyRose
                      : AppColors.charcoal.withValues(alpha: 0.55),
                ),
              ),
              const SizedBox(height: 3),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                style: AppTextStyles.labelSmall.copyWith(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected
                      ? AppColors.dustyRose
                      : AppColors.charcoal.withValues(alpha: 0.60),
                ),
                child: Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
