import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/providers/entitlement_provider.dart';

/// Shown at the value moment (2nd weekly recap / tapping a premium insight).
class PaywallScreen extends ConsumerStatefulWidget {
  const PaywallScreen({super.key});

  @override
  ConsumerState<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends ConsumerState<PaywallScreen> {
  bool _busy = false;

  Future<void> _buy() async {
    setState(() => _busy = true);
    final ok = await ref
        .read(entitlementServiceProvider)
        .purchaseCurrentOffering(annual: true);
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      context.pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Purchase not completed. '
                '(In dev, configure RevenueCat first.)')),
      );
    }
  }

  Future<void> _restore() async {
    await ref.read(entitlementServiceProvider).restore();
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Purchases restored.')));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Premium')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8),
            Text('Go deeper with Premium', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 16),
            const _Perk('Unlimited daily reflections'),
            const _Perk('Monthly "Wrapped" recap'),
            const _Perk('Deeper, cloud-quality weekly insights'),
            const _Perk('Trend graphs over time'),
            const Spacer(),
            FilledButton(
              onPressed: _busy ? null : _buy,
              child: _busy
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Start 7-day free trial'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _restore,
              child: const Text('Restore purchases'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Perk extends StatelessWidget {
  const _Perk(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline),
          const SizedBox(width: 12),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
