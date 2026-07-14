import 'package:clarity_flutter/clarity_flutter.dart';

import 'oracle_trace_env.dart';

// ────────────────────────────────────────────────────────────
// OracleTrace — crash-safe facade over Microsoft Clarity.
// ────────────────────────────────────────────────────────────
// Session replay records the NATIVE Flutter surface (loading gate,
// push invite, minesweeper, WebView container). The DOM inside the
// WebView is invisible to replay, so the funnel signals (offer
// reached, register / login / deposit taps) come from custom events
// emitted by this facade + a JS probe injected into the shrine page.
//
// Rules:
//   * Never call the Clarity SDK directly — always go through
//     OracleTrace. Every call is wrapped in a try/catch so a Clarity
//     failure can never crash the gray flow.
//   * Keep event names STABLE and few. Put high-cardinality values
//     (urls, hosts, labels, error text) into TAGS, not event names.
//   * `identify()` only after AppsFlyer af_id is known — otherwise a
//     later identify() would fragment a good session.
//   * The class is `final` on purpose; construction is not needed.
class OracleTrace {
  const OracleTrace._();

  /// Config handed to `ClarityWidget` in main.dart. Keep `LogLevel
  /// .None` in release builds — verbose logging is only useful while
  /// wiring a fresh project id.
  static ClarityConfig get config => ClarityConfig(
        projectId: kOracleTraceProjectId,
        logLevel: LogLevel.None,
      );

  /// Group the session by AppsFlyer id + attach attribution tags.
  /// No-op on empty id so a missing af_id never wipes a good user id.
  static void identify(
    String? aid, {
    Map<String, String> tags = const <String, String>{},
  }) {
    if (aid != null && aid.isNotEmpty) {
      _guard(() => Clarity.setCustomUserId(_clip(aid, 255)));
      tag('aid', aid);
    }
    tags.forEach(tag);
  }

  /// Named screen: sets the label AND emits a stable per-screen
  /// event. Prefer this over calling `screenName` + `event` manually.
  static void screen(String name) {
    screenName(name);
    event('screen_$name');
  }

  /// Sets the current screen label + mirrors it into a persistent
  /// `last_screen` tag. Clarity keeps the LAST tag value per session,
  /// so filtering by `last_screen` instantly shows where the user
  /// dropped off.
  static void screenName(String name) => _guard(() {
        Clarity.setCurrentScreenName(_clip(name, 255));
        Clarity.setCustomTag('last_screen', _clip(name, 255));
      });

  static void event(String name) =>
      _guard(() => Clarity.sendCustomEvent(_clip(name, 254)));

  static void tag(String key, String value) {
    if (value.isEmpty) return;
    _guard(() => Clarity.setCustomTag(key, _clip(value, 255)));
  }

  static String _clip(String v, int max) =>
      v.length <= max ? v : v.substring(0, max);

  static void _guard(void Function() body) {
    try {
      body();
    } catch (_) {}
  }
}
