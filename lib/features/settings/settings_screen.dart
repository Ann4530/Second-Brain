import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart' show UserInfo;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/router/app_router.dart';
import '../../data/services/notification_service.dart';
import '../../shared/providers/app_providers.dart';
import '../../shared/providers/entitlement_provider.dart';
import '../../shared/providers/settings_providers.dart';

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

  Future<void> _signInGoogle() async {
    try {
      final user = await ref.read(authServiceProvider).signInWithGoogle();
      if (!mounted || user == null) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Signed in as ${user.email ?? 'Google'}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Sign-in failed: $e')));
    }
  }

  Future<void> _signOut() async {
    await ref.read(authServiceProvider).signOut();
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Signed out.')));
  }

  Future<void> _pickLanguage() async {
    final current = ref.read(reflectionLanguageProvider);
    // Return the chosen LABEL (non-null) so we can tell a real pick apart from
    // a dismiss (null).
    final pickedLabel = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Reflection language'),
        children: [
          for (final entry in reflectionLanguageOptions.entries)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, entry.key),
              child: Row(
                children: [
                  Icon(entry.value == current
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked),
                  const SizedBox(width: 12),
                  Text(entry.key),
                ],
              ),
            ),
        ],
      ),
    );
    if (pickedLabel == null) return; // dismissed
    await ref
        .read(reflectionLanguageProvider.notifier)
        .set(reflectionLanguageOptions[pickedLabel]);
  }

  Future<void> _pickTheme() async {
    final current = ref.read(themeChoiceProvider);
    final picked = await showDialog<AppThemeChoice>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Theme'),
        children: [
          for (final c in AppThemeChoice.values)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, c),
              child: Row(
                children: [
                  Icon(c == current
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked),
                  const SizedBox(width: 12),
                  Icon(c.icon, size: 20),
                  const SizedBox(width: 10),
                  Text(c.label),
                ],
              ),
            ),
        ],
      ),
    );
    if (picked == null) return;
    await ref.read(themeChoiceProvider.notifier).set(picked);
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
    final user = ref.watch(authUserProvider).valueOrNull;
    final signedIn = user != null && !user.isAnonymous;
    // Linking Google to an anonymous user doesn't copy name/photo to the
    // top-level User — read them from the linked provider entry.
    final google = signedIn
        ? user.providerData
            .where((p) => p.providerId == 'google.com')
            .cast<UserInfo?>()
            .firstWhere((_) => true, orElse: () => null)
        : null;
    final accountName =
        user?.displayName ?? google?.displayName ?? 'User';
    final accountEmail = user?.email ?? google?.email;
    final accountPhoto = user?.photoURL ?? google?.photoURL;
    final language = ref.watch(reflectionLanguageProvider);
    final languageLabel = reflectionLanguageOptions.entries
        .firstWhere((e) => e.value == language,
            orElse: () => reflectionLanguageOptions.entries.first)
        .key;
    final themeChoice = ref.watch(themeChoiceProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          // ── Account ──────────────────────────────────────────────
          ListTile(
            leading: CircleAvatar(
              backgroundImage:
                  accountPhoto != null ? NetworkImage(accountPhoto) : null,
              child: accountPhoto != null
                  ? null
                  : Icon(signedIn ? Icons.person : Icons.person_outline),
            ),
            title: Text(signedIn
                ? (accountName ?? 'Google account')
                : 'Not signed in'),
            subtitle: Text(signedIn
                ? (accountEmail ?? 'Synced to your Google account')
                : 'Anonymous — data lives only on this phone. Sign in to '
                    'keep it forever and sync across devices.'),
            isThreeLine: !signedIn,
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(Routes.profile),
          ),
          if (signedIn)
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Sign out'),
              onTap: _signOut,
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: FilledButton.icon(
                icon: const Icon(Icons.login),
                label: const Text('Sign in with Google'),
                onPressed: _signInGoogle,
              ),
            ),
          const Divider(),

          // ── Appearance ───────────────────────────────────────────
          ListTile(
            leading: Icon(themeChoice.icon),
            title: const Text('Theme'),
            subtitle: Text(themeChoice.label),
            onTap: _pickTheme,
          ),
          ListTile(
            leading: const Icon(Icons.translate),
            title: const Text('Reflection language'),
            subtitle: Text(languageLabel),
            onTap: _pickLanguage,
          ),
          const Divider(),

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
