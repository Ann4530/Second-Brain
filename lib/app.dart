import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'shared/providers/entitlement_provider.dart';
import 'shared/providers/settings_providers.dart';

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
    final themeChoice = ref.watch(themeChoiceProvider);
    final cosmic = themeChoice == AppThemeChoice.cosmic;

    return MaterialApp.router(
      title: 'Second Brain',
      debugShowCheckedModeBanner: false,
      theme: cosmic ? AppTheme.cosmic : AppTheme.light,
      darkTheme: cosmic ? AppTheme.cosmic : AppTheme.dark,
      themeMode: switch (themeChoice) {
        AppThemeChoice.light => ThemeMode.light,
        AppThemeChoice.dark => ThemeMode.dark,
        AppThemeChoice.cosmic => ThemeMode.dark, // cosmic is always dark
        AppThemeChoice.system => ThemeMode.system,
      },
      routerConfig: router,
    );
  }
}
