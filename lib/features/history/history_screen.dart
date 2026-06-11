import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../shared/providers/app_providers.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(allEntriesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('History')),
      body: entries.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (list) {
          if (list.isEmpty) {
            return const Center(
                child: Text('No entries yet. Your reflections will appear here.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final e = list[i];
              return Card(
                child: ListTile(
                  title: Text(
                    DateFormat.yMMMMEEEEd().format(e.createdAt),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    e.reflection,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Text('${e.metadata.mood}\n${e.metadata.energy}/5',
                      textAlign: TextAlign.right),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
