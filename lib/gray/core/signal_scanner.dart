import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';

import '../env/sanctum_config.dart';

// ────────────────────────────────────────────────────────────
// SignalScanner — connectivity + DNS liveness probe.
// ────────────────────────────────────────────────────────────
// Per `gray_part_pitfalls.md §3`:
//   * VPN, Bluetooth-tether and "other" interfaces count as online.
//   * DNS probe timeout is 7 seconds, not 3 — real failures throw
//     SocketException instantly, the extra window only helps when a
//     VPN tunnel is slow.
//   * The status stream is debounced by callers before it flips a
//     screen — do NOT debounce in here, the raw stream is public.

class SignalScanner {
  static const Set<ConnectivityResult> _liveTransports = <ConnectivityResult>{
    ConnectivityResult.wifi,
    ConnectivityResult.mobile,
    ConnectivityResult.ethernet,
    ConnectivityResult.vpn,
    ConnectivityResult.bluetooth,
    ConnectivityResult.other,
  };

  static const List<String> _probeHosts = <String>[
    'cloudflare.com',
    'google.com',
    'apple.com',
  ];

  final Connectivity _connectivity;

  SignalScanner({Connectivity? connectivity})
      : _connectivity = connectivity ?? Connectivity();

  Stream<List<ConnectivityResult>> get pulseStream =>
      _connectivity.onConnectivityChanged;

  Future<List<ConnectivityResult>> currentTransports() =>
      _connectivity.checkConnectivity();

  /// True when at least one live transport is present AND at least
  /// one of the probe hosts resolves within the pit-fall-mitigated
  /// 7 s window.
  Future<bool> hasReachableNet() async {
    final transports = await currentTransports();
    final liveAny = transports.any(_liveTransports.contains);
    if (!liveAny) return false;
    return await _resolveAny();
  }

  Future<bool> _resolveAny() async {
    for (final host in _probeHosts) {
      try {
        final addresses = await InternetAddress.lookup(host).timeout(
          Duration(seconds: SanctumConfig.dnsProbeTimeoutSeconds),
        );
        if (addresses.isNotEmpty && addresses.first.rawAddress.isNotEmpty) {
          return true;
        }
      } on SocketException {
        // Route missing — no need to check other hosts.
        return false;
      } catch (_) {
        // Time-out or other transient failure — try the next host.
        continue;
      }
    }
    return false;
  }
}
