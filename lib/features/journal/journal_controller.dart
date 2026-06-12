import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../core/env/app_config.dart';
import '../../data/models/chat_message.dart';
import '../../data/models/entry.dart';
import '../../data/repositories/entry_repository.dart';
import '../../data/services/ai_service.dart';
import '../../shared/providers/app_providers.dart';
import '../../shared/providers/settings_providers.dart';

String todayLocalDate() => DateFormat('yyyy-MM-dd').format(DateTime.now());

/// Today's saved entry (null if the user hasn't journaled yet today).
final todaysEntryProvider = FutureProvider<Entry?>((ref) async {
  final repo = ref.watch(entryRepositoryProvider);
  return repo.entryForLocalDate(todayLocalDate());
});

// ─── Conversation state ───────────────────────────────────────────────────────

class ConvState {
  final List<ChatMessage> messages;
  final bool isTyping;

  const ConvState({required this.messages, this.isTyping = false});

  ConvState copyWith({List<ChatMessage>? messages, bool? isTyping}) => ConvState(
        messages: messages ?? this.messages,
        isTyping: isTyping ?? this.isTyping,
      );
}

final conversationProvider =
    StateNotifierProvider<ConversationNotifier, ConvState>((ref) {
  return ConversationNotifier(
    ai: ref.watch(aiServiceProvider),
    language: ref.watch(reflectionLanguageProvider),
  );
});

class ConversationNotifier extends StateNotifier<ConvState> {
  ConversationNotifier({required AiService ai, required String? language})
      : _ai = ai,
        _language = language,
        super(const ConvState(messages: []));

  final AiService _ai;
  final String? _language;

  /// Start a new conversation — show the hardcoded opening question instantly.
  void start() {
    state = ConvState(messages: [
      ChatMessage(
        isUser: false,
        text: AiPrompts.openingQuestion(_language),
      ),
    ]);
  }

  void reset() => state = const ConvState(messages: []);

  bool get hasUserMessage => state.messages.any((m) => m.isUser);

  /// Send a user message and get the AI follow-up.
  Future<void> send(String text) async {
    if (text.trim().isEmpty) return;

    // Add user message immediately.
    final withUser = state.messages + [ChatMessage(isUser: true, text: text.trim())];
    state = ConvState(messages: withUser, isTyping: true);

    try {
      final reply = await _ai.chat(withUser, language: _language);
      state = ConvState(
        messages: withUser + [ChatMessage(isUser: false, text: reply)],
      );
    } catch (_) {
      // On error, keep conversation going without AI reply.
      state = ConvState(messages: withUser);
    }
  }

  /// Format the conversation as a text block for reflect().
  String get transcript =>
      AiPrompts.conversationToEntryText(state.messages);
}

// ─── Journal save controller ──────────────────────────────────────────────────

/// Drives the save step: call AI reflect() on conversation transcript → save entry.
final journalControllerProvider =
    StateNotifierProvider<JournalController, AsyncValue<Entry?>>((ref) {
  return JournalController(
    ai: ref.watch(aiServiceProvider),
    repo: ref.watch(entryRepositoryProvider),
    isPremium: ref.watch(isPremiumProvider),
    onSaved: () {
      ref.invalidate(todaysEntryProvider);
      ref.invalidate(allEntriesProvider);
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

  /// Submit the conversation transcript (or a plain entry text) for reflection.
  Future<void> submit(String text, {String? language}) async {
    if (text.trim().isEmpty) return;
    state = const AsyncValue.loading();
    try {
      final date = todayLocalDate();

      if (!_isPremium && AppConfig.freeReflectionsPerDay > 0) {
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
