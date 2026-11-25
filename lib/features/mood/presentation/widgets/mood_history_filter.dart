import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../providers/mood_providers.dart';

/// Clean horizontal pill filter bar for switching between All, My Mood, and Partner.
class MoodHistoryFilterBar extends StatelessWidget {
  const MoodHistoryFilterBar({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final MoodHistoryFilter selected;
  final ValueChanged<MoodHistoryFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.warmGray.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          _FilterPill(
            label: 'All',
            isSelected: selected == MoodHistoryFilter.all,
            onTap: () => onChanged(MoodHistoryFilter.all),
          ),
          _FilterPill(
            label: 'My Mood',
            isSelected: selected == MoodHistoryFilter.myMood,
            onTap: () => onChanged(MoodHistoryFilter.myMood),
          ),
          _FilterPill(
            label: 'Partner',
            isSelected: selected == MoodHistoryFilter.partner,
            onTap: () => onChanged(MoodHistoryFilter.partner),
          ),
        ],
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppColors.charcoal.withValues(alpha: 0.06),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: AppTextStyles.labelSmall.copyWith(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              color: isSelected ? AppColors.dustyRose : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
