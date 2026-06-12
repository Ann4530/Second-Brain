import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../data/models/chat_message.dart';
import '../../data/models/entry.dart';
import '../../data/models/reflection.dart';
import '../../data/services/on_device_ai_service.dart';
import '../../shared/providers/settings_providers.dart';
import '../history/streak.dart';
import 'journal_controller.dart';

class TodayScreen extends ConsumerStatefulWidget {
  const TodayScreen({super.key});

  @override
  ConsumerState<TodayScreen> createState() => _TodayScreenState();
}

/// Entry mode: quick note (classic) or AI conversation.
enum _EntryMode { note, chat }

class _TodayScreenState extends ConsumerState<TodayScreen> {
  final _textCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _speech = SpeechToText();
  bool _sttReady = false;
  bool _listening = false;
  bool _composing = false;
  _EntryMode _mode = _EntryMode.chat; // default to conversation

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeStart());
  }

  void _maybeStart() {
    final existing = ref.read(todaysEntryProvider).valueOrNull;
    if (existing == null && !_composing) {
      _beginEntry();
    }
  }

  void _beginEntry() {
    ref.read(journalControllerProvider.notifier).reset();
    if (_mode == _EntryMode.chat) {
      ref.read(conversationProvider.notifier).start();
    } else {
      ref.read(conversationProvider.notifier).reset();
    }
    setState(() => _composing = true);
  }

  void _startNew() {
    _textCtrl.clear();
    ref.read(conversationProvider.notifier).reset();
    _beginEntry();
  }

  void _switchMode(_EntryMode m) {
    if (m == _mode) return;
    setState(() => _mode = m);
    // Restart entry in new mode
    _textCtrl.clear();
    ref.read(journalControllerProvider.notifier).reset();
    if (m == _EntryMode.chat) {
      ref.read(conversationProvider.notifier).start();
    } else {
      ref.read(conversationProvider.notifier).reset();
    }
    setState(() => _composing = true);
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _toggleMic() async {
    if (!_sttReady) {
      _sttReady = await _speech.initialize();
      if (!_sttReady) return;
    }
    if (_listening) {
      await _speech.stop();
      setState(() => _listening = false);
      return;
    }
    setState(() => _listening = true);
    await _speech.listen(
      onResult: (r) => setState(() => _textCtrl.text = r.recognizedWords),
      listenOptions: SpeechListenOptions(listenFor: const Duration(minutes: 3)),
    );
  }

  Future<void> _sendMessage() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) return;
    _textCtrl.clear();
    await _speech.stop();
    setState(() => _listening = false);
    await ref.read(conversationProvider.notifier).send(text);
    _scrollToBottom();
  }

  Future<void> _submitNote() async {
    await _speech.stop();
    setState(() => _listening = false);
    final language = ref.read(reflectionLanguageProvider);
    await ref.read(journalControllerProvider.notifier).submit(
          _textCtrl.text,
          language: language,
        );
    if (mounted) setState(() => _composing = false);
  }

  Future<void> _endConversation() async {
    final conv = ref.read(conversationProvider.notifier);
    if (!conv.hasUserMessage) return;
    final transcript = conv.transcript;
    final language = ref.read(reflectionLanguageProvider);
    await ref.read(journalControllerProvider.notifier).submit(
          transcript,
          language: language,
        );
    if (mounted) setState(() => _composing = false);
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final journalState = ref.watch(journalControllerProvider);
    final todays = ref.watch(todaysEntryProvider);
    final streak = ref.watch(streakProvider).valueOrNull ?? 0;

    final shown = journalState.valueOrNull ?? todays.valueOrNull;
    final inEntry = _composing && shown == null && !journalState.isLoading;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Today'),
        actions: [
          if (streak > 0)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Chip(label: Text('🔥 $streak')),
            ),
          if (inEntry)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: SegmentedButton<_EntryMode>(
                segments: const [
                  ButtonSegment(
                      value: _EntryMode.chat,
                      icon: Icon(Icons.chat_bubble_outline, size: 16),
                      label: Text('Trò chuyện')),
                  ButtonSegment(
                      value: _EntryMode.note,
                      icon: Icon(Icons.edit_note, size: 16),
                      label: Text('Ghi chú')),
                ],
                selected: {_mode},
                onSelectionChanged: (s) => _switchMode(s.first),
                style: const ButtonStyle(
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: journalState.when(
          loading: () => const _Summarising(),
          error: (e, _) => _ErrorView(
            message: _friendlyError(e),
            onRetry: _startNew,
          ),
          data: (entry) {
            final shownEntry = entry ?? todays.valueOrNull;
            if (shownEntry != null && !_composing) {
              return _ReflectionView(entry: shownEntry, onNew: _startNew);
            }
            if (_mode == _EntryMode.chat) {
              return _ChatView(
                scrollCtrl: _scrollCtrl,
                textCtrl: _textCtrl,
                listening: _listening,
                onMic: _toggleMic,
                onSend: _sendMessage,
                onEnd: _endConversation,
              );
            }
            return _NoteComposer(
              controller: _textCtrl,
              listening: _listening,
              onMic: _toggleMic,
              onSubmit: _submitNote,
            );
          },
        ),
      ),
    );
  }

  String _friendlyError(Object e) {
    if (e is DailyLimitReached) {
      return 'Bạn đã dùng hết lượt phản tư miễn phí hôm nay. Nâng cấp để dùng không giới hạn.';
    }
    if (e is OnDeviceUnsupported) {
      return 'Máy này không đủ mạnh để chạy AI nội bộ. Tắt "Chỉ dùng on-device" trong Cài đặt.';
    }
    return 'Có lỗi xảy ra. Vui lòng thử lại.';
  }
}

