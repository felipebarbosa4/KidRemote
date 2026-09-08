# KR-003 Samsung runner-v2 HOST_EXCEPTION — 2026-09-08

- **Goal:** Preserve the exact Samsung runner-v2 calibration and identify how far it progressed without turning a host exception into a physical enforcement result.
- **Context:** The exact immutable `c74d656` bundle was executed once on the already transport-approved Samsung SM-X400 configuration.
- **Constraints:** Direct `/mnt/c` ingestion only; retain no raw command/exception output, serial, account, content, package history, screenshot or unrelated environment data; no rerun, qualification or KR-004 work.
- **Done when:** Approved artifacts and hashes are recorded, the completed controls and failure interval are explicit, and the result remains INVALID with zero calibration/qualification samples.

## Immutable mounted evidence

Directory: `C:\platform-tools\kr003-oracle-calibration\calibration-20260908-172235-9f29ec9a`.

| Artifact | SHA-256 |
| --- | --- |
| `device.json` | `5e1c89c0cddcc8dc2b1b86bfe5b5e5ed2c61d4170d71318ceafc0c94906b6c23` |
| `fixture.jsonl` | `5b79cb84097eeaa24f8ec791dec4668dff292bcffb6dd9395314d91d15773969` |
| `operations.json` | `de5debbc6daadbbf8badcb290a7cb40a19be9cfa43792d4ec6daf00f7ce65219` |
| `permission-verification.json` | `2ac76b72a2d1028169f5b20e638e79991ccd6a60394adc6bb2b6187f6bfdea20` |
| `summary.json` | `52dafcc4ee06594f28882b5935cdb89553c6763c608ab1d2cb20f8c06c71d6c5` |
| `telemetry.jsonl` | `c69a4bd32618a1f9cec95b3a6cbb9ed133a1886a3564ec7a8878f2a01de4d632` |
| `trace.jsonl` | `1c6b8ca00f3ec062cf17ddacae21c3ef7a8d053c9cf25dd488297dbadf349bdf` |
| `verified-candidate.apk` | `5b27c891fe155ee4d26e4da68f8323f178f7116e73d8097ce07199e5800e318b` |
| `verified-ordinary-fixture.apk` | `223219c17a31439b52698e769bdf03ead0998bbbe8bbb5c1b0ff5be3cfaf21dc` |

Strict `ingest.mjs calibration` returns source `c74d6569ea4e4d179922c389790a4a96d1a9c2fe`, `INVALID:HOST_EXCEPTION`, zero calibration samples,
zero qualification samples, physical agreement `UNRECORDED`, permission verification passed, derived host stage `ARM`, exception class
`UNSPECIFIED_V2_NOT_RETAINED`, v2 summary written and cleanup verified. The original artifacts remain unchanged.

## OBSERVED

- Bundle integrity, transport evidence ingestion, ADB authorization, configuration identity and installed/pulled candidate and fixture APK hashes completed. The bundle and all four runner/module payloads matched the published `c74d656` bytes.
- Runner v2 passed every required readiness check: Usage Access `ENABLED` / `MODE_ALLOWED`; Accessibility `ENABLED` / `GLOBAL_ENABLED_COMPONENT_MATCH_FULL`; service heartbeat `FRESH`; candidate health `HEALTHY`; candidate eligibility `ELIGIBLE`.
- The independent fixture was focused/resumed and its tap counter advanced exactly once, `0 → 1`. `summary.PositiveControl` is true.
- The pre-ARM permission/configuration recheck completed. `CANDIDATE_ARM` returned exit zero and its sanitized request-8 telemetry reports revision 8, armed true and 10,000 ms remaining.
- The runner never committed `summary.Revision`: it is null. No attachment latency, blocked-control tap, blocked hold, fixture-denial oracle or owner prompt was recorded. `BlockedControl=false`, `LatencyMs=null`, `HoldMillis=0`, `InjectedBlockedTaps=0`, and `PhysicalAgreement=UNRECORDED`.
- Finalization retained the v2 summary. Cleanup queried the candidate, issued `CANDIDATE_CLEAR` with exit zero, and verified release; final telemetry is unarmed/unrestricted. `CleanupVerified=true`.

## INFERRED

- The failure boundary is the runner's `ARM` host stage: after the ARM reply was parsed and journaled, but before its revision was assigned to the run summary. This stage is derived from the immutable v2 artifact sequence because v2 had no `HostStage` field.
- No retained artifact supports a failure in bundle/hash verification, transport ingestion, permission verification, fixture positive control, blocked hold, fixture oracle, owner prompt, cleanup or report writing.

## UNSPECIFIED

- Runner v2 normalized every non-typed exception to `INVALID:HOST_EXCEPTION` and discarded the original exception class/message. The exact .NET/PowerShell exception and immediate cause are therefore **UNSPECIFIED** and cannot be recovered from this run.
- Whether the candidate would have attached, blocked the fixture, held continuously or agreed with the owner is **UNSPECIFIED / Not run**. ARM telemetry is not enforcement evidence.

## Disposition

The run remains correctly `INVALID:HOST_EXCEPTION`. It separately establishes that runner-v2's permission correction passed on this exact
Samsung configuration and that the positive transport/fixture control remained usable. It advances no enforcement, latency, AC-3 or TIME-04 row.
Runner v3 adds only whitelisted host-stage/exception/cleanup/finalization diagnostics and primary-result preservation before one fresh calibration rerun.
