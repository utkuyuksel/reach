/// In-app purchase configuration in ONE place.
///
/// Products:
///   * a single non-consumable **Premium** (~US$3.99) — removes ads, unlimited
///     hints, unlocks all cosmetic themes;
///   * **consumable coin packs** — grant coins (spent on hints and cosmetics).
///
/// TODO: create these products in App Store Connect and Google Play Console
///       with the SAME IDs, then replace the placeholders. Prices are set in
///       the store consoles. See README → "Ads & IAP setup".
class IapConfig {
  /// Non-consumable Premium unlock.
  static const String premiumProductId = 'com.utkuyuksel.reach.premium';

  /// Consumable coin packs: product id → coins granted.
  static const Map<String, int> coinPacks = {
    'com.utkuyuksel.reach.coins_small': 250,
    'com.utkuyuksel.reach.coins_medium': 700,
    'com.utkuyuksel.reach.coins_large': 2000,
  };

  /// Coin packs in display order.
  static const List<String> coinPackOrder = [
    'com.utkuyuksel.reach.coins_small',
    'com.utkuyuksel.reach.coins_medium',
    'com.utkuyuksel.reach.coins_large',
  ];

  /// All product IDs queried on launch.
  static Set<String> get productIds => {premiumProductId, ...coinPacks.keys};

  static bool isCoinPack(String productId) => coinPacks.containsKey(productId);

  /// Coins granted by [productId] (0 if it isn't a coin pack).
  static int coinsFor(String productId) => coinPacks[productId] ?? 0;
}
