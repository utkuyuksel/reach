/// Chooses between real store/ad services and no-op dev stubs.
///
/// Defaults to **dev stubs** so the game runs fully without an AdMob or store
/// account. To exercise the real `google_mobile_ads` / `in_app_purchase`
/// integrations on a configured build, pass:
///
///   flutter run --dart-define=REACH_REAL_SERVICES=true
///
/// (and set the real ad unit IDs / IAP product id — see README → "Ads & IAP").
const bool kUseRealServices =
    bool.fromEnvironment('REACH_REAL_SERVICES', defaultValue: false);
