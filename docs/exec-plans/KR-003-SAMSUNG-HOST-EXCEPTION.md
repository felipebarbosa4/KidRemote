# KR-003 Samsung runner-v2 host-exception diagnosis

- **Goal:** Ingest the exact runner-v2 Samsung calibration, preserve every completed control, locate the host exception, and prepare one fail-closed rerun with safe stage/finalization diagnostics.
- **Context:** The owner executed the immutable `c74d656` calibration bundle once on the transport-approved SM-X400. It returned `INVALID:HOST_EXCEPTION` after runner-v2 permission verification and the positive fixture control passed.
- **Constraints:** KR-003 only; preserve the mounted run and its INVALID classification; no raw exception/command output, serial, accounts, content, package history, screenshot, permission mutation, physical rerun, qualification samples, production move or KR-004 work.
- **Done when:** Strict ingestion establishes the last completed and failing stages; OBSERVED/INFERRED/UNSPECIFIED are separated; a typed host-stage/exception/cleanup/finalization record is regression-tested; completed evidence cannot be erased or promoted to PASS; all required suites pass; one immutable bundle and exact rerun command are published; Issue #3 and draft PR #16 are synchronized; execution stops.

## Execution

1. Ingest and hash only the approved mounted artifacts; compare the source-pinned runner and APK hashes without modifying the run.
2. Reconstruct the ordered host stage from summary, operations, telemetry and fixture journals. Do not infer physical enforcement from ARM or candidate telemetry.
3. Add a whitelisted `HostDiagnostic` record with `HostStage`, `ExceptionClass`, `PrimaryReason`, `FinalizationStatus` and `CleanupStatus`; retain no raw exception message, stack, path or command output.
4. Keep cleanup in `finally`, preserve the first primary result if cleanup/finalization also fails, and invalidate an otherwise successful run whose final report cannot be verified.
5. Test pre-ARM, ARM/hold, finalization and cleanup-failure paths; validate, commit, package from clean source, publish the stopped handoff and synchronize GitHub.

## Stop point

Stop after publishing one exact PowerShell calibration command. Do not execute it, start a 100-cycle qualification, relabel the v2 INVALID as an enforcement failure, close KR-003, merge PR #16 or touch KR-004.

## Repository checkpoint

Source `cf7b2e97fa12bd3397ea8ba7a40174456df27ba0` implements the typed host/finalization record and preserves strict historical ingestion.
Its clean immutable runner-v3 bundle and stopped handoff are recorded in
[KR-003-SAMSUNG-CALIBRATION-V3-BUNDLE-2026-09-08](../test-plans/evidence/KR-003-SAMSUNG-CALIBRATION-V3-BUNDLE-2026-09-08.md).
Physical execution remains Not run; Issue #3 / PR #16 synchronization and exact-source CI remain administrative steps.
