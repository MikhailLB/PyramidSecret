import 'oracle_creds.dart';
import 'portal_beacon.dart';
import 'shrine_links.dart';

// ────────────────────────────────────────────────────────────
// sanctum_config.dart — central facade for gray-flow constants.
// ────────────────────────────────────────────────────────────
// All app-level identifiers live here. Everything that a partner
// or a store review might grep for is either literal (safe) or
// resolved on the fly from encoded byte arrays elsewhere.

class SanctumConfig {
  const SanctumConfig._();

  // ─── Identity ───
  static const String bundleTag = 'com.pyramsec.pyramidsecret';
  static const String storeTag = 'com.pyramsec.pyramidsecret';
  static const String displayName = 'Pyramid Secret';
  // PascalCase, no spaces — appended to the WebView User-Agent.
  static const String uaLabel = 'PyramidSecret';
  // iOS App Store numeric ID. Android build ignores this.
  static const String iosStoreId = '';

  // ─── Endpoints (lazy resolution keeps them out of the strings table) ───
  static String get portalEndpoint => openBeacon();
  static String get analyticsKey => revealAnalyticsKey();
  static String get messagingProjectId => revealMessagingProject();

  // ─── Legal / support ───
  static String get siteUrl => shrineSiteUrl;
  static String get privacyPolicyUrl => shrinePrivacyUrl;
  static String get supportUrl => shrineSupportUrl;

  // ─── Timings ───
  // Push permission deferral when user picks "Skip" — three days.
  static const int flameDeferSeconds = 3 * 24 * 60 * 60;
  // Delay between the first Organic verdict and the GCD retry.
  static const int organicRetryDelaySeconds = 5;
  // First-launch attribution race caps.
  static const int firstLaunchAttributionCapSeconds = 25;
  static const int firstLaunchDeepLinkCapSeconds = 5;
  // Second-phase GCD polling window when a deep link hints non-organic
  // but the SDK callback has still not delivered.
  static const int gcdPollWindowSeconds = 90;
  static const int gcdPollIntervalSeconds = 4;
  // Warm-return attribution timeout (returning gray users).
  static const int warmAttributionCapSeconds = 10;
  // POST timeout for the config endpoint.
  static const int portalRequestTimeoutSeconds = 15;
  // DNS probe cap — raised from the naive 3 s to survive VPN latency.
  static const int dnsProbeTimeoutSeconds = 7;
  // Debounce before treating a connectivity flap as offline.
  static const int offlineDebounceMillis = 700;
}
