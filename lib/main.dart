import 'package:flutter/material.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'data/services/notification_service.dart';

import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // On-device AI engine. Gemma weights need a HF token (license acceptance):
  // flutter run --dart-define=HUGGINGFACE_TOKEN=hf_xxx
  FlutterGemma.initialize(
    huggingFaceToken: const String.fromEnvironment('HUGGINGFACE_TOKEN'),
    maxDownloadRetries: 10,
  );

  await NotificationService.instance.init();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(
    const ProviderScope(
      child: SecondBrainApp(),
    ),
  );
}
