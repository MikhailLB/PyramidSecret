import 'dart:typed_data';

// ────────────────────────────────────────────────────────────
// SigilCodec — sensitive string veil for the Pyramid Secret gray path.
// ────────────────────────────────────────────────────────────
// The whole gray pipeline keeps its sensitive host names, dev keys
// and Firebase identifiers out of the compiled binary strings table.
// Values are stored as pre-computed byte arrays and revealed at
// runtime by [unveil] using a derived 24-byte rolling key.
//
// FINGERPRINT NOTE: the seed phrase, the LCG constants and the key
// length must remain unique per project — do not reuse them across
// installs living under the same publisher account.
//
// Steps to rotate the veil:
//   1. Replace the bytes returned by [_seed] with a fresh ASCII phrase.
//   2. Change any of the two constants inside [_forgeKey] if desired.
//   3. Re-run `dart run tool/scribe_ciphers.dart` to re-encode secrets.
//   4. Paste new byte arrays into the env/* files.

const List<int> _seed = <int>[
  0x73, 0x66, 0x6E, 0x78, 0x76, 0x6C, 0x74, // "sfnxvlt"
];

/// Derives the 24-byte rolling XOR key from the project seed.
///
/// Uses the Numerical Recipes LCG constants (1664525, 1013904223) and
/// folds high/low bytes together for extra spread. The output length
/// intentionally differs from the classical 16 to skew static analysis
/// tools that grep for common key sizes.
Uint8List _forgeKey() {
  if (_seed.isEmpty) return Uint8List(24);

  var state = _seed.fold<int>(
    0x5A5A5A5A,
    (acc, b) => ((acc ^ (b * 131 + 7)) & 0xFFFFFFFF),
  );
  final key = Uint8List(24);
  for (var i = 0; i < key.length; i++) {
    state = (state * 1664525 + 1013904223) & 0xFFFFFFFF;
    // Fold the top byte into the low byte to whiten the sequence.
    key[i] = ((state >> 8) ^ state) & 0xFF;
  }
  return key;
}

final Uint8List _sigilKey = _forgeKey();

/// Non-linear position hash — differs from a plain modulo so two
/// consecutive encoded bytes never touch the same key byte.
int _slot(int i) => ((i * 5) + (i >> 2)) % 24;

/// Reveals an encoded byte list back into its plaintext form.
///
/// Pass the byte arrays produced by `tool/scribe_ciphers.dart`.
String unveil(List<int> bytes) {
  if (bytes.isEmpty) return '';
  final out = Uint8List(bytes.length);
  for (var i = 0; i < bytes.length; i++) {
    out[i] = bytes[i] ^ _sigilKey[_slot(i)];
  }
  return String.fromCharCodes(out);
}

/// Encodes the given plaintext with the current key. Kept in the
/// runtime binary so we can smoke-test the round-trip during
/// integration without pulling in the tool script.
List<int> engrave(String plain) {
  final data = plain.codeUnits;
  final out = List<int>.filled(data.length, 0);
  for (var i = 0; i < data.length; i++) {
    out[i] = data[i] ^ _sigilKey[_slot(i)];
  }
  return out;
}
