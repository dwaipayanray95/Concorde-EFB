import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Google UMP (User Messaging Platform) consent flow for AdMob -- Android/
/// iOS only, desktop and web have no ads.
///
/// Google requires a certified consent tool before showing ads to users in
/// the EEA, UK and Switzerland. UMP decides per user whether a form is
/// needed: users elsewhere never see it. Ads (and the AdMob SDK itself) are
/// only started once [ConsentInformation.canRequestAds] is true.
class AdConsentService {
  AdConsentService._();

  static bool get isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  /// Flips to true once consent allows ads and the AdMob SDK is initialised.
  /// Ad widgets listen to this instead of loading ads straight away.
  static final ValueNotifier<bool> adsReady = ValueNotifier(false);

  /// Whether the user must be offered a way to change their choice (shown
  /// as "Privacy options" in the app's settings).
  static final ValueNotifier<bool> privacyOptionsRequired = ValueNotifier(
    false,
  );

  static bool _started = false;

  /// Requests the latest consent status, shows the consent form if this
  /// user needs one, then starts AdMob if ads are allowed. Safe to call
  /// more than once; must run after the first frame (the form needs an
  /// activity to attach to).
  static Future<void> gatherConsentAndStartAds() async {
    if (!isSupported || _started) return;
    _started = true;

    final updated = Completer<void>();
    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(),
      () => updated.complete(),
      (FormError error) {
        debugPrint('UMP consent update failed: ${error.message}');
        updated.complete(); // fall through: a previous consent may still apply
      },
    );
    await updated.future;

    await ConsentForm.loadAndShowConsentFormIfRequired((FormError? error) {
      if (error != null) debugPrint('UMP consent form error: ${error.message}');
    });

    await _refreshPrivacyOptions();
    await _startAdsIfAllowed();
  }

  /// Re-opens the consent form so the user can change or withdraw consent.
  static Future<void> showPrivacyOptions() async {
    if (!isSupported) return;
    await ConsentForm.showPrivacyOptionsForm((FormError? error) {
      if (error != null) debugPrint('UMP privacy form error: ${error.message}');
    });
    await _startAdsIfAllowed();
  }

  static Future<void> _refreshPrivacyOptions() async {
    final status = await ConsentInformation.instance
        .getPrivacyOptionsRequirementStatus();
    privacyOptionsRequired.value =
        status == PrivacyOptionsRequirementStatus.required;
  }

  static Future<void> _startAdsIfAllowed() async {
    if (adsReady.value) return;
    if (!await ConsentInformation.instance.canRequestAds()) return;
    await MobileAds.instance.initialize();
    adsReady.value = true;
  }
}
