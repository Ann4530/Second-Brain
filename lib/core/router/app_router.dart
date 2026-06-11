import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/history/history_screen.dart';
import '../../features/insights/insights_screen.dart';
import '../../features/journal/today_screen.dart';
import '../../features/onboarding/onboarding_screen.dart';
import '../../features/paywall/paywall_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../shared/widgets/home_shell.dart';

/// Route names/paths in one place.
class Routes {
  Routes._();
  static const onboarding = '/onboarding';
  static const today = '/today';
  static const history = '/history';
  static const insights = '/insights';
  static const settings = '/settings';
  static const paywall = '/paywall';
}

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: Routes.today,
    routes: [
      GoRoute(
        path: Routes.onboarding,
        builder: (_, __) => const OnboardingScreen(),
      ),
      GoRoute(
        path: Routes.paywall,
        builder: (_, __) => const PaywallScreen(),
      ),
      // Bottom-nav shell for the main tabs.
      StatefulShellRoute.indexedStack(
        builder: (_, __, shell) => HomeShell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: Routes.today, builder: (_, __) => const TodayScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
                path: Routes.history,
                builder: (_, __) => const HistoryScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
                path: Routes.insights,
                builder: (_, __) => const InsightsScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
                path: Routes.settings,
                builder: (_, __) => const SettingsScreen()),
          ]),
        ],
      ),
    ],
    errorBuilder: (_, state) => Scaffold(
      body: Center(child: Text('Route error: ${state.error}')),
    ),
  );
});
