import 'persisted_models.dart';

/// Local persistence behind an interface so it can be mocked in tests and,
/// later, replaced/augmented by cloud sync without touching game logic.
///
/// Implementations load synchronously from an in-memory cache after [init]
/// (so the UI can read without awaiting) and persist writes asynchronously.
abstract class StorageService {
  /// Load everything into memory. Call once before reading.
  Future<void> init();

  Settings loadSettings();
  Future<void> saveSettings(Settings settings);

  /// Premium entitlement (the cached value; re-verified via the purchase
  /// service's restore on launch).
  bool loadPremium();
  Future<void> savePremium(bool premium);

  DailyRecord loadDaily();
  Future<void> saveDaily(DailyRecord record);

  ZenRecord loadZen();
  Future<void> saveZen(ZenRecord record);

  StatsRecord loadStats();
  Future<void> saveStats(StatsRecord record);

  MosaicRecord loadMosaic();
  Future<void> saveMosaic(MosaicRecord record);

  /// The coin wallet, or null if it has never been initialised (first launch —
  /// the caller grants starting coins).
  WalletRecord? loadWallet();
  Future<void> saveWallet(WalletRecord record);
}
