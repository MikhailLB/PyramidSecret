// ────────────────────────────────────────────────────────────
// oracle_trace_env.dart — Microsoft Clarity project id.
// ────────────────────────────────────────────────────────────
// [FINGERPRINT] The Clarity project id is unique per app. Never
// reuse another project's id here — mixing sessions across apps
// under the same publisher would poison the drop-off funnel.
//
// Kept in its own file (not in `sanctum_config.dart`) so the
// analytics layer can be swapped / stubbed without touching the
// gray-flow configuration.

const String kOracleTraceProjectId = 'xmdi1cb4k2';
