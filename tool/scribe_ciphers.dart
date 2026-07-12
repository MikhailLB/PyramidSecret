// ────────────────────────────────────────────────────────────
// scribe_ciphers.dart — one-off encoder for env/* byte arrays.
//
// Run: `dart run tool/scribe_ciphers.dart`
//
// Paste the printed const lists into:
//   • lib/gray/env/portal_beacon.dart   (host + path fragments)
//   • lib/gray/env/oracle_creds.dart    (AppsFlyer key, Firebase#, GCD)
//   • lib/gray/core/desert_transport.dart (Chrome/WebKit UA fragments)
// ────────────────────────────────────────────────────────────

import '../lib/gray/cipher/sigil_codec.dart';

void _dump(String label, String plain) {
  final bytes = engrave(plain);
  final buf = StringBuffer('// $label  →  "$plain"\nconst <int>[');
  for (var i = 0; i < bytes.length; i++) {
    if (i % 12 == 0) buf.write('\n  ');
    buf.write('0x${bytes[i].toRadixString(16).padLeft(2, '0').toUpperCase()}, ');
  }
  buf.write('\n];\n');
  print(buf);
}

void main() {
  _dump('portal_beacon.host', 'https://pyramidseccret.com');
  _dump('portal_beacon.path', '/config.php');

  _dump('gcd.host', 'https://gcdsdk.appsflyer.com');
  _dump('gcd.path', '/install_data/v4.0/');

  _dump('chrome.version', '149.0.7827.163');
  _dump('webkit.version', '537.36');

  // Placeholders — the operator will re-run this script once real keys
  // are handed over, and paste the fresh arrays into env/oracle_creds.dart.
  _dump('appsflyer.key', 'REPLACE_WITH_APPSFLYER_DEV_KEY');
  _dump('firebase.project', 'REPLACE_WITH_FIREBASE_PROJECT_NUMBER');
}
