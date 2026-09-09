# KR-003 Samsung configuration-bound qualification bundle — 2026-09-08

- **Goal:** Publish one immutable 100-cycle active-oracle qualification bundle bound to the exact Samsung calibration PASS, without executing it.
- **Context:** `calibration-20260908-231756-97a0855b` passed the bounded runner-v5 calibration with one excluded sample, explicit owner agreement and verified cleanup.
- **Constraints:** No physical execution, pooling/resume, permission grant, raw device output, serial, account/content/node/screenshot capture, cross-device inference, production move or KR-004 work. Unknown state fails closed.
- **Done when:** A clean source commit, calibration provenance, exact metadata/APK binding, payload hashes, native Windows PowerShell startup/static safety, Node/repository checks and Android debug/release isolation are verified; the manifest remains `physicalExecution=NOT_RUN`.

## Immutable publication

- Source commit: `33c2b36564d4d164d1992e41a9327a7968e44787`
- Windows path: `C:\platform-tools\kr003-qualification-bundles\33c2b36`
- Mounted path: `/mnt/c/platform-tools/kr003-qualification-bundles/33c2b36`
- Protocol / runner: `KR003-CONFIGURATION-ACTIVE-ORACLE-QUALIFICATION` / version 8
- `bundle.json` SHA-256: `a828d4689bfc552411f016262df1bd44f6b606c37efe1be66b73858bced4e4a0`
- Physical execution: **Not run**

The manifest binds captured `samsung` / `SM-X400` / Android `16` / API `36` / build `BP4A.251205.006` / security patch `2026-07-05`. `Galaxy Tab S10 Lite` and `One UI 8.5` remain separate owner-provided labels. It binds calibration source `4690d3951d0952fefe43eab9de0799599c6ea903`, directory `calibration-20260908-231756-97a0855b`, calibration summary/device hashes and transport evidence hash `e14837ade8cd72b48186ebc1bbdec439bb1ba1be263a8b6204696333db485ae7`.

## Payload hashes

| File | SHA-256 |
| --- | --- |
| `Start-KR003.ps1` | `1dee8165e2ead1b4f319dd7e6bfd54f59e335007ec60dc440b9281d4f9ab2196` |
| `Clear-KR003-Lab.ps1` | `58ede61ed8a22759953427704711e60c6a3fdc2b4388a29e5b177764a6779797` |
| `Qualification.psm1` | `8b06bcc37cf96f501659e730fc5167d9c6e69c114ff961ed120c4a9044f966fd` |
| `DevicePreflight.psm1` | `e0d77b65b7d5ea3e8f26245247ba33fadcf985b11af43aa0b2d032375f5449d3` |
| `protocol.md` | `eef2701e254022e8db1e20574f6c4293a6dcf82b1950adba7a2faa54c20994f7` |
| `candidate.apk` | `5b27c891fe155ee4d26e4da68f8323f178f7116e73d8097ce07199e5800e318b` |
| `ordinary-fixture.apk` | `223219c17a31439b52698e769bdf03ead0998bbbe8bbb5c1b0ff5be3cfaf21dc` |

The APK hashes exactly match the passed calibration. Every manifest payload hash was recomputed from mounted Windows storage.

## Qualification contract

The runner requires one new, non-resumable, non-pooled run: an excluded active-oracle preflight; exactly 100 fresh offline cycles with an independent fixture positive control, 20 denied blocked taps and no focus regain per cycle; candidate telemetry only as corroboration; and exactly three passing owner checkpoint records. It re-verifies typed Usage Access, Accessibility, heartbeat, health and eligibility before and after each expiry. Configuration, hash, permission or oracle uncertainty is INVALID and stops the run. A physical/oracle breach is FAIL and stops the run. PASS additionally requires p95 at most 2,000 ms, final safety, CLEAR/bailout, network restoration and error-free finalization.

Expected elapsed time is approximately 45–60 minutes, including 35–45 unattended minutes for attempts 1–100. The owner interacts only in the initial preflight session and the final guided safety session; the controlled negative confirmation is part of the initial session. There are no prompts during the 100-cycle section.

Future owner command, not executed during publication:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\platform-tools\kr003-qualification-bundles\33c2b36\Start-KR003.ps1" -OfflineNetwork
```

If the device becomes inconvenient to use, press `Q` in the runner. If cleanup is not visibly/explicitly verified, preserve the run directory and execute:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\platform-tools\kr003-qualification-bundles\33c2b36\Clear-KR003-Lab.ps1"
```

The helper sends only the disposable lab `CLEAR`, verifies the restriction/overlay are absent and preserves latency samples. It does not uninstall, clear app data, change permissions, inject input, change network settings or establish consumer recovery evidence. If network restoration is unverified, use the retained minimized `network-original.json` flags for owner-assisted restoration.

## Validation boundary

- Node evidence/security: 20/20 passed.
- Native Windows PowerShell 5.1.26100.9168: 480 source assertions passed without a device; the mounted bundle then passed the reserved-variable scan and actual entrypoint startup test before any device command.
- Android isolated suite: 24/24 JVM executions, debug/release lint and builds passed; merged permissions/receiver protection/release DEX isolation passed for all three modules.
- Repository validation, strict calibration reingestion, bundle payload rehash and `git diff --check` passed.
- PowerShell 7 execution is delegated to CI because `pwsh` is unavailable in the local environment.

These are synthetic/host/build results only. They do not create a qualification row or change the calibration verdict.
