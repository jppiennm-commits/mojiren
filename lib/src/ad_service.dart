import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'age_gate.dart';

class AdMobIds {
  static const androidAppId = 'ca-app-pub-3940256099942544~3347511713';
  static const iosAppId = 'ca-app-pub-3940256099942544~1458002511';

  static const androidBannerTestId = 'ca-app-pub-3940256099942544/9214589741';
  static const iosBannerTestId = 'ca-app-pub-3940256099942544/2435281174';

  static String get bannerAdUnitId {
    if (kIsWeb) {
      throw UnsupportedError('Banner ads are not configured for web.');
    }
    return Platform.isIOS ? iosBannerTestId : androidBannerTestId;
  }
}

class AudienceAdService extends ChangeNotifier {
  AudienceAdService._();

  static final AudienceAdService instance = AudienceAdService._();

  bool _initialized = false;
  AudienceAgeGroup? _group;

  AudienceAgeGroup? get group => _group;
  bool get isReady => _initialized && _group != null;

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
    notifyListeners();
  }
}
