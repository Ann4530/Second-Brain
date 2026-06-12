import 'package:firebase_auth/firebase_auth.dart' show UserInfo;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../shared/providers/app_providers.dart';

/// User profile management: avatar, editable display name, account type,
/// member-since, entry count, sign in/out, delete.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _nameController = TextEditingController();
  bool _editingName = false;
  bool _busy = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  UserInfo? _googleInfo(user) {
    for (final p in user.providerData) {
      if (p.providerId == 'google.com') return p;
    }
    return null;
  }

  Future<void> _saveName() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    setState(() => _busy = true);
    await ref.read(authServiceProvider).updateDisplayName(name);
    ref.invalidate(authUserProvider);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _editingName = false;
    });
  }

  Future<void> _signInGoogle() async {
    setState(() => _busy = true);
    try {
      await ref.read(authServiceProvider).signInWithGoogle();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Sign-in failed: $e')));
      }
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _signOut() async {
    await ref.read(authServiceProvider).signOut();
    if (mounted) setState(() {});
  }

  Future<void> _deleteAll() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete account & data?'),
        content: const Text(
            'Permanently deletes all your entries. This cannot be undone.'),
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
    if (ok != true) return;
    await ref.read(entryRepositoryProvider).deleteAll();
    ref.invalidate(allEntriesProvider);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('All data deleted.')));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = ref.watch(authUserProvider).valueOrNull;
    final entryCount = ref.watch(allEntriesProvider).valueOrNull?.length ?? 0;

    final signedIn = user != null && !user.isAnonymous;
    final google = (user != null) ? _googleInfo(user) : null;
    final name = user?.displayName ?? google?.displayName;
    final email = user?.email ?? google?.email;
    final photo = user?.photoURL ?? google?.photoURL;
    final created = user?.metadata.creationTime;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: CircleAvatar(
              radius: 44,
              backgroundImage: photo != null ? NetworkImage(photo) : null,
              child: photo == null
                  ? const Icon(Icons.person, size: 44)
                  : null,
            ),
          ),
          const SizedBox(height: 20),

          // ── Display name (editable) ──
          if (_editingName)
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _nameController,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'Display name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.check),
                  onPressed: _busy ? null : _saveName,
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => setState(() => _editingName = false),
                ),
              ],
            )
          else
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(name ?? 'User', style: theme.textTheme.titleMedium),
              subtitle: Text(email ?? 'Anonymous account'),
              trailing: signedIn
                  ? IconButton(
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () {
                        _nameController.text = name ?? '';
                        setState(() => _editingName = true);
                      },
                    )
                  : null,
            ),
          const Divider(height: 32),

          _InfoRow(
            icon: Icons.verified_user_outlined,
            label: 'Account type',
            value: signedIn ? 'Google' : 'Anonymous (local only)',
          ),
          _InfoRow(
            icon: Icons.book_outlined,
            label: 'Entries',
            value: '$entryCount',
          ),
          if (created != null)
            _InfoRow(
              icon: Icons.calendar_today_outlined,
              label: 'Member since',
              value: DateFormat.yMMMMd().format(created),
            ),
          const SizedBox(height: 24),

          if (signedIn)
            OutlinedButton.icon(
              icon: const Icon(Icons.logout),
              label: const Text('Sign out'),
              onPressed: _busy ? null : _signOut,
            )
          else
            FilledButton.icon(
              icon: const Icon(Icons.login),
              label: const Text('Sign in with Google'),
              onPressed: _busy ? null : _signInGoogle,
            ),
          const SizedBox(height: 8),
          if (!signedIn)
            Text(
              'Sign in to keep your journal forever and sync across devices.',
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          const SizedBox(height: 24),
          TextButton.icon(
            icon: Icon(Icons.delete_forever_outlined,
                color: theme.colorScheme.error),
            label: Text('Delete account & data',
                style: TextStyle(color: theme.colorScheme.error)),
            onPressed: _deleteAll,
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(
      {required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 14),
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          const Spacer(),
          Text(value,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
