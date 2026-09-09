# KR-003 Samsung calibration runner-v4 bundle — 2026-09-08

- **Goal:** Publish one immutable calibration-only replacement whose PowerShell entrypoint is tested against reserved-variable startup failures before physical handoff.
- **Context:** The runner-v3 `cf7b2e9` invocation failed on `$script:Host` before any device command; all earlier Samsung evidence remains unchanged.
- **Constraints:** Exact unchanged Q5 candidate and independent fixture; no raw exception/AppOps/settings/command output, serial, account/content/history, permission mutation, Samsung workaround, enforcement/oracle change, qualification loop, production code or KR-004 work.
- **Done when:** Clean committed source and all payload hashes are pinned; source and generated-bundle collision scans pass; the actual bundle entrypoint reaches its controlled pre-device stop under Windows PowerShell 5.1; CI covers PowerShell 7 and native 5.1; one exact owner command is recorded; physical execution remains Not run.

## Immutable handoff

| Item | Value |
| --- | --- |
| Source commit | `af723c5a7af530a2c694e2749c533de1e18f4cab` |
| Protocol / runner | `KR003-GENERIC-ACTIVE-ORACLE-CALIBRATION` / `4` |
| Windows directory | `C:\platform-tools\kr003-oracle-calibration-bundles\af723c5` |
| `bundle.json` SHA-256 | `4d98e4e40c7b2eec77e59b8fb672cc89a5356356742ae2ae3f50f6be6f7b8320` |
| Candidate SHA-256 | `5b27c891fe155ee4d26e4da68f8323f178f7116e73d8097ce07199e5800e318b` |
| Fixture SHA-256 | `223219c17a31439b52698e769bdf03ead0998bbbe8bbb5c1b0ff5be3cfaf21dc` |
| Calibration / qualification maximum | one excluded calibration / `0` qualification samples |
| Physical execution | **Not run** |

| Payload | SHA-256 |
| --- | --- |
| `Test-KR003-OracleCalibration.ps1` | `88357ba82402561c5aa0cc2219a7f7278f0da7015d459adc93e75d926c4d8b7b` |
| `CalibrationHost.psm1` | `4fc023045efaf8b487e3b4d52f06df6c733df2d8c275540e5c7dd7c88c7ee2db` |
| `DevicePreflight.psm1` | `e0d77b65b7d5ea3e8f26245247ba33fadcf985b11af43aa0b2d032375f5449d3` |
| `OracleTransport.psm1` | `b3a6d4a53d813e03e937c3f762343e88743045f29076f234255070d37f554e3f` |
| `Qualification.psm1` | `7c099bac9c0ac710a94d54d5f664435c70c13418aa319a87d396e1e7c6f62ffa` |
| `protocol.md` | `704c8d60d037814973fb7772e6a05c753fab402e5bc2fdeb37685f6dc1c3e523` |
| `candidate.apk` | `5b27c891fe155ee4d26e4da68f8323f178f7116e73d8097ce07199e5800e318b` |
| `ordinary-fixture.apk` | `223219c17a31439b52698e769bdf03ead0998bbbe8bbb5c1b0ff5be3cfaf21dc` |

All eight manifest payload hashes were independently re-read. All five PowerShell payloads and the protocol matched source commit `af723c5`
byte-for-byte; APK hashes remain identical to the earlier physical runs. The generated bundle passed the reserved-variable collision scan across
all five PowerShell files. Its actual entrypoint passed the redirected-input initialization regression under Windows PowerShell `5.1.26100.9168`,
returning the expected controlled exit before output creation, bundle reads or any device command.

## Exact single rerun command

With only the exact authorized Samsung SM-X400 connected, unlocked and interactive, run once in Windows PowerShell:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\platform-tools\kr003-oracle-calibration-bundles\af723c5\Test-KR003-OracleCalibration.ps1" -TransportEvidence "C:\platform-tools\kr003-device-preflight\device-20260908-092640-d3b5053b"
```

Do not change or auto-grant permissions. Keep Usage Access and the disposable Accessibility service enabled through the run. During the single
physical agreement prompt, watch the full blocked hold and press `P` only if restriction remains visibly continuous with no ordinary use/flicker;
press `F` on a visible failure or `I` if missed/uncertain. Preserve the printed evidence directory and stop on PASS, FAIL or INVALID.

No 100-cycle qualification is authorized. A calibration PASS would permit only repository review and preparation of a separately authorized,
configuration-specific qualification bundle; it would not close KR-003 or establish safety/lifecycle/Play support.

## Verification

- 20 Node evidence/security tests passed.
- 451 assertions passed across nine native Windows PowerShell 5.1 suites. These include static source/bundle collision checks and actual-entrypoint initialization, plus the existing permission, oracle, cleanup and finalization paths; no device command ran.
- Packaging completed all 274 Gradle tasks (6 executed), debug/release unit/lint/build, JVM `24/24`, and all six merged-manifest/DEX release-isolation checks.
- `node tools/validate.mjs` and `git diff --check` passed. Exact-source [CI run 34301619476](https://github.com/felipebarbosa4/KidRemote/actions/runs/34301619476)
  passed all three jobs; the bundled-entrypoint regression ran under PowerShell `7.6.5` and native Windows PowerShell `5.1.26100.33296`.

These are repository/bundle results, not a physical runner-v4 calibration, enforcement result, Samsung support boundary or Play approval.

## Subsequent physical status

The owner later invoked this exact bundle four times. The four directories remain separate and are preserved in
[runner-v4 ARM host-exception evidence](KR-003-SAMSUNG-RUNNER-V4-HOST-EXCEPTIONS-2026-09-08.md). Every run is independently
`INVALID:HOST_EXCEPTION`, with `HostStage=ARM`, `ExceptionClass=PROPERTY_NOT_FOUND_EXCEPTION`, verified cleanup and zero samples. This updates
only the subsequent execution status; the immutable handoff bytes and original at-publication `Not run` statement above remain historical facts.
