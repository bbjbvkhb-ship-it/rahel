import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdService {
  static final AdService _instance = AdService._internal();
  factory AdService() => _instance;
  AdService._internal();

  InterstitialAd? _interstitialAd;
  bool _isInterstitialAdLoading = false;

  // Production Ad Unit ID provided by the user
  static const String interstitialAdUnitId = 'ca-app-pub-3636946633767150/9079213004';
  
  // Banner Ad Unit ID (uses test banner ID, can be replaced by production banner ID later)
  static const String bannerAdUnitId = 'ca-app-pub-3940256099942544/2934735716';

  /// Pre-loads the Interstitial Ad so that it's ready to show
  void loadInterstitialAd() {
    if (_interstitialAd != null || _isInterstitialAdLoading) return;
    
    _isInterstitialAdLoading = true;
    if (kDebugMode) print('Starting to load interstitial ad...');
    
    InterstitialAd.load(
      adUnitId: interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (InterstitialAd ad) {
          _interstitialAd = ad;
          _isInterstitialAdLoading = false;
          if (kDebugMode) print('Interstitial ad loaded successfully.');
        },
        onAdFailedToLoad: (LoadAdError error) {
          _interstitialAd = null;
          _isInterstitialAdLoading = false;
          if (kDebugMode) print('Failed to load interstitial ad: $error');
        },
      ),
    );
  }

  /// Shows the loaded Interstitial Ad. If not loaded, calls callback and retries loading.
  void showInterstitialAd({VoidCallback? onDismissed}) {
    if (_interstitialAd == null) {
      if (kDebugMode) print('Interstitial ad not ready to show yet.');
      onDismissed?.call();
      loadInterstitialAd(); // Trigger load for future use
      return;
    }

    _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (InterstitialAd ad) {
        if (kDebugMode) print('Interstitial ad dismissed.');
        ad.dispose();
        _interstitialAd = null;
        onDismissed?.call();
        loadInterstitialAd(); // Load next one for future use
      },
      onAdFailedToShowFullScreenContent: (InterstitialAd ad, AdError error) {
        if (kDebugMode) print('Failed to show interstitial ad: $error');
        ad.dispose();
        _interstitialAd = null;
        onDismissed?.call();
        loadInterstitialAd(); // Try reloading
      },
    );

    _interstitialAd!.show();
  }
}
