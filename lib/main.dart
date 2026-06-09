import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'config/service_config.dart';
import 'firebase_options.dart';
import 'game/app.dart';
import 'game/state/providers.dart';
import 'services/ad_service.dart';
import 'services/analytics_service.dart';
import 'services/firebase_analytics_service.dart';
import 'services/google_ad_service.dart';
import 'services/prefs_storage_service.dart';
import 'services/purchase_service.dart';
import 'services/remote_config_service.dart';
import 'services/sound_service.dart';
import 'services/storage_service.dart';
import 'services/store_purchase_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Portrait, one-hand reachable.
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Persistence is always real; ads/IAP default to no-op dev stubs so the game
  // runs without store/ad accounts (see service_config.dart to enable real
  // services with --dart-define=REACH_REAL_SERVICES=true).
  final StorageService storage = PrefsStorageService();
  await storage.init();

  final AdService ad = kUseRealServices ? GoogleAdService() : DevAdService();
  final PurchaseService purchase =
      kUseRealServices ? StorePurchaseService() : DevPurchaseService();
  await ad.init();
  await purchase.init();

  // Tunable config (local defaults; swap for a real remote backend later).
  final RemoteConfigService remoteConfig = LocalRemoteConfigService();
  await remoteConfig.init();

  // Analytics: console logger in dev; Firebase Analytics in the real-services
  // build. Firebase is initialized from lib/firebase_options.dart (Dart-only,
  // no native config-file bundling needed), and ONLY when real services are on
  // so dev/test builds never touch Firebase.
  if (kUseRealServices) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }
  final AnalyticsService analytics =
      kUseRealServices ? FirebaseAnalyticsService() : DebugAnalyticsService();
  await analytics.init();

  final SoundService sound = AudioPlayersSoundService();
  await sound.init();

  runApp(
    ProviderScope(
      overrides: [
        storageServiceProvider.overrideWithValue(storage),
        adServiceProvider.overrideWithValue(ad),
        purchaseServiceProvider.overrideWithValue(purchase),
        remoteConfigServiceProvider.overrideWithValue(remoteConfig),
        analyticsServiceProvider.overrideWithValue(analytics),
        soundServiceProvider.overrideWithValue(sound),
      ],
      child: const ReachApp(),
    ),
  );
}
