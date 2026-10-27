import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../providers/mood_providers.dart';

class MoodPage extends ConsumerWidget {
  const MoodPage({super.key});
  static const moods = [
    ('Happy', '😊'),
    ('Loved', '🥰'),
    ('Calm', '😌'),
    ('Tired', '😴'),
    ('Sad', '😔'),
    ('Excited', '🤩'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mood = ref.watch(moodProvider);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(AppRoutes.home),
        ),
        title: Text('Mood', style: AppTextStyles.h3),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text('How are you feeling?', style: AppTextStyles.h2),
          const SizedBox(height: 8),
          Text(
            'Let your partner know what is on your heart.',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 28),
          mood.when(
            data: (snapshot) {
              final data = snapshot.data();
              return data == null
                  ? const SizedBox.shrink()
                  : Card(
                      child: ListTile(
                        leading: Text(
                          data['emoji'] as String? ?? '😊',
                          style: const TextStyle(fontSize: 32),
                        ),
                        title: Text('Your current mood: ${data['mood'] ?? ''}'),
                      ),
                    );
            },
            loading: () => const LinearProgressIndicator(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: moods
                .map(
                  (item) => ActionChip(
                    avatar: Text(item.$2, style: const TextStyle(fontSize: 20)),
                    label: Text(item.$1),
                    onPressed: () async {
                      try {
                        await ref
                            .read(moodServiceProvider)
                            .setMood(item.$1, item.$2);
                        if (context.mounted)
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Mood shared.')),
                          );
                      } catch (error) {
                        if (context.mounted)
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(error.toString())),
                          );
                      }
                    },
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}
