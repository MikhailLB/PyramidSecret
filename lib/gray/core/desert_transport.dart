import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:http/http.dart' as http;

import '../cipher/sigil_codec.dart';
import '../env/sanctum_config.dart';

// ────────────────────────────────────────────────────────────
// DesertTransport — HTTP client with a real-device User-Agent.
// ────────────────────────────────────────────────────────────
// Every outbound request from the gray flow carries the same UA the
// WebView will use — mismatched fingerprints trigger 4xx from strict
// affiliate providers.  The Chrome and WebKit fragments are XOR-veiled
// (see sigil_codec.dart) so static analysis cannot pull a stable
// version string out of the binary.
//
// Per the mdc rule in AdventureRoad/.cursor/rules/gray_user_agent.mdc
// the tail carries `appid/<bundle> appname/<label>` after the standard
// Chrome UA — so partner backends can bin traffic by app.

const List<int> _chromeVersionCipher = <int>[
  0x4F, 0x3B, 0xEC, 0xE7, 0x10, 0x6D, 0x12, 0x40, 0x93, 0xCD, 0xFC, 0x1E,
  0xFF, 0x1D,
];
const List<int> _webkitVersionCipher = <int>[
  0x4B, 0x3C, 0xE2, 0xE7, 0x13, 0x75,
];

String get _chromeVersion {
  final decoded = unveil(_chromeVersionCipher);
  return decoded.isEmpty ? '149.0.7827.163' : decoded;
}

String get _webkitVersion {
  final decoded = unveil(_webkitVersionCipher);
  return decoded.isEmpty ? '537.36' : decoded;
}

class DesertTransport extends http.BaseClient {
  final http.Client _inner = http.Client();
  String _uaHeader = 'Mozilla/5.0';

  String get userAgent => _uaHeader;

  Future<void> awaken() async {
    _uaHeader = await _fabricateUserAgent();
  }

  Future<String> _fabricateUserAgent() async {
    final suffix =
        'appid/${SanctumConfig.bundleTag} appname/${SanctumConfig.uaLabel}';

    try {
      final info = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final droid = await info.androidInfo;
        // Release version (e.g. "15") — the value real browsers
        // ship in their UA. `sdkInt` (e.g. 35) is Google-internal
        // and would immediately flag us as non-human traffic.
        final release = droid.version.release.isNotEmpty
            ? droid.version.release
            : droid.version.sdkInt.toString();
        final brand = droid.brand;
        final model = droid.model;
        final build = droid.display.isNotEmpty ? droid.display : droid.id;
        return 'Mozilla/5.0 (Linux; Android $release; $brand $model '
            'Build/$build) AppleWebKit/$_webkitVersion '
            '(KHTML, like Gecko) Chrome/$_chromeVersion Mobile '
            'Safari/$_webkitVersion $suffix';
      }
      final ios = await info.iosInfo;
      final osVer = ios.systemVersion.replaceAll('.', '_');
      return 'Mozilla/5.0 (iPhone; CPU iPhone OS $osVer like Mac OS X) '
          'AppleWebKit/$_webkitVersion (KHTML, like Gecko) '
          'Version/${ios.systemVersion} Mobile/15E148 '
          'Safari/$_webkitVersion $suffix';
    } catch (_) {
      // Fallback UA when device_info_plus fails (emulators, tests).
      return 'Mozilla/5.0 (Linux; Android 15; SM-S931U '
          'Build/AP3A.240905.015.A2) AppleWebKit/$_webkitVersion '
          '(KHTML, like Gecko) Chrome/$_chromeVersion Mobile '
          'Safari/$_webkitVersion $suffix';
    }
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.putIfAbsent('User-Agent', () => _uaHeader);
    return _inner.send(request);
  }

  @override
  void close() => _inner.close();
}

/// Global singleton shared by every gray-flow service.
final DesertTransport desertTransport = DesertTransport();
