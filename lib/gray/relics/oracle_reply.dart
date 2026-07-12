// ────────────────────────────────────────────────────────────
// oracle_reply.dart — typed wrapper over the config endpoint JSON.
// ────────────────────────────────────────────────────────────
// Contract:
//   { "ok": true,  "url": "https://…",  "expires": 1720000000 }
//   { "ok": false, "message": "organic" }
// Anything else (bad JSON, network error, missing url) collapses
// into an `OracleReply.miss(reason)` value the caller can pattern
// match against.

class OracleReply {
  final bool granted;
  final String? shrineUrl;
  final int? expiresAt;
  final String? note;

  const OracleReply({
    required this.granted,
    this.shrineUrl,
    this.expiresAt,
    this.note,
  });

  const OracleReply.miss(String reason)
      : granted = false,
        shrineUrl = null,
        expiresAt = null,
        note = reason;

  factory OracleReply.fromJson(Map<String, dynamic> raw) {
    final rawOk = raw['ok'];
    final rawUrl = raw['url'];
    final rawExpires = raw['expires'];
    return OracleReply(
      granted: rawOk is bool ? rawOk : rawOk?.toString() == 'true',
      shrineUrl: rawUrl is String && rawUrl.isNotEmpty ? rawUrl : null,
      expiresAt: rawExpires is int
          ? rawExpires
          : (rawExpires is num ? rawExpires.toInt() : null),
      note: raw['message']?.toString(),
    );
  }

  bool get hasShrine => granted && (shrineUrl?.isNotEmpty ?? false);
}
