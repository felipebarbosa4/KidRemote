# KR-003 Samsung calibration verifier v2 bundle — 2026-09-08

- **Goal:** Publish one immutable, calibration-only rerun bundle that diagnoses and corrects the Samsung required-permission verifier without weakening the oracle gate.
- **Context:** Samsung SM-X400 transport passed under source `5a46f75`; three v1 calibration attempts remain `INVALID:REQUIRED_PERMISSION_STATE_NOT_VERIFIED` with runner Usage Access granted, runner Accessibility not granted, and healthy candidate/service telemetry.
- **Constraints:** Exact unchanged Q5 candidate and reviewed independent fixture; no raw AppOps/settings/dumpsys output, device serial, account/content/history, permission mutation, Samsung allowlist, network change, qualification loop, production code or KR-004 work.
- **Done when:** A clean committed source builds/tests, runner v2 and every payload are hash-pinned and independently byte-compared, and its later physical result is linked without changing the immutable bundle.

## Immutable handoff

| Item | Value |
| --- | --- |
| Source commit | `c74d6569ea4e4d179922c389790a4a96d1a9c2fe` |
| Protocol / runner | `KR003-GENERIC-ACTIVE-ORACLE-CALIBRATION` / `2` |
| Windows directory | `C:\platform-tools\kr003-oracle-calibration-bundles\c74d656` |
| `bundle.json` SHA-256 | `35b77cf68433813b733616a66f6a4dfe90183823201ad32d38f5d49c094f29d9` |
| Candidate SHA-256 | `5b27c891fe155ee4d26e4da68f8323f178f7116e73d8097ce07199e5800e318b` |
| Fixture SHA-256 | `223219c17a31439b52698e769bdf03ead0998bbbe8bbb5c1b0ff5be3cfaf21dc` |
| Calibration / qualification maximum | one excluded calibration / `0` qualification samples |
| Physical execution | Executed once: [`INVALID:HOST_EXCEPTION`](KR-003-SAMSUNG-HOST-EXCEPTION-2026-09-08.md) |

| Payload | SHA-256 |
| --- | --- |
| `Test-KR003-OracleCalibration.ps1` | `2e760e8d7f1e526a4fa6b4b97085bf65ec3aeea3688109f4d441a0ce8021ec80` |
| `DevicePreflight.psm1` | `e0d77b65b7d5ea3e8f26245247ba33fadcf985b11af43aa0b2d032375f5449d3` |
| `OracleTransport.psm1` | `b3a6d4a53d813e03e937c3f762343e88743045f29076f234255070d37f554e3f` |
| `Qualification.psm1` | `524cbf5f528e8ad88d0667a2aef1bd1f605331bc289cbdcb6e4f421bfede63b7` |
| `protocol.md` | `cbb5e10ab1ebc4b0661af9d0e259cbdec57af82dcae00a8158bae7cc6da3e9ba` |
| `candidate.apk` | `5b27c891fe155ee4d26e4da68f8323f178f7116e73d8097ce07199e5800e318b` |
| `ordinary-fixture.apk` | `223219c17a31439b52698e769bdf03ead0998bbbe8bbb5c1b0ff5be3cfaf21dc` |

The packager rebuilt/tested debug and release variants, ran repository validation and release isolation, then wrote a new non-overwriting directory.
An independent `sha256sum` plus byte-for-byte comparison matched every source/protocol/APK payload to commit `c74d656`. Packaging ran no device command.

## Historical executed command

The owner later ran this command once on the exact authorized Samsung SM-X400:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\platform-tools\kr003-oracle-calibration-bundles\c74d656\Test-KR003-OracleCalibration.ps1" -TransportEvidence "C:\platform-tools\kr003-device-preflight\device-20260908-092640-d3b5053b"
```

Do not change or auto-grant permissions. Keep Usage Access and the disposable Accessibility service enabled through the run. During the single
physical agreement prompt, watch the full blocked hold and press `P` only if restriction remains visibly continuous with no ordinary use/flicker;
press `F` on a visible failure or `I` if missed/uncertain. Preserve the printed evidence directory and stop on PASS, FAIL or INVALID.

Do not rerun this superseded v2 bundle. No 100-cycle qualification is authorized by this handoff. A calibration PASS would permit only repository review and preparation of a separately
authorized configuration-specific bundle; it would not close KR-003 or establish safety/lifecycle/Play support.

## Verification

- 19 Node evidence/security tests passed, including historical INVALID compatibility and strict typed-diagnostic ingestion.
- 423 assertions passed across all seven PowerShell suites under Windows PowerShell 5.1; every device call was absent or stubbed.
- The isolated Gradle `testDebugUnitTest lintDebug assembleDebug lintRelease assembleRelease` suite passed; build audit verified JVM `24/24`, merged permissions and debug/release isolation for all three modules.
- `node tools/validate.mjs` and `git diff --check` passed.

These are repository/bundle results, not physical calibration, enforcement, Samsung support or Play approval.
