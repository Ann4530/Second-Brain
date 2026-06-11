import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/router/app_router.dart';
import '../../data/services/notification_service.dart';
import '../../shared/providers/app_providers.dart';
import '../../shared/providers/entitlement_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  TimeOfDay _reminder = const TimeOfDay(hour: 21, minute: 0);

  Future<void> _pickReminderTime() async {
    final t = await showTimePicker(context: context, initialTime: _reminder);
    if (t == null) return;
    setState(() => _reminder = t);
    await NotificationService.instance
        .scheduleDailyReminder(hour: t.hour, minute: t.minute);
  }

  Future<void> _export() async {
    final entries = await ref.read(entryRepositoryProvider).all();
    final json = const JsonEncoder.withIndent('  ')
        .convert(entries.map((e) => e.toJson()).toList());
    await Share.shareXFiles(
      [
        XFile.fromData(
          utf8.encode(json),
          name: 'second-brain-export.json',
          mimeType: 'application/json',
        )
      ],
      text: 'My Second Brain journal export',
    );
  }

  Future<void> _deleteAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete everything?'),
        content: const Text(
            'This permanently deletes all your entries and your account data. '
            'This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(entryRepositoryProvider).deleteAll();
    // TODO(firebase): also call the deleteAccount Cloud Function + sign out
    // once Firebase is configured.
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('All data deleted.')));
  }

  @override
  Widget build(BuildContext context) {
    final privacyOnly = ref.watch(privacyModeProvider);
    final isPremium = ref.watch(isPremiumProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text('On-device only (max privacy)'),
            subtitle: const Text(
                'Never send anything to the cloud. AI runs only on this phone.'),
            value: privacyOnly,
            onChanged: (v) =>
                ref.read(privacyModeProvider.notifier).state = v,
          ),
          ListTile(
            leading: const Icon(Icons.notifications_outlined),
            title: const Text('Daily reminder'),
            subtitle: Text(_reminder.format(context)),
            onTap: _pickReminderTime,
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.workspace_premium_outlined),
            title: Text(isPremium ? 'Premium active' : 'Upgrade to Premium'),
            subtitle: const Text(
                'Unlimited reflections, monthly Wrapped, deeper cloud insights.'),
            onTap: () => context.push(Routes.paywall),
          ),
          ListTile(
            leading: const Icon(Icons.restore),
            title: const Text('Restore purchases'),
            onTap: () => ref.read(entitlementServiceProvider).restore(),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.download_outlined),
            title: const Text('Export my data'),
            onTap: _export,
          ),
          ListTile(
            leading: const Icon(Icons.delete_forever_outlined),
            title: const Text('Delete account & data'),
            onTap: _deleteAll,
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('Privacy policy'),
            onTap: () {
              // TODO: open hosted privacy policy URL before store submission.
            },
          ),
        ],
      ),
    );
  }
}
