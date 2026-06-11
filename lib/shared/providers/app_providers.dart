import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/env/app_config.dart';
import '../../data/models/entry.dart';
import '../../data/repositories/entry_repository.dart';
import '../../data/services/ai_router.dart';
import '../../data/services/ai_service.dart';
import '../../data/services/crypto_service.dart';
import '../../data/services/groq_ai_service.dart';
import '../../data/services/on_device_ai_service.dart';

/// True once `flutterfire configure` has been run and Firebase.initializeApp
/// succeeded in main(). Everything Firebase-dependent gates on this so the
/// app runs end-to-end in dev without a Firebase project.
final firebaseReadyProvider = Provider<bool>((ref) => Firebase.apps.isNotEmpty);

/// Anonymous-first auth: sign in silently so entries can sync; upgrade to
/// Google later from Settings without losing data (linkWithCredential).
final authUserProvider = FutureProvider<User?>((ref) async {
  if (!ref.watch(firebaseReadyProvider)) return null;
  final auth = FirebaseAuth.instance;
  if (auth.currentUser != null) return auth.currentUser;
  final cred = await auth.signInAnonymously();
  return cred.user;
});

/// "On-device only" privacy toggle (persist to settings later).
final privacyModeProvider = StateProvider<bool>(
  (ref) => AppConfig.privacyModeDefault,
);

/// Premium entitlement — kept in sync by EntitlementService (RevenueCat).
final isPremiumProvider = StateProvider<bool>((ref) => false);

final cryptoServiceProvider = Provider<CryptoService>(
  (ref) => CryptoService(),
);

final onDeviceAiProvider = Provider<OnDeviceAiService>(
  (ref) => OnDeviceAiService(),
);

final groqAiProvider = Provider<GroqAiService>(
  (ref) => GroqAiService(),
);

/// The engine-agnostic AI entry point the app uses everywhere.
final aiServiceProvider = Provider<AiService>((ref) {
  return AiRouter(
    onDevice: ref.watch(onDeviceAiProvider),
    cloud: ref.watch(groqAiProvider),
    privacyModeOnly: ref.watch(privacyModeProvider),
    isPremium: ref.watch(isPremiumProvider),
  );
});

/// A single, stable in-memory store. Kept in its own dependency-free provider
/// so it is NOT recreated when entryRepositoryProvider rebuilds (e.g. on the
/// auth-state flicker). Without this, switching tabs could drop the day's
/// saved entry and bounce the Today screen back to the composer.
final _inMemoryRepoProvider =
    Provider<InMemoryEntryRepository>((ref) => InMemoryEntryRepository());

/// Entry storage: Firestore (encrypted at rest) once Firebase + auth are up,
/// otherwise the stable in-memory store so the app still works in dev.
final entryRepositoryProvider = Provider<EntryRepository>((ref) {
  final uid = ref.watch(authUserProvider).valueOrNull?.uid;
  if (ref.watch(firebaseReadyProvider) && uid != null) {
    return FirestoreEntryRepository(
      uid: uid,
      crypto: ref.watch(cryptoServiceProvider),
    );
  }
  return ref.watch(_inMemoryRepoProvider);
});

/// All saved entries, newest first. Shared by History, Insights and the streak.
/// Invalidate this after saving a new entry so every screen refreshes.
final allEntriesProvider = FutureProvider<List<Entry>>(
  (ref) => ref.watch(entryRepositoryProvider).all(),
);
