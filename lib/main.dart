import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'config/service_config.dart';
import 'game/app.dart';
import 'game/state/providers.dart';
import 'services/ad_service.dart';
import 'services/analytics_service.dart';
import 'services/google_ad_service.dart';
import 'services/prefs_storage_service.dart';
import 'services/purchase_service.dart';
import 'services/remote_config_service.dart';
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

  // Analytics: console logger in dev. TODO: wire a real provider (e.g. Firebase
  // Analytics) for the real-services build instead of the no-op.
  final AnalyticsService analytics =
      kUseRealServices ? NoopAnalyticsService() : DebugAnalyticsService();
  await analytics.init();

  runApp(
    ProviderScope(
      overrides: [
        storageServiceProvider.overrideWithValue(storage),
        adServiceProvider.overrideWithValue(ad),
        purchaseServiceProvider.overrideWithValue(purchase),
        remoteConfigServiceProvider.overrideWithValue(remoteConfig),
        analyticsServiceProvider.overrideWithValue(analytics),
      ],
      child: const ReachApp(),
    ),
  );
}
