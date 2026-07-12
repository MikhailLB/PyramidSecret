// ────────────────────────────────────────────────────────────
// portal_mode.dart — persistent gray/white verdict.
//
// The verdict is stored the moment the config endpoint answers for
// the first time. `awaiting` is the pristine state before any
// backend contact; `unlocked` means the WebView flow is active for
// this install; `sealed` locks the install into the offline game
// forever (per TZ §9 — never re-ask the backend).
// ────────────────────────────────────────────────────────────

enum PortalMode {
  unlocked,
  sealed,
  awaiting;

  static PortalMode fromToken(String? token) {
    switch (token) {
      case 'unlocked':
        return PortalMode.unlocked;
      case 'sealed':
        return PortalMode.sealed;
      default:
        return PortalMode.awaiting;
    }
  }

  String toToken() {
    switch (this) {
      case PortalMode.unlocked:
        return 'unlocked';
      case PortalMode.sealed:
        return 'sealed';
      case PortalMode.awaiting:
        return 'awaiting';
    }
  }
}
