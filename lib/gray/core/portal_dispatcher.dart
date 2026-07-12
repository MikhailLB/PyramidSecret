import 'dart:convert';

import '../env/sanctum_config.dart';
import '../relics/oracle_reply.dart';
import 'desert_transport.dart';
import 'vault_locker.dart';

// ────────────────────────────────────────────────────────────
// PortalDispatcher — POST the attribution body to the backend and
// translate the answer into an OracleReply.
// ────────────────────────────────────────────────────────────
// Timeout / caching / storage side-effects follow the rules in
// android_gray_guide.md. If the endpoint is empty (placeholder) or
// the request explodes, the caller reads the last known shrine URL
// from the vault before giving up.

class PortalDispatcher {
  final VaultLocker _vault;

  PortalDispatcher(this._vault);

  Future<OracleReply> ask(Map<String, dynamic> body) async {
    final endpoint = SanctumConfig.portalEndpoint;
    if (endpoint.isEmpty) {
      return const OracleReply.miss('portal_disabled');
    }

    try {
      final response = await desertTransport
          .post(
            Uri.parse(endpoint),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(
            Duration(seconds: SanctumConfig.portalRequestTimeoutSeconds),
          );

      if (response.statusCode != 200) {
        return OracleReply.miss('http_${response.statusCode}');
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map) {
        return const OracleReply.miss('bad_json');
      }
      final reply = OracleReply.fromJson(Map<String, dynamic>.from(decoded));

      if (reply.hasShrine) {
        await _vault.stashShrineUrl(reply.shrineUrl!);
        if (reply.expiresAt != null) {
          await _vault.setShrineExpiry(reply.expiresAt!);
        }
      }
      return reply;
    } catch (e) {
      return OracleReply.miss(e.toString());
    }
  }

  Future<String?> lastKnownShrine() => _vault.peekShrineUrl();
}
