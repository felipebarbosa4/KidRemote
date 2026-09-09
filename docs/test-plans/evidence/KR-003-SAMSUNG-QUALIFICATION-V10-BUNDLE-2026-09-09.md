# KR-003 Samsung qualification runner-v10 bundle — 2026-09-09

- **Goal:** Publish one immutable stay-awake-aware replacement after the preserved runner-v9 checkpoint-3 INVALID, without executing it.
- **Context:** Runner-v9 retained 100 automated PASS rows but lost combined screen/keyguard eligibility while waiting for checkpoint-3 owner input. Android's Stay awake while plugged in mechanism is suitable for this authorized powered lab run.
- **Constraints:** Exact passed-calibration configuration and APK hashes; no physical execution, result pooling/resume, lock-security change, root, device-owner assumption, raw battery/settings capture, enforcement change, production move or KR-004 work.
- **Done when:** Clean source and every payload hash are pinned; PowerShell 5.1/7, Node, Android build/lint/release isolation and repository checks pass; the mounted bundle matches source; one future command and exact interaction/bailout boundary are recorded.

## Immutable handoff

| Field | Value |
| --- | --- |
| Source commit | `fd9824943c35f70d393f7b0e0b252c2a8253a2d9` |
| Windows path | `C:\platform-tools\kr003-qualification-bundles\fd98249` |
| Mounted path | `/mnt/c/platform-tools/kr003-qualification-bundles/fd98249` |
| Protocol / runner | `KR003-CONFIGURATION-ACTIVE-ORACLE-QUALIFICATION` / v10 |
| `bundle.json` SHA-256 | `f4bf6e52b6cc7e61fa335ac1f93a6828085779f3a988bd217bb31443b1f294b2` |
| Physical execution | **Not run** |

The bundle remains bound to `samsung` / `SM-X400` / Android 16 / API 36 / build `BP4A.251205.006` / security patch `2026-07-05`, passed calibration `calibration-20260908-231756-97a0855b`, candidate SHA-256 `5b27c891fe155ee4d26e4da68f8323f178f7116e73d8097ce07199e5800e318b`, and independent fixture SHA-256 `223219c17a31439b52698e769bdf03ead0998bbbe8bbb5c1b0ff5be3cfaf21dc`. `Galaxy Tab S10 Lite` / `One UI 8.5` are retained as owner-provided labels.

## Bounded change

Runner-v10 requires the tablet to start unlocked/interactively eligible and connected to a recognized AC, USB, wireless or dock power source. It journals the original integer `stay_on_while_plugged_in` value and coarse source class, invokes Android's `svc power stayon true` only when needed, verifies the applied setting covers the current power source at cycle boundaries, and restores/readbacks the exact original integer in finalization. Raw `dumpsys battery` and settings output are never persisted. Unknown state, unplugging, enable/readback failure or restoration failure remains INVALID/fail closed. No PIN, pattern, password, permission, enforcement or oracle behavior changes.

Android documents Stay awake as keeping the screen on while plugged in; Android 16's AOSP `svc power` implementation wakes the screen and applies the plugged-source bitmask. [Android developer option](https://developer.android.com/studio/debug/dev-options#general), [Android 16 `svc power` source](https://android.googlesource.com/platform/frameworks/base/+/android16-qpr2-release/cmds/svc/src/com/android/commands/svc/PowerCommand.java), [BatteryManager constants](https://developer.android.com/reference/android/os/BatteryManager#BATTERY_PLUGGED_USB).

## Payload hashes

| File | SHA-256 |
| --- | --- |
| `Start-KR003.ps1` | `5f6556a499b3487b5c521c98e9447b5c9e8d97bc3e617806a91d7f4613328bd3` |
| `Clear-KR003-Lab.ps1` | `ff6d5bcaa8f555b38e6aacaa2c84dd76f45f676316d8d1ae5fed15bf4969bc6c` |
| `Qualification.psm1` | `67a9ded23784d251fcac84bc36c814d655fc07695591ccc8a31be08966874641` |
| `DevicePreflight.psm1` | `e0d77b65b7d5ea3e8f26245247ba33fadcf985b11af43aa0b2d032375f5449d3` |
| `protocol.md` | `87f38813ee4ef300e9da48dd5cd5d27136b517f9b98f9c6c7da0f79bccba87cd` |
| `candidate.apk` | `5b27c891fe155ee4d26e4da68f8323f178f7116e73d8097ce07199e5800e318b` |
| `ordinary-fixture.apk` | `223219c17a31439b52698e769bdf03ead0998bbbe8bbb5c1b0ff5be3cfaf21dc` |

## Validation

Before publication, local checks passed:

- 135 PowerShell qualification assertions and 135 finalization assertions under native Windows PowerShell 5.1;
- all transport/calibration PowerShell suites, the reserved-variable scan, and actual bundled redirected-input startup under Windows PowerShell 5.1 with zero device commands;
- 22 Node evidence/security tests;
- repository validation and `git diff --check`;
- isolated Gradle `:app:testDebugUnitTest`, `lintDebug`, `assembleDebug`, `lintRelease`, `assembleRelease` (24/24 JVM executions);
- merged-manifest and release DEX isolation for candidate, fixture and input probe.

Exact-source [CI run 34357242810](https://github.com/felipebarbosa4/KidRemote/actions/runs/34357242810) passed all three jobs: repository/Node/PowerShell 7 validation, native Windows PowerShell 5.1 runner tests, and the isolated Android enforcement spike.

## One future owner command

Do not run automatically. For one entirely fresh attempt only:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\platform-tools\kr003-qualification-bundles\fd98249\Start-KR003.ps1" -OfflineNetwork
```

Before invoking it, connect the tablet to stable external power/ADB, unlock it, leave Usage Access and the disposable Accessibility service enabled, and confirm ordinary Wi-Fi use is available. At the start, respond to the offline confirmation and checkpoints 1/2 as guided. Do not touch the device during the approximately 60–70 minute 100-cycle section. Return after `Automated expiry 100/100` for checkpoint 3 and follow each visible/Home/Settings/re-entry/CLEAR prompt. Budget approximately 75–90 minutes total.

Press `Q` in the active runner at any prompt if the tablet becomes inconvenient; the runner attempts lab CLEAR, exact stay-awake restoration and network restoration in finalization. If the console is unavailable, run the bundled `Clear-KR003-Lab.ps1` to release only the disposable timer; that emergency script does not prove or perform network/stay-awake restoration, so inspect the retained journals before manually restoring any unverified state.