// ── Chat view ─────────────────────────────────────────────────────────────────

class _ChatView extends ConsumerWidget {
  const _ChatView({
    required this.scrollCtrl,
    required this.textCtrl,
    required this.listening,
    required this.onMic,
    required this.onSend,
    required this.onEnd,
  });

  final ScrollController scrollCtrl;
  final TextEditingController textCtrl;
  final bool listening;
  final VoidCallback onMic;
  final VoidCallback onSend;
  final VoidCallback onEnd;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conv = ref.watch(conversationProvider);
    final hasUser = conv.messages.any((m) => m.isUser);

    return Column(
      children: [
        // ── Messages list ──
        Expanded(
          child: ListView.builder(
            controller: scrollCtrl,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            itemCount: conv.messages.length + (conv.isTyping ? 1 : 0),
            itemBuilder: (ctx, i) {
              if (i == conv.messages.length) {
                return const _TypingBubble();
              }
              final msg = conv.messages[i];
              return _MessageBubble(message: msg);
            },
          ),
        ),

        // ── "Kết thúc" button (visible after first user message) ──
        if (hasUser)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('Kết thúc & Phân tích'),
                onPressed: conv.isTyping ? null : onEnd,
              ),
            ),
          ),

        // ── Input bar ──
        _InputBar(
          controller: textCtrl,
          listening: listening,
          onMic: onMic,
          onSend: onSend,
          enabled: !conv.isTyping,
        ),
      ],
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});
  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: message.isUser ? cs.primary : cs.surfaceContainerHighest,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(message.isUser ? 18 : 4),
            bottomRight: Radius.circular(message.isUser ? 4 : 18),
          ),
        ),
        child: Text(
          message.text,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: message.isUser ? cs.onPrimary : cs.onSurface,
          ),
        ),
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(4),
            bottomRight: Radius.circular(18),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 40,
              child: LinearProgressIndicator(
                minHeight: 2,
                color: cs.primary,
                backgroundColor: cs.surfaceContainerHighest,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  const _InputBar({
    required this.controller,
    required this.listening,
    required this.onMic,
    required this.onSend,
    required this.enabled,
  });

  final TextEditingController controller;
  final bool listening;
  final VoidCallback onMic;
  final VoidCallback onSend;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          12, 4, 12, MediaQuery.of(context).viewInsets.bottom + 8),
      child: Row(
        children: [
          IconButton(
            onPressed: enabled ? onMic : null,
            icon: Icon(listening ? Icons.stop : Icons.mic),
            color: listening ? Theme.of(context).colorScheme.error : null,
          ),
          Expanded(
            child: TextField(
              controller: controller,
              enabled: enabled,
              maxLines: null,
              textInputAction: TextInputAction.send,
              onSubmitted: enabled ? (_) => onSend() : null,
              decoration: InputDecoration(
                hintText: listening ? 'Đang nghe…' : 'Nhắn tin…',
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: 4),
          IconButton.filled(
            onPressed: enabled ? onSend : null,
            icon: const Icon(Icons.send),
          ),
        ],
      ),
    );
  }
}

// ── Loading / result views ────────────────────────────────────────────────────

class _Summarising extends StatelessWidget {
  const _Summarising();
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Đang phân tích cuộc trò chuyện…'),
        ],
      ),
    );
  }
}

class _ReflectionView extends StatelessWidget {
  const _ReflectionView({required this.entry, required this.onNew});
  final Entry entry;
  final VoidCallback onNew;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Phân tích', style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          Text(entry.reflection, style: theme.textTheme.bodyLarge),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.lightbulb_outline),
                  const SizedBox(width: 12),
                  Expanded(child: Text(entry.nudge)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 8,
            children: [
              Chip(label: Text('mood: ${entry.metadata.mood}')),
              Chip(label: Text('energy: ${entry.metadata.energy}/5')),
              for (final t in entry.metadata.topics.take(3)) Chip(label: Text(t)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            entry.source == AiSource.onDevice
                ? '🔒 Phân tích trên máy của bạn'
                : '☁️ Phân tích qua cloud riêng tư',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onNew,
              icon: const Icon(Icons.add),
              label: const Text('Cuộc trò chuyện mới'),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Note composer (classic single-text mode) ──────────────────────────────────

class _NoteComposer extends StatelessWidget {
  const _NoteComposer({
    required this.controller,
    required this.listening,
    required this.onMic,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final bool listening;
  final VoidCallback onMic;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Hôm nay của bạn thế nào?',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text('Gõ hoặc nói ~2 phút. Riêng tư trên máy của bạn.',
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 16),
          Expanded(
            child: TextField(
              controller: controller,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Hôm nay tôi…',
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              IconButton.filledTonal(
                onPressed: onMic,
                iconSize: 28,
                icon: Icon(listening ? Icons.stop : Icons.mic),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: onSubmit,
                  child: const Text('Phân tích'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Thử lại')),
          ],
        ),
      ),
    );
  }
}
