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
  0x2C, 0x4A, 0x85, 0x85, 0x61, 0x00, 0x60, 0x27, 0xF6, 0xB3, 0x86, 0x67,
  0x96, 0x6F, 0xB6, 0x99, 0x2B, 0x60, 0xEA, 0x9F, 0x6A, 0xF0, 0x78, 0x3A,
  0x8C, 0xBA, 0x64, 0x6B, 0x83, 0x30,
];

const List<int> _messagingProjectNumber = <int>[
  0x2C, 0x4A, 0x85, 0x85, 0x61, 0x00, 0x60, 0x27, 0xF6, 0xB3, 0x86, 0x67,
  0x96, 0x68, 0xAF, 0x9B, 0x3D, 0x64, 0xE7, 0x95, 0x6A, 0xFD, 0x77, 0x2C,
  0x86, 0xA6, 0x7E, 0x63, 0x92, 0x36, 0x05, 0xF4, 0x33, 0x4D, 0x90, 0x9B,
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
