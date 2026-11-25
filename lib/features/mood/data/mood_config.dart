import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// Immutable definition of a single check-in mood.
class MoodDefinition {
  const MoodDefinition({
    required this.name,
    required this.emoji,
    required this.category,
    required this.circleColor,
  });

  final String name;
  final String emoji;
  final String category;
  final Color circleColor;
}

/// Centralized, single source of truth for mood categories, emojis, and visual
/// styling across Mood Check-In and Mood History.
class MoodConfig {
  MoodConfig._();

  static const String categoryGood = 'Good';
  static const String categoryNeutral = 'Neutral';
  static const String categoryBad = 'Bad';

  /// Primary moods displayed as check-in ChoiceChips.
  static const List<MoodDefinition> checkInMoods = [
    MoodDefinition(
      name: 'Happy',
      emoji: '😊',
      category: categoryGood,
      circleColor: AppColors.softSage,
    ),
    MoodDefinition(
      name: 'Love',
      emoji: '🥰',
      category: categoryGood,
      circleColor: Color(0xFFF6E4E8),
    ),
    MoodDefinition(
      name: 'Calm',
      emoji: '😌',
      category: categoryGood,
      circleColor: AppColors.softSage,
    ),
    MoodDefinition(
      name: 'Excited',
      emoji: '✨',
      category: categoryGood,
      circleColor: Color(0xFFFBF1DD),
    ),
    MoodDefinition(
      name: 'Missing You',
      emoji: '🥺',
      category: categoryNeutral,
      circleColor: Color(0xFFEDE8E1),
    ),
    MoodDefinition(
      name: 'Tired',
      emoji: '🥱',
      category: categoryBad,
      circleColor: Color(0xFFECE9F0),
    ),
    MoodDefinition(
      name: 'Sad',
      emoji: '😢',
      category: categoryBad,
      circleColor: Color(0xFFE4EDF4),
    ),
    MoodDefinition(
      name: 'Stressed',
      emoji: '😮‍💨',
      category: categoryBad,
      circleColor: Color(0xFFF7E5E5),
    ),
  ];

  /// Extended mood mappings for additional or future moods.
  static const List<MoodDefinition> _extendedMoods = [
    MoodDefinition(
      name: 'Ashamed',
      emoji: '😳',
      category: categoryBad,
      circleColor: Color(0xFFF6E6E2),
    ),
    MoodDefinition(
      name: 'Annoyed',
      emoji: '😤',
      category: categoryBad,
      circleColor: Color(0xFFF7E5E5),
    ),
    MoodDefinition(
      name: 'Need Attention',
      emoji: '🫶',
      category: categoryNeutral,
      circleColor: Color(0xFFF6E4E8),
    ),
  ];

  static final Map<String, MoodDefinition> _byNameLower = {
    for (final item in [...checkInMoods, ..._extendedMoods])
      item.name.toLowerCase(): item,
  };

  /// Looks up a mood definition case-insensitively.
  static MoodDefinition? find(String? mood) {
    if (mood == null) return null;
    return _byNameLower[mood.trim().toLowerCase()];
  }

  /// Returns a consistent category (`Good`, `Neutral`, or `Bad`) for any mood.
  static String categoryFor(String mood) {
    return find(mood)?.category ?? categoryNeutral;
  }

  /// Returns the emoji mapped to [mood], with a gentle default fallback.
  static String emojiFor(String mood) {
    return find(mood)?.emoji ?? '✨';
  }

  /// Returns the pastel circular background color for [mood].
  static Color circleColorFor(String mood) {
    return find(mood)?.circleColor ?? AppColors.warmGray;
  }

  /// Subtle pill background color for a mood category.
  static Color categoryBadgeColor(String category) {
    switch (category) {
      case categoryGood:
        return AppColors.softSage;
      case categoryBad:
        return const Color(0xFFF6E4E8);
      case categoryNeutral:
      default:
        return AppColors.warmGray;
    }
  }

  /// Text color for a mood category pill.
  static Color categoryTextColor(String category) {
    switch (category) {
      case categoryGood:
        return const Color(0xFF3E7B57);
      case categoryBad:
        return const Color(0xFFB55D6D);
      case categoryNeutral:
      default:
        return AppColors.textSecondary;
    }
  }
}
