# KR-003 Mi 8 calibration incident — 2026-09-06

- **Goal:** Preserve the stopped calibration, classify the conflicting evidence accurately and repair the lab runner without changing production enforcement.
- **Context:** Source/bundle `d81f19a`; new debug APK installed and hashed; owner reports expiry, Home and designated Settings success followed by oracle/finalization failures.
- **Constraints:** No new physical run; originals and old bundle untouched; no invented Android root cause, radio restoration or qualification pass.
- **Done when:** Evidence is correlated, independent cleanup/reporting and phase-oracle regressions pass, and a new immutable owner-run calibration bundle passes CI.

## Original artefacts

Newest directory, read directly from mounted Windows storage:
`C:\platform-tools\kr003-qualification\run-20260906-025608-9dd0c8c7`.
Started `2026-09-06T06:56:08.9896816Z`; manifest finalization timestamp `2026-09-06T06:57:38.4974705Z`.
Device: authorized Xiaomi Mi 8 / MIUI Global 12.0.3 / Android 10 API 29. No device command was run during ingestion.

| Existing file | Bytes | SHA-256 |
| --- | ---: | --- |
| `manifest.json` | 4519 | `e0d8ddbacc7b923cb33fa74f0d4775dd22e15b0aaffa2c438d21ff6e7916e853` |
| `calibration.json` | 340 | `d024448e501ec57cd889d08bcae0a6accae9f5a2e348409edfc3f0cf68557516` |
| `attempts.json` | 11 | `84b1c14e68260082e3e79edff0a78f4ebf1942cfd6c593246044ec2149cbb87d` |
| `attempts.csv` | 231 | `541d7c86f9ff364f19ad8a5014042f2a80931f57ad224a2910dbb8d914cdd5a4` |
| `telemetry.jsonl` | 46777 | `4964bc3af8fb3740de23f8cf6b76f3202d722bc66d5c4ab78c3f00af5b30afc6` |
| `trace.jsonl` | 3598 | `1f97a6c7565fa004125fbcbfba92bf63eefb69f5ca627f65715302b63aa4fddf` |
| `fixture.jsonl` | 2496 | `ef000a2bca504fd95177543a73539a5a918355a17cb4451751a0460f60f8389c` |
| `prior-metrics.json` | 2854 | `fe1e4dd5b2567d84ecb4bb1eb186c7d3f5ce5fd753967530652754dc85cdd10c` |
| `network-original.json` | 56 | `09c214513ded779793f015e6cc1dff5c10905a687430e82b0a58d8d9718318fc` |
| `network-touched.json` | 24 | `54f99457c188496eea76f2aa36037affba6dd011141e532b80720f255fa6afa3` |
| `verified-candidate.apk` | 2673461 | `67caa5d5b7e84fef8b86e4ed6b42d6b491116b4b71beffb2091c176725a669c5` |
| `verified-ordinary-fixture.apk` | 2543026 | `6653f10b527cc9a273a8c0ea045cd250f6978c1acfb8e92b00b701f6c14f84bb` |

No safety record, `summary.json`, `SUMMARY.md`, final metrics, end-device snapshot or persisted network-restoration outcome exists.
`attempts.json` is empty. `attempts.csv` contains a stale pre-confirmation calibration row, whereas `calibration.json` records the completed expiry
PASS. This is a runner journalling inconsistency, not a retraction of the observed expiry. Zero qualification attempts started.
An earlier directory `run-20260906-025517-0216802b` also exists and was preserved; it has no calibration or qualification rows. Its primary stop
reason is **UNSPECIFIED**. It is not another physical pass or a replacement qualification sample.

## Correlated evidence

| Device monotonic time / host record | Observed state |
| --- | --- |
| `t=9,915,404`, request 12 | Fresh arm revision 42; 10,000 ms, ordinary fixture eligible |
| `t=9,925,547`, trace sequence 11 | Overlay attached; restriction true; ordinary disposition; internal sample 148 ms |
| `t=9,925,681–682`, sequences 13–14 | OWN_PACKAGE event preserves ORDINARY_APP; no original feedback-loop removal |
| `t=9,925,819–9,936,677`, requests 40–81 | Restricted/attached; automatic hold recorded 10,535 ms; fixture loses focus, remains resumed, no synthetic tap |
| `t=9,972,102`, request 83; fixture request 84 | Post-expiry-P check remains blocked; fixture unfocused/resumed with zero taps |
| Host `06:57:19.9050265Z` | Calibration expiry saved with Observer PASS, Automated PASS, revision 42, one 148 ms internal sample |
| Physical Home/Settings phase | Owner reports Home did not escape; Settings opened; overlay disappeared; Settings usable; owner pressed P |
| `t=9,982,206–9,990,020`, requests 85–104 | Twenty post-Settings-P snapshots all revision/sample revision 42, restricted, attached, ORDINARY_APP/APPLIED; heartbeat true |

Those twenty samples are fresh: `elapsed - sampledAt` is **19–265 ms**. Trace head stays 14 with `traceLost=false`; no SAFE_SYSTEM, hide or removal
event was captured while restricted. The last pre-recovery query and first post-P query are 10,104 ms apart; the old blocking prompt made no queries
during the physical phase and did not persist the P timestamp. Exact Home/Settings/P times are **UNSPECIFIED**. The in-memory trace is continuous
through sequence 14, so a missed transient safe transition is **not established** merely by the polling gap. Fixture state was not queried during
or after the Settings phase. No evidence establishes a receiver side effect, OEM suppression, late event or actual enforcement-state defect.

