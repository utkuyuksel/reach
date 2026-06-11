/// In-app purchase configuration in ONE place.
///
/// Products:
///   * a single non-consumable **Premium** (~US$7.99) — removes ads, grants
///     daily free hints, unlocks all coin-priced themes;
///   * a one-time **Starter Pack** (~US$1.99) — coins + the exclusive "Ember"
///     theme + a Streak Freeze token;
///   * **consumable coin packs** — grant coins (spent on hints, streak
///     protection, and cosmetics). The value-per-dollar curve is monotonic
///     (each tier up is a better deal) for honest anchoring.
///
/// TODO: create these products in App Store Connect and Google Play Console
///       with the SAME IDs, then replace the placeholders. Prices are set in
///       the store consoles. See README → "Ads & IAP setup".
class IapConfig {
  /// Non-consumable Premium unlock.
  static const String premiumProductId = 'com.utkuyuksel.reach.premium';

  /// One-time Starter Pack (non-consumable so it can't be re-bought):
  /// 500 coins + the exclusive Ember theme + 1 Streak Freeze token.
  static const String starterPackProductId = 'com.utkuyuksel.reach.starter';
  static const int starterPackCoins = 500;
  static const String starterPackPaletteId = 'ember';

  /// Consumable coin packs: product id → coins granted.
  /// Monotonic value curve at the intended store prices
  /// ($0.99 / $2.99 / $6.99): ≈202 → ≈268 → ≈315 coins per dollar.
  static const Map<String, int> coinPacks = {
    'com.utkuyuksel.reach.coins_small': 200,
    'com.utkuyuksel.reach.coins_medium': 800,
    'com.utkuyuksel.reach.coins_large': 2200,
  };

  /// Coin packs in display order.
  static const List<String> coinPackOrder = [
    'com.utkuyuksel.reach.coins_small',
    'com.utkuyuksel.reach.coins_medium',
    'com.utkuyuksel.reach.coins_large',
  ];

  /// All product IDs queried on launch.
  static Set<String> get productIds =>
      {premiumProductId, starterPackProductId, ...coinPacks.keys};

  static bool isCoinPack(String productId) => coinPacks.containsKey(productId);

  /// Coins granted by [productId] (0 if it isn't a coin pack).
  static int coinsFor(String productId) => coinPacks[productId] ?? 0;
}
