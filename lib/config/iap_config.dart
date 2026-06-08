/// In-app purchase configuration in ONE place.
///
/// REACH has a single non-consumable "Premium" product (~US$3.99) that removes
/// ads, unlocks unlimited hints, and unlocks cosmetic themes.
///
/// TODO: create this product in App Store Connect and Google Play Console with
///       the SAME product ID, then replace the placeholder below. See README →
///       "Ads & IAP setup". Price is configured in the store consoles, not here.
class IapConfig {
  /// Store product ID for the one-time Premium unlock. Placeholder — must match
  /// the product you create in both stores.
  static const String premiumProductId = 'com.reach.reach.premium';

  /// All product IDs the app queries on launch.
  static const Set<String> productIds = {premiumProductId};
}