**Classification:** calibration sequence stopped/incomplete; physical expiry PASS, physical Home PASS and physical designated Settings PASS.
The software oracle did not corroborate recovery. Its original terminal label `FAIL:SETTINGS_RECOVERY` is preserved as historical output; analysis
classifies this disagreement as **INVALID / SETTINGS_RECOVERY_ORACLE_UNCORROBORATED**, not a physical Settings failure. The Android-side reason for
the disagreement remains **UNSPECIFIED**. Do not change the allowlist, lengthen a timeout speculatively or waive the unresolved oracle.

The exported pre-reset store has exactly ten internal numbers `[77,123,102,263,132,113,247,205,209,85]`, p50 123/p95 263/max 263 ms. This establishes
the stored count **at this export**, not a retroactively known count at the owner's earlier transcription. Calibration's single 148 ms sample is
separate and does not join the 100-sample set. This adds one independent observed expiry, not a full calibration pass or extra Home/Settings expiries.

## Finalization defect and radio evidence

The original finalizer evaluates `@($validRows.LatencyMs)` with an empty array under StrictMode. The member lookup itself throws
`PropertyNotFoundStrict` before `Get-KRStatistics` receives an empty input. Reproduced locally without a device. StrictMode's missing-member checks
and collection enumeration are documented by [Microsoft StrictMode](https://learn.microsoft.com/powershell/module/microsoft.powershell.core/set-strictmode)
and [member enumeration](https://learn.microsoft.com/powershell/module/microsoft.powershell.core/about/about_member-access_enumeration), reviewed 2026-09-06.
Tests had covered the statistics function's empty input but not this real finalization expression; that coverage gap is a runner defect.

Original Wi-Fi flag: **1**; mobile data: **0**. Only Wi-Fi was recorded as touched. The run's baseline after setup has both flags **0**.
Source order calls `Restore-Network` before the manifest end timestamp and the failing statistics expression. Therefore restoration was attempted
before reporting failed, but either restoration success or its caught failure can reach that timestamp. No post-restoration flags were persisted.
Actual final Wi-Fi/mobile state is **UNSPECIFIED** pending owner visual confirmation; do not claim verified restoration from code order alone.
The earlier run's restoration is corroborated only by the latest run starting with Wi-Fi=1/mobile=0; it does not prove this latest run's final state.

## Bounded repairs and verification

- Replace empty-array member shorthand with explicit row enumeration. Qualification statistics exclude calibration and partial/failed rows;
  zero rows yield Count 0 and null percentiles. Calibration remains in both JSON/CSV journals, eliminating the stale calibration CSV path.
- Save physical responses before post-response checks and recovery records at phase start/during polling. Preserve partial/current attempts.
- Correlate Settings-button request/dispatch with revision, monotonic time and trace-sequence floor. Require a subsequent safe sample or safe
  transition/removal; latch phase evidence instead of demanding one exact later snapshot. Pre-button/stale events cannot corroborate recovery.
- An owner PASS without corroboration stops INVALID with the physical PASS retained. No speculative timeout increase, safe-package change or
  enforcement fix was made. The evidence gap is being instrumented, not claimed resolved.
- Add only debug-owned View visibility/focus/framework-attachment flags and typed button-dispatch trace. Candidate reply schema is 2; fixture
  remains 1. Release hooks remain no-op, controls absent, permissions unchanged; validator now also scans debug trace for forbidden data access.
- Finalization guards each recovery/report operation independently. A Wi-Fi error cannot skip mobile restoration; actual flag readbacks are
  persisted. Secondary errors have their own list and cannot mask the primary reason or allow qualification. JSON/Markdown fallback writes are
  attempted independently; unwritable storage/hard process termination cannot be guaranteed recoverable.
- Add `-CalibrationOnly`: next owner execution cannot proceed to 100 even on success. It captures one diagnostic calibration and end hash/configuration.

Executed locally, without a device:

| Check | Result |
| --- | --- |
| JVM debug unit tests | 23/23, no failures/skips; includes diagnostics not overriding adapter state |
| PowerShell qualification assertions | 45 passed, native Linux PowerShell 7.6.5, synthetic inputs |
| PowerShell real finalizer/recovery assertions | 65 passed: zero/calibration, interruption, sample 1, partial, 100 rows, writer/radio faults, stale/unrelated safe events, physical PASS preservation |
| Node evidence/negative-security tests | 6 passed; missing legacy summary remains incomplete; calibration-only cannot qualify |
| lintDebug / assembleDebug / lintRelease / assembleRelease | Passed for candidate and fixture |
| Merged manifest / release DEX audit | Both APKs, both variants passed; 23 executed JVM cases verified |

An additional `testReleaseUnitTest` invocation was rejected during task selection: that task does not exist in this configured spike.
Task discovery confirms the registered JVM variant is debug (shared `test` plus `testDebug` sources, all 23 cases covered); do not claim a
separate release JVM suite ran. Release compilation, lint and manifest/DEX isolation are separate executed checks.

GitHub exact-source CI, immutable bundle identities and final repository validation are recorded in the subsequent handoff once actually verified.
These desktop results do not validate Q2 on-device recovery, radio restoration, 100-sample qualification, another OEM/API or Google Play acceptance.
