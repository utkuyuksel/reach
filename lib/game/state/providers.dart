import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/ad_service.dart';
import '../../services/analytics_service.dart';
import '../../services/purchase_service.dart';
import '../../services/remote_config_service.dart';
import '../../services/sound_service.dart';
import '../../services/storage_service.dart';
import '../theme/palette.dart';
import 'entitlement_controller.dart';
import 'settings_controller.dart';

/// Service providers. These are overridden in `main()` with concrete (real or
/// dev) implementations, so reading them before that is a programming error.
final storageServiceProvider = Provider<StorageService>(
  (ref) => throw UnimplementedError('Override storageServiceProvider in main()'),
);

final adServiceProvider = Provider<AdService>(
  (ref) => throw UnimplementedError('Override adServiceProvider in main()'),
);

final purchaseServiceProvider = Provider<PurchaseService>(
  (ref) => throw UnimplementedError('Override purchaseServiceProvider in main()'),
);

final analyticsServiceProvider = Provider<AnalyticsService>(
  (ref) => throw UnimplementedError('Override analyticsServiceProvider in main()'),
);

final remoteConfigServiceProvider = Provider<RemoteConfigService>(
  (ref) =>
      throw UnimplementedError('Override remoteConfigServiceProvider in main()'),
);

final soundServiceProvider = Provider<SoundService>(
  (ref) => throw UnimplementedError('Override soundServiceProvider in main()'),
);

/// The active tunable game configuration (economy, ads, stars).
final gameConfigProvider = Provider<GameConfig>(
  (ref) => ref.watch(remoteConfigServiceProvider).config,
);

/// The palette to render with: the user's selection if it's unlocked (free,
/// owned, or Premium for coin-priced ones; exclusives are owned-or-nothing),
/// otherwise the free default.
final paletteProvider = Provider<GamePalette>((ref) {
  final settings = ref.watch(settingsControllerProvider);
  final premium = ref.watch(entitlementControllerProvider);
  final selected = GamePalette.byId(settings.paletteId);
  final owned = settings.ownedPaletteIds.contains(selected.id);
  final unlocked =
      selected.exclusive ? owned : (selected.isFree || premium || owned);
  return unlocked ? selected : GamePalette.clay;
});
