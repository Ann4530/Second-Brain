import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../../core/env/app_config.dart';
import 'app_providers.dart';

/// Wires RevenueCat: configure once, listen to entitlement changes, and keep
/// [isPremiumProvider] in sync. No-ops gracefully when the key isn't set yet
/// (dev) so the app runs before billing is configured.
class EntitlementService {
  EntitlementService(this._ref);
  final Ref _ref;
  bool _configured = false;

  Future<void> init({String? appUserId}) async {
    if (_configured) return;
    if (AppConfig.revenueCatAndroidKey.isEmpty || !Platform.isAndroid) {
      debugPrint('RevenueCat key not set — running without billing (dev).');
      return;
    }
    await Purchases.setLogLevel(
        kDebugMode ? LogLevel.debug : LogLevel.warn);
    await Purchases.configure(
      PurchasesConfiguration(AppConfig.revenueCatAndroidKey)
        ..appUserID = appUserId,
    );
    Purchases.addCustomerInfoUpdateListener(_onCustomerInfo);
    _onCustomerInfo(await Purchases.getCustomerInfo());
    _configured = true;
  }

  void _onCustomerInfo(CustomerInfo info) {
    final active = info.entitlements.active
        .containsKey(AppConfig.premiumEntitlementId);
    _ref.read(isPremiumProvider.notifier).state = active;
  }

  /// Buy the first package of the current offering (call from the paywall).
  Future<bool> purchaseCurrentOffering({bool annual = true}) async {
    if (!_configured) return false;
    final offerings = await Purchases.getOfferings();
    final offering = offerings.current;
    if (offering == null) return false;
    final fallback = offering.availablePackages.isEmpty
        ? null
        : offering.availablePackages.first;
    final pkg =
        annual ? (offering.annual ?? fallback) : (offering.monthly ?? fallback);
    if (pkg == null) return false;
    try {
      final customerInfo = await Purchases.purchasePackage(pkg);
      return customerInfo.entitlements.active
          .containsKey(AppConfig.premiumEntitlementId);
    } on PlatformException {
      return false; // user cancelled or store error
    }
  }

  Future<void> restore() async {
    if (!_configured) return;
    _onCustomerInfo(await Purchases.restorePurchases());
  }
}

final entitlementServiceProvider = Provider<EntitlementService>(
  (ref) => EntitlementService(ref),
);
