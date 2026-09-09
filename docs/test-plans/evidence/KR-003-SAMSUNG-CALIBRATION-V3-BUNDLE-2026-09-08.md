# KR-003 Samsung calibration runner-v3 bundle — 2026-09-08

- **Goal:** Publish one immutable calibration-only rerun bundle that can safely identify a host exception stage/class without weakening any physical gate.
- **Context:** Runner v2 passed permission verification and the fixture positive control on SM-X400, then stopped `INVALID:HOST_EXCEPTION` in ARM before a blocked hold; its original exception class was not retained.
- **Constraints:** Exact unchanged Q5 candidate and independent fixture; no raw exception/AppOps/settings/command output, serial, account/content/history, permission mutation, Samsung workaround, network change, qualification loop, production code or KR-004 work.
- **Done when:** Clean committed source and all payload hashes are pinned, tests pass, one exact owner command is recorded, and physical execution remains Not run.

## Immutable handoff

| Item | Value |
| --- | --- |
| Source commit | `cf7b2e97fa12bd3397ea8ba7a40174456df27ba0` |
| Protocol / runner | `KR003-GENERIC-ACTIVE-ORACLE-CALIBRATION` / `3` |
| Windows directory | `C:\platform-tools\kr003-oracle-calibration-bundles\cf7b2e9` |
| `bundle.json` SHA-256 | `576b95a1c1b5be3fb420a8ef072b66a054947041da0949b0f6403e90806c6654` |
| Candidate SHA-256 | `5b27c891fe155ee4d26e4da68f8323f178f7116e73d8097ce07199e5800e318b` |
| Fixture SHA-256 | `223219c17a31439b52698e769bdf03ead0998bbbe8bbb5c1b0ff5be3cfaf21dc` |
| Calibration / qualification maximum | one excluded calibration / `0` qualification samples |
| Host invocation / physical execution | **Failed at PowerShell initialization once / Not run** |
| Current status | **Superseded; do not rerun** |

| Payload | SHA-256 |
| --- | --- |
| `Test-KR003-OracleCalibration.ps1` | `936fd52169bace3d2f71be369874ac25cb8658d1b379f5ed327fb51e0302951b` |
| `CalibrationHost.psm1` | `4fc023045efaf8b487e3b4d52f06df6c733df2d8c275540e5c7dd7c88c7ee2db` |
| `DevicePreflight.psm1` | `e0d77b65b7d5ea3e8f26245247ba33fadcf985b11af43aa0b2d032375f5449d3` |
| `OracleTransport.psm1` | `b3a6d4a53d813e03e937c3f762343e88743045f29076f234255070d37f554e3f` |
| `Qualification.psm1` | `524cbf5f528e8ad88d0667a2aef1bd1f605331bc289cbdcb6e4f421bfede63b7` |
| `protocol.md` | `c1f56eb434e0adc7673c8a3884c8ab720fad1270261662931857a88079769326` |
| `candidate.apk` | `5b27c891fe155ee4d26e4da68f8323f178f7116e73d8097ce07199e5800e318b` |
| `ordinary-fixture.apk` | `223219c17a31439b52698e769bdf03ead0998bbbe8bbb5c1b0ff5be3cfaf21dc` |

All eight manifest payload hashes were independently re-read, and every runner/module/protocol payload matched the source tree byte-for-byte.
The candidate and fixture APK hashes remain identical to the earlier physical runs.

## Historical failed command — do not rerun

The owner invoked this command once. It failed on the entrypoint's `$script:Host` assignment before output creation or any device command:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\platform-tools\kr003-oracle-calibration-bundles\cf7b2e9\Test-KR003-OracleCalibration.ps1" -TransportEvidence "C:\platform-tools\kr003-device-preflight\device-20260908-092640-d3b5053b"
```

Do not invoke this superseded bundle again. The exact owner-provided error and zero-device-execution boundary are preserved in
[KR-003-SAMSUNG-RUNNER-V3-STARTUP-2026-09-08](KR-003-SAMSUNG-RUNNER-V3-STARTUP-2026-09-08.md).

No 100-cycle qualification is authorized. A calibration PASS would permit only repository review and preparation of a separately authorized,
configuration-specific qualification bundle; it would not close KR-003 or establish safety/lifecycle/Play support.

## Verification

- 20 Node evidence/security tests passed, including strict ingestion of the immutable v2 HOST_EXCEPTION and rejection of raw exception fields.
- 443 assertions passed across all seven native Windows PowerShell 5.1 suites; pre-ARM, ARM, blocked-hold, finalization and secondary-cleanup failure paths are covered without a device.
- Packaging rebuilt/tested debug and release variants because APKs are bundle payloads: Gradle completed 274 tasks (6 executed), and the build audit verified JVM `24/24` plus all six merged-manifest/DEX release-isolation checks.
- `node tools/validate.mjs` and `git diff --check` passed.

These were repository/bundle results, not a physical runner-v3 calibration, enforcement result, Samsung support boundary or Play approval. The
old test suite did not execute the top-level entrypoint and therefore missed the automatic-variable collision; runner v4 adds that regression.
