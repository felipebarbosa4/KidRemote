# KR-003 Samsung permission-verifier correction

- **Goal:** Ingest the Samsung transport/calibration evidence, identify the failed required-permission sub-check, and prepare one fail-closed calibration rerun with Android-version-compatible typed verification.
- **Context:** Source `5a46f75` produced one transport PASS and three calibration INVALID runs on an authorized Samsung SM-X400 / Android 16 / API 36 configuration. Candidate telemetry reached healthy permission/service state, while runner metadata classified Accessibility as not granted.
- **Constraints:** KR-003 only; preserve every original evidence directory and classification; no raw settings/AppOps/dumpsys output, serial, accounts, screenshots, content, package history, permission mutation, Samsung-only workaround, physical rerun, qualification samples, production move or KR-004 work.
- **Done when:** Mounted evidence passes strict ingestion and is recorded; OBSERVED/INFERRED/UNSPECIFIED findings are separated; Usage Access, Accessibility, heartbeat and candidate-health verification have typed fail-closed diagnostics; short/full Android component forms and disabled/unknown/stale/revoked cases regress; all requested suites pass; a clean immutable calibration bundle is published; Issue #3 and draft PR #16 are synchronized; execution stops before the owner command runs.

## Execution

1. Strictly ingest the exact mounted transport directory and all three mounted calibration directories; hash only approved sanitized artifacts.
2. Trace AppOps, secure settings, candidate AccessibilityManager state, heartbeat and health independently. Review Android 10/current Android component and AppOps semantics against official AOSP sources.
3. Replace raw string equality with semantic `ComponentName` comparison, read secure settings for the current user explicitly, and persist only typed source/parse/state enums. `UNKNOWN` remains rejecting.
4. Recheck runner permission state before ARM and after the blocked hold. A permission/service loss after initial success remains `FAIL`; unavailable or unparseable verification remains `INVALID`.
5. Record the physical evidence and exact matrix boundary, validate, commit the implementation, package a clean source-pinned calibration-only bundle, then record/push the handoff and synchronize GitHub.

## Stop point

Stop after publishing one exact PowerShell calibration command. Do not run it, start a 100-cycle qualification, generalize to Mi 8/another Samsung configuration, close KR-003, merge PR #16 or touch KR-004.

## Repository checkpoint

Source `c74d6569ea4e4d179922c389790a4a96d1a9c2fe` implements and validates runner v2. Its clean immutable bundle and exact stopped handoff are recorded in
[KR-003-SAMSUNG-CALIBRATION-V2-BUNDLE-2026-09-08](../test-plans/evidence/KR-003-SAMSUNG-CALIBRATION-V2-BUNDLE-2026-09-08.md).
Physical execution remains Not run; Issue #3 / PR #16 synchronization and exact-source CI remain the final administrative steps.
