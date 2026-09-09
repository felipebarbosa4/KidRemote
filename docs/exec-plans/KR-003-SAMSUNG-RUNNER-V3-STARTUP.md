# KR-003 Samsung runner-v3 startup defect

- **Goal:** Remove PowerShell automatic-variable collisions from the calibration runner, prove the actual entrypoint initializes under Windows PowerShell 5.1 and PowerShell 7, and publish one replacement bundle.
- **Context:** The owner invoked the immutable `cf7b2e9` runner-v3 bundle once; PowerShell rejected top-level `$script:Host` assignment before the protected runner block or any device operation.
- **Constraints:** KR-003 only; preserve all earlier evidence and the failed invocation; no device command, enforcement/permission/oracle change, gate reduction, rerun, qualification, production move or KR-004 work.
- **Done when:** Exact source and bundle collisions are audited; internal variables are minimally renamed while JSON fields stay stable; static and real-entrypoint regressions pass on PowerShell 5.1 and 7 where available; required suites and CI pass; a clean immutable runner-v4 bundle and one command are published; Issue #3 and draft PR #16 are synchronized.

## Execution and stop point

1. Record the owner-provided failure as a host-script startup defect with zero physical execution.
2. Rename `$script:Host` to `$script:HostState`; preserve external `HostDiagnostic` / `HostStage` schema properties.
3. Audit every KR-003 PowerShell source, module, test and generated bundle for reserved parameter/write targets. Allow automatic-variable reads and the conventional `$null = expression` discard only.
4. Execute the real entrypoint from a bundle-shaped directory with redirected input so it must stop before output creation, bundle reads and ADB; run under native Windows PowerShell 5.1 and PowerShell 7 where available.
5. Validate, commit, build from clean source, independently verify the immutable bundle, synchronize GitHub, then stop before physical execution.

Do not run the replacement calibration, start 100 samples, close KR-003, merge PR #16 or touch KR-004.

## Repository checkpoint

Source `af723c5a7af530a2c694e2749c533de1e18f4cab` contains the bounded rename and regressions. Its immutable runner-v4 bundle is recorded in
[KR-003-SAMSUNG-CALIBRATION-V4-BUNDLE-2026-09-08](../test-plans/evidence/KR-003-SAMSUNG-CALIBRATION-V4-BUNDLE-2026-09-08.md), with bundle hash
`4d98e4e40c7b2eec77e59b8fb672cc89a5356356742ae2ae3f50f6be6f7b8320`. Exact-source CI run `34301619476` passed PowerShell 7 and native Windows PowerShell 5.1 entrypoint/collision regressions plus Node, Android,
JVM and release-isolation checks. GitHub publication readback remains pending; physical execution remains Not run.
