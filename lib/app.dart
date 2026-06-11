import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'shared/providers/entitlement_provider.dart';

class SecondBrainApp extends ConsumerStatefulWidget {
  const SecondBrainApp({super.key});

  @override
  ConsumerState<SecondBrainApp> createState() => _SecondBrainAppState();
}

class _SecondBrainAppState extends ConsumerState<SecondBrainApp> {
  @override
  void initState() {
    super.initState();
    // Billing (no-op until the RevenueCat key is configured).
    Future.microtask(() => ref.read(entitlementServiceProvider).init());
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'Second Brain',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      routerConfig: router,
    );
  }
}
