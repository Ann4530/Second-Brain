import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../core/env/app_config.dart';
import '../../data/models/entry.dart';
import '../../data/repositories/entry_repository.dart';
import '../../data/services/ai_service.dart';
import '../../shared/providers/app_providers.dart';

String todayLocalDate() => DateFormat('yyyy-MM-dd').format(DateTime.now());

/// Today's saved entry (null if the user hasn't journaled yet today).
final todaysEntryProvider = FutureProvider<Entry?>((ref) async {
  final repo = ref.watch(entryRepositoryProvider);
  return repo.entryForLocalDate(todayLocalDate());
});

/// Drives the daily loop: enforce the free cap → call AI → save the entry.
final journalControllerProvider =
    StateNotifierProvider<JournalController, AsyncValue<Entry?>>((ref) {
  return JournalController(
    ai: ref.watch(aiServiceProvider),
    repo: ref.watch(entryRepositoryProvider),
    isPremium: ref.watch(isPremiumProvider),
    onSaved: () {
      ref.invalidate(todaysEntryProvider);
      ref.invalidate(allEntriesProvider); // refresh History / Insights / streak
    },
  );
});

class JournalController extends StateNotifier<AsyncValue<Entry?>> {
  JournalController({
    required AiService ai,
    required EntryRepository repo,
    required bool isPremium,
    required VoidCallback onSaved,
  })  : _ai = ai,
        _repo = repo,
        _isPremium = isPremium,
        _onSaved = onSaved,
        super(const AsyncValue.data(null));

  final AiService _ai;
  final EntryRepository _repo;
  final bool _isPremium;
  final VoidCallback _onSaved;

  /// Submit the day's text. Returns the saved Entry (with reflection + nudge).
  Future<void> submit(String text, {String? language}) async {
    if (text.trim().isEmpty) return;
    state = const AsyncValue.loading();
    try {
      final date = todayLocalDate();

      // Free-tier daily cap (also enforced server-side in production).
      if (!_isPremium) {
        final count = await _repo.countForLocalDate(date);
        if (count >= AppConfig.freeReflectionsPerDay) {
          state = AsyncValue.error(const DailyLimitReached(), StackTrace.current);
          return;
        }
      }

      final reflection = await _ai.reflect(text, language: language);
      final entry = Entry.fromReflection(
        id: const Uuid().v4(),
        createdAt: DateTime.now(),
        localDate: date,
        text: text,
        r: reflection,
      );
      await _repo.save(entry);
      _onSaved();
      state = AsyncValue.data(entry);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  void reset() => state = const AsyncValue.data(null);
}

class DailyLimitReached implements Exception {
  const DailyLimitReached();
  @override
  String toString() => 'You have used your free reflection for today.';
}
