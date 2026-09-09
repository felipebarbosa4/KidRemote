# KR-003 Samsung runner-v4 deterministic ARM host exception

- **Goal:** Preserve four independent runner-v4 Samsung `INVALID:HOST_EXCEPTION` records, establish their earliest common boundary, and publish one tested runner-only correction without starting another physical run.
- **Context:** Source `af723c5a7af530a2c694e2749c533de1e18f4cab` was invoked four times on the transport-approved SM-X400. Every retained summary reports `HostStage=ARM`, `ExceptionClass=PROPERTY_NOT_FOUND_EXCEPTION`, completed finalization, verified cleanup and zero samples.
- **Constraints:** KR-003 only; original mounted directories remain immutable and unpooled; retain only bounded structured diagnostics; no raw command/exception output, stack, serial, account/content/history or screenshot; no candidate, enforcement, permission, oracle or gate change; `UNKNOWN` remains fail-closed; no physical rerun, 100-cycle qualification or KR-004 work.
- **Done when:** All four directories pass strict ingestion and are independently recorded; the exact v4 source/bundle defect is reproduced; scalar, array, missing/null ARM properties, revision extraction, stage attribution, cleanup and primary-result preservation regress on PowerShell 5.1 and 7 where available; relevant suites and CI pass; one clean immutable replacement bundle is hash-pinned; Issue #3 and draft PR #16 are synchronized; execution stops before the owner command runs.

## Execution

1. Read and hash each mounted directory independently; compare only safe structured summary, permission, operation and bounded telemetry fields.
2. Trace the terminal `ARM` boundary through exact source and bundle bytes; distinguish an issued timer ARM from attachment, blocked hold, denial oracle and physical agreement.
3. Remove the case-insensitive same-scope reply/state collision and validate that the ARM reply is exactly one typed object with a numeric revision before assignment.
4. Run PowerShell, Node, validation and release-isolation checks; Android code is unchanged, so do not claim new Android behavior.
5. Commit and push clean source, wait for exact-source CI, package a new immutable calibration-only bundle, verify payload hashes and its actual entrypoint on Windows PowerShell 5.1, then record and synchronize the stopped handoff.

## Stop point

Stop after publishing one exact future calibration command. Do not execute it, begin the 100-cycle qualification, advance a physical matrix row, merge PR #16, close KR-003 or touch KR-004.

## Repository checkpoint

Source `4690d3951d0952fefe43eab9de0799599c6ea903` contains the bounded runner-only fix and regressions. Exact-source CI run `34305581473`
passed all three jobs, including PowerShell `7.6.5` and native Windows PowerShell `5.1.26100.33296`. Its immutable runner-v5 bundle is recorded in
[KR-003-SAMSUNG-CALIBRATION-V5-BUNDLE-2026-09-08](../test-plans/evidence/KR-003-SAMSUNG-CALIBRATION-V5-BUNDLE-2026-09-08.md), with
`bundle.json` SHA-256 `8599225eb453ceaa391f9aa2aea30cc6f04e1a2e450b98a39ec7a03c6ae216fd`. Physical execution remains Not run.
