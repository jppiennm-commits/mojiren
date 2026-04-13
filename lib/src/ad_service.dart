import 'dart:io';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'age_gate.dart';

class AdMobIds {
  static const androidAppId = 'ca-app-pub-4143663317477933~5659977244';
  static const iosAppId = 'ca-app-pub-4143663317477933~4819939802';

  static const androidBannerId = 'ca-app-pub-4143663317477933/9252784076';
  static const iosBannerId = 'ca-app-pub-4143663317477933/8324282577';

  static const androidRewardedId = 'ca-app-pub-4143663317477933/5177807691';
  static const iosRewardedId = 'ca-app-pub-4143663317477933/8912883048';

  static String get bannerAdUnitId {
    if (kIsWeb) {
      throw UnsupportedError('Banner ads are not configured for web.');
    }
    return Platform.isIOS ? iosBannerId : androidBannerId;
  }

  static String get rewardedAdUnitId {
    if (kIsWeb) {
      throw UnsupportedError('Rewarded ads are not configured for web.');
    }
    return Platform.isIOS ? iosRewardedId : androidRewardedId;
  }
}

class AudienceAdService extends ChangeNotifier {
  AudienceAdService._();

  static final AudienceAdService instance = AudienceAdService._();

  bool _initialized = false;
  AudienceAgeGroup? _group;
  RewardedAd? _rewardedAd;
  bool _rewardedLoading = false;

  AudienceAgeGroup? get group => _group;
  bool get isReady => _initialized && _group != null;
  bool get isRewardedReady => _rewardedAd != null;
  bool get isRewardedLoading => _rewardedLoading;

  Future<void> configureFor(AudienceAgeGroup group) async {
    final requestConfiguration = switch (group) {
      AudienceAgeGroup.under13 => RequestConfiguration(
          tagForChildDirectedTreatment: TagForChildDirectedTreatment.yes,
          tagForUnderAgeOfConsent: TagForUnderAgeOfConsent.yes,
          maxAdContentRating: MaxAdContentRating.g,
        ),
      AudienceAgeGroup.over13 => RequestConfiguration(
          tagForChildDirectedTreatment: TagForChildDirectedTreatment.no,
          tagForUnderAgeOfConsent: TagForUnderAgeOfConsent.no,
          maxAdContentRating: MaxAdContentRating.pg,
        ),
    };

    await MobileAds.instance.updateRequestConfiguration(requestConfiguration);
    if (!_initialized) {
      await MobileAds.instance.initialize();
      _initialized = true;
    }

    _group = group;
    _rewardedAd?.dispose();
    _rewardedAd = null;
    notifyListeners();
    unawaited(preloadRewardedAd());
  }

  Future<void> preloadRewardedAd() async {
    if (!_initialized || _group == null || _rewardedAd != null || _rewardedLoading) {
      return;
    }

    _rewardedLoading = true;
    notifyListeners();

    await RewardedAd.load(
      adUnitId: AdMobIds.rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedLoading = false;
          _rewardedAd = ad;
          notifyListeners();
        },
        onAdFailedToLoad: (_) {
          _rewardedLoading = false;
          _rewardedAd = null;
          notifyListeners();
        },
      ),
    );
  }

  Future<bool> showRewardedAd() async {
    final ad = _rewardedAd;
    if (ad == null) {
      unawaited(preloadRewardedAd());
      return false;
    }

    _rewardedAd = null;
    notifyListeners();

    final completer = Completer<bool>();
    var rewardEarned = false;

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        if (!completer.isCompleted) {
          completer.complete(rewardEarned);
        }
        unawaited(preloadRewardedAd());
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        ad.dispose();
        if (!completer.isCompleted) {
          completer.complete(false);
        }
        unawaited(preloadRewardedAd());
      },
    );

    await ad.show(
      onUserEarnedReward: (_, __) {
        rewardEarned = true;
      },
    );

    return completer.future;
  }
}
