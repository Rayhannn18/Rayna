import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rayna_app/features/mood/data/mood_config.dart';
import 'package:rayna_app/features/mood/data/mood_history_model.dart';
import 'package:rayna_app/features/mood/presentation/widgets/mood_history_card.dart';
import 'package:rayna_app/features/mood/presentation/widgets/mood_history_filter.dart';
import 'package:rayna_app/features/mood/providers/mood_providers.dart';

void main() {
  group('MoodConfig mapping', () {
    test('maps all 8 default check-in moods to consistent categories', () {
      expect(MoodConfig.checkInMoods.length, equals(8));
      expect(MoodConfig.categoryFor('Happy'), equals('Good'));
      expect(MoodConfig.categoryFor('Love'), equals('Good'));
      expect(MoodConfig.categoryFor('Calm'), equals('Good'));
      expect(MoodConfig.categoryFor('Excited'), equals('Good'));
      expect(MoodConfig.categoryFor('Missing You'), equals('Neutral'));
      expect(MoodConfig.categoryFor('Tired'), equals('Bad'));
      expect(MoodConfig.categoryFor('Sad'), equals('Bad'));
      expect(MoodConfig.categoryFor('Stressed'), equals('Bad'));
    });

    test('supports extended moods and safe fallback for unknown moods', () {
      expect(MoodConfig.categoryFor('Ashamed'), equals('Bad'));
      expect(MoodConfig.emojiFor('Ashamed'), equals('😳'));
      expect(MoodConfig.categoryFor('UnknownMood'), equals('Neutral'));
      expect(MoodConfig.emojiFor('UnknownMood'), equals('✨'));
    });
  });

  group('MoodHistoryEntry model & time formatting', () {
    test('parses map and derives missing category/emoji consistently', () {
      final entry = MoodHistoryEntry.fromMap(
        id: 'hist_1',
        data: {
          'uid': 'uid_rayhan',
          'displayName': 'Rayhan',
          'mood': 'Happy',
          'note': 'Today feels great!',
          'createdAt': DateTime(2026, 11, 23, 16, 21),
          'pairId': 'pair_1',
        },
      );

      expect(entry.category, equals('Good'));
      expect(entry.emoji, equals('😊'));
      expect(entry.subtitle(currentUid: 'uid_rayhan'), equals('Happy, Rayhan'));
      expect(entry.isOwnedBy('uid_rayhan'), isTrue);
      expect(entry.isOwnedBy('uid_partner'), isFalse);
      expect(entry.formattedTime(), equals('4:21 PM'));
    });

    test('uses You / Partner fallbacks when displayName is empty', () {
      final myEntry = MoodHistoryEntry.fromMap(
        id: 'h1',
        data: {'uid': 'uid_me', 'displayName': '', 'mood': 'Calm'},
      );
      final partnerEntry = MoodHistoryEntry.fromMap(
        id: 'h2',
        data: {'uid': 'uid_partner', 'displayName': '', 'mood': 'Tired'},
      );

      expect(myEntry.subtitle(currentUid: 'uid_me'), equals('Calm, You'));
      expect(
        partnerEntry.subtitle(currentUid: 'uid_me'),
        equals('Tired, Partner'),
      );
    });

    test('formats 12-hour local time accurately for AM/PM edge cases', () {
      expect(
        MoodHistoryEntry.formatLocalTime(DateTime(2026, 1, 1, 9, 15)),
        equals('9:15 AM'),
      );
      expect(
        MoodHistoryEntry.formatLocalTime(DateTime(2026, 1, 1, 0, 5)),
        equals('12:05 AM'),
      );
      expect(
        MoodHistoryEntry.formatLocalTime(DateTime(2026, 1, 1, 12, 0)),
        equals('12:00 PM'),
      );
      expect(
        MoodHistoryEntry.formatLocalTime(DateTime(2026, 1, 1, 16, 21)),
        equals('4:21 PM'),
      );
    });
  });

  group('filterMoodHistoryEntries', () {
    final entries = [
      MoodHistoryEntry(
        id: '1',
        uid: 'uid_me',
        displayName: 'Rayhan',
        mood: 'Happy',
        category: 'Good',
        emoji: '😊',
        note: '',
        createdAt: DateTime(2026, 11, 23, 16, 21),
        pairId: 'pair_1',
      ),
      MoodHistoryEntry(
        id: '2',
        uid: 'uid_partner',
        displayName: 'Rayhan', // Same displayName, different UID
        mood: 'Tired',
        category: 'Bad',
        emoji: '🥱',
        note: 'Long day',
        createdAt: DateTime(2026, 11, 23, 9, 15),
        pairId: 'pair_1',
      ),
    ];

    test('filters strictly by UID for All, My Mood, and Partner', () {
      final all = filterMoodHistoryEntries(
        entries: entries,
        filter: MoodHistoryFilter.all,
        currentUid: 'uid_me',
      );
      final mine = filterMoodHistoryEntries(
        entries: entries,
        filter: MoodHistoryFilter.myMood,
        currentUid: 'uid_me',
      );
      final partner = filterMoodHistoryEntries(
        entries: entries,
        filter: MoodHistoryFilter.partner,
        currentUid: 'uid_me',
      );

      expect(all.length, equals(2));
      expect(mine.map((e) => e.id).toList(), equals(['1']));
      expect(partner.map((e) => e.id).toList(), equals(['2']));
    });
  });

  group('MoodHistoryCard & Filter widgets', () {
    testWidgets('shows Delete option only for own mood history entry', (
      tester,
    ) async {
      final ownEntry = MoodHistoryEntry(
        id: 'own_1',
        uid: 'uid_me',
        displayName: 'Rayhan',
        mood: 'Happy',
        category: 'Good',
        emoji: '😊',
        note: 'Feeling wonderful',
        createdAt: DateTime(2026, 11, 23, 16, 21),
        pairId: 'pair_1',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MoodHistoryCard(
              entry: ownEntry,
              currentUid: 'uid_me',
              onTap: () {},
              onDelete: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Good'), findsOneWidget);
      expect(find.text('Happy, Rayhan'), findsOneWidget);
      expect(find.text('4:21 PM'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.more_vert_rounded));
      await tester.pumpAndSettle();

      expect(find.text('View Details'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
    });

    testWidgets('hides Delete option for partner mood history entry', (
      tester,
    ) async {
      final partnerEntry = MoodHistoryEntry(
        id: 'partner_1',
        uid: 'uid_partner',
        displayName: 'Nadia',
        mood: 'Excited',
        category: 'Good',
        emoji: '✨',
        note: '',
        createdAt: DateTime(2026, 11, 23, 9, 15),
        pairId: 'pair_1',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MoodHistoryCard(
              entry: partnerEntry,
              currentUid: 'uid_me',
              onTap: () {},
              onDelete: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Good'), findsOneWidget);
      expect(find.text('Excited, Nadia'), findsOneWidget);
      expect(find.text('9:15 AM'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.more_vert_rounded));
      await tester.pumpAndSettle();

      expect(find.text('View Details'), findsOneWidget);
      expect(find.text('Delete'), findsNothing);
    });

    testWidgets('MoodHistoryFilterBar switches filter modes on tap', (
      tester,
    ) async {
      MoodHistoryFilter current = MoodHistoryFilter.all;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => MoodHistoryFilterBar(
                selected: current,
                onChanged: (next) => setState(() => current = next),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('My Mood'));
      await tester.pumpAndSettle();
      expect(current, equals(MoodHistoryFilter.myMood));

      await tester.tap(find.text('Partner'));
      await tester.pumpAndSettle();
      expect(current, equals(MoodHistoryFilter.partner));

      await tester.tap(find.text('All'));
      await tester.pumpAndSettle();
      expect(current, equals(MoodHistoryFilter.all));
    });
  });
}
