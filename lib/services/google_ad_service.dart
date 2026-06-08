import 'dart:async';

import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../config/ad_config.dart';
import 'ad_service.dart';

/// Real [AdService] backed by `google_mobile_ads`. Selected only when the app
/// is built with real services enabled (see `service_config.dart`); otherwise
/// [DevAdService] is used so development needs no AdMob account.
///
/// Uses Google's **test** ad unit IDs from [AdConfig] until you replace them.
class GoogleAdService implements AdService {
  RewardedAd? _rewarded;
  InterstitialAd? _interstitial;

  @override
  Future<void> init() async {
    await MobileAds.instance.initialize();
    _loadRewarded();
    _loadInterstitial();
  }

  void _loadRewarded() {
    RewardedAd.load(
      adUnitId: AdConfig.rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) => _rewarded = ad,
        onAdFailedToLoad: (_) => _rewarded = null,
      ),
    );
  }

  void _loadInterstitial() {
    InterstitialAd.load(
      adUnitId: AdConfig.interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) => _interstitial = ad,
        onAdFailedToLoad: (_) => _interstitial = null,
      ),
    );
  }

  @override
  Future<bool> showRewardedAd() async {
    final ad = _rewarded;
    if (ad == null) {
      _loadRewarded(); // not ready — try again for next time
      return false;
    }
    _rewarded = null;
    final completer = Completer<bool>();
    var earned = false;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _loadRewarded();
        if (!completer.isCompleted) completer.complete(earned);
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        ad.dispose();
        _loadRewarded();
        if (!completer.isCompleted) completer.complete(false);
      },
    );
    ad.show(onUserEarnedReward: (_, _) => earned = true);
    return completer.future;
  }

  @override
  Future<void> showInterstitial() async {
    final ad = _interstitial;
    if (ad == null) {
      _loadInterstitial();
      return;
    }
    _interstitial = null;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _loadInterstitial();
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        ad.dispose();
        _loadInterstitial();
      },
    );
    await ad.show();
  }

  @override
  void dispose() {
    _rewarded?.dispose();
    _interstitial?.dispose();
  }
}
