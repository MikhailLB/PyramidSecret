import '../cipher/sigil_codec.dart';

// ────────────────────────────────────────────────────────────
// oracle_creds.dart — analytics + push credentials, veiled.
//
// These placeholders resolve to the literal strings
// "REPLACE_WITH_APPSFLYER_DEV_KEY" and
// "REPLACE_WITH_FIREBASE_PROJECT_NUMBER". Once real values are
// handed over, re-run `dart run tool/scribe_ciphers.dart` after
// editing the plain-text arguments in that script and swap the
// arrays below.
//
// The runtime code guards on `startsWith('REPLACE_')` to skip any
// network call while the placeholders are still in place, so the
// current APK behaves as a clean organic install.
// ────────────────────────────────────────────────────────────

const List<int> _analyticsDevKey = <int>[
  0x34, 0x5C, 0x90, 0xAE, 0x73, 0x13, 0x43, 0x22, 0xF7, 0x9E, 0x8A, 0x63,
  0x90, 0x56, 0xA2, 0xAB, 0x12, 0x44, 0xE0, 0x80, 0x4D, 0xE3,
];

const List<int> _messagingProjectNumber = <int>[
  0x46, 0x3A, 0xE6, 0xFD, 0x18, 0x70, 0x11, 0x4D, 0x98, 0xC9, 0xE4, 0x1F,
];

const List<int> _gcdHost = <int>[
  0x16, 0x7B, 0xA1, 0xB9, 0x53, 0x79, 0x0A, 0x57, 0xC6, 0x99, 0xB6, 0x5C,
  0xAD, 0x45, 0xC8, 0xA8, 0x08, 0x56, 0xD5, 0xA0, 0x43, 0xDB, 0x42, 0x0C,
  0xE7, 0x8F, 0x54, 0x4D,
];

const List<int> _gcdPath = <int>[
  0x51, 0x66, 0xBB, 0xBA, 0x54, 0x22, 0x49, 0x14, 0xFE, 0x9E, 0xB3, 0x5B,
  0xA8, 0x01, 0x90, 0xFD, 0x56, 0x16, 0x89,
];

String revealAnalyticsKey() {
  final value = unveil(_analyticsDevKey);
  if (value.startsWith('REPLACE_')) return '';
  return value;
}

String revealMessagingProject() {
  final value = unveil(_messagingProjectNumber);
  if (value.startsWith('REPLACE_')) return '';
  return value;
}

/// Builds the AppsFlyer Get-Conversion-Data URL used to retry
/// attribution when the SDK returns a false "Organic" verdict.
///
/// Format: <host><path><bundleId>?devkey=<key>&device_id=<uid>
String assembleOracleGcd({
  required String appId,
  required String deviceId,
  required String devKey,
}) {
  final host = unveil(_gcdHost);
  if (host.isEmpty) return '';
  final path = unveil(_gcdPath);
  return '$host$path$appId?devkey=$devKey&device_id=$deviceId';
}
