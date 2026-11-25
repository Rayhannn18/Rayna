import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../pairing/providers/pairing_providers.dart';
import '../../data/mood_config.dart';
import '../../data/mood_service.dart';
import '../../providers/mood_providers.dart';
import '../widgets/mood_history_section.dart';

class MoodPage extends ConsumerStatefulWidget {
  const MoodPage({super.key});

  @override
  ConsumerState<MoodPage> createState() => _MoodPageState();
}

class _MoodPageState extends ConsumerState<MoodPage> {
  final noteController = TextEditingController();
  String? selected;
  bool saving = false;

  @override
  void dispose() {
    noteController.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (selected == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Choose a mood first.')));
      return;
    }

    final userData = ref.read(currentUserDocumentProvider).valueOrNull?.data();
    final pair = userData?['activePairId'] as String?;

    if (pair == null || pair.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pair with your partner first.')),
      );
      return;
    }

    final displayName = userData?['displayName'] as String?;

    setState(() => saving = true);
    try {
      await ref
          .read(moodServiceProvider)
          .setMood(
            pairId: pair,
            mood: selected!,
            note: noteController.text,
            displayName: displayName,
          );
      if (mounted) {
        noteController.clear();
        FocusScope.of(context).unfocus();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Mood shared with your partner!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } on MoodException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: AppColors.error),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not share mood. Please try again.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final userDoc = ref.watch(currentUserDocumentProvider);
    final activePairId =
        userDoc.valueOrNull?.data()?['activePairId'] as String?;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text('Mood Check-In', style: AppTextStyles.h3),
        centerTitle: true,
        leading: Navigator.of(context).canPop()
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 120),
        children: [
          Text('How are you feeling?', style: AppTextStyles.h2),
          const SizedBox(height: 6),
          Text(
            'Keep your partner in tune with your emotions today.',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: MoodConfig.checkInMoods.map((m) {
              final isChosen = selected == m.name;

              return ChoiceChip(
                avatar: Text(m.emoji, style: const TextStyle(fontSize: 16)),
                label: Text(m.name),
                selected: isChosen,
                selectedColor: AppColors.dustyRose.withValues(alpha: 0.20),
                backgroundColor: AppColors.white,
                side: BorderSide(
                  color: isChosen ? AppColors.dustyRose : AppColors.divider,
                  width: isChosen ? 1.5 : 1,
                ),
                labelStyle: TextStyle(
                  color: isChosen ? AppColors.dustyRose : AppColors.charcoal,
                  fontWeight: isChosen ? FontWeight.w600 : FontWeight.w500,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                onSelected: (_) => setState(() => selected = m.name),
              );
            }).toList(),
          ),
          const SizedBox(height: 28),
          TextField(
            controller: noteController,
            maxLength: 300,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: 'A little note (optional)',
              hintText: 'Tell your partner why or what you need...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: AppColors.divider),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: AppColors.divider),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(
                  color: AppColors.dustyRose,
                  width: 1.5,
                ),
              ),
              filled: true,
              fillColor: AppColors.white,
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: saving ? null : save,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.dustyRose,
              foregroundColor: AppColors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: saving
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.white,
                    ),
                  )
                : const Text('Share Mood with Partner'),
          ),
          const SizedBox(height: 28),
          const Divider(color: AppColors.divider, height: 1),
          const SizedBox(height: 24),
          MoodHistorySection(
            pairId: activePairId,
            isUserDocLoading: userDoc.isLoading,
          ),
        ],
      ),
    );
  }
}
