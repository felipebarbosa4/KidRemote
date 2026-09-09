# KR-003 Samsung capability-aware qualification bundle — 2026-09-09

- **Goal:** Publish one immutable runner-v9 qualification bundle after the preserved Samsung network-preflight INVALID, without executing it.
- **Context:** Runner-v8 treated a global `mobile_data` value as capability and entered an inapplicable mobile-data mutation branch on the exact SM-X400 Wi-Fi SKU. The prior run remains independently INVALID with zero cycles.
- **Constraints:** Same passed calibration, exact device/APK binding and active-oracle gates; no Samsung-specific branch, airplane-mode substitution, root, permission mutation, raw command output, physical execution, pooling/resume, production move or KR-004 work. Unknown capability/state fails closed.
- **Done when:** Clean committed source, calibration provenance, Android/system-feature behavior, PowerShell 5.1/7, Node, build/lint/release isolation and all hashes are verified; `physicalExecution=NOT_RUN` remains true.

## Immutable publication

- Source commit: `532bc22df0084b62e202a0cda0158dc61331f180`
- Windows path: `C:\platform-tools\kr003-qualification-bundles\532bc22`
- Mounted path: `/mnt/c/platform-tools/kr003-qualification-bundles/532bc22`
- Protocol / runner: `KR003-CONFIGURATION-ACTIVE-ORACLE-QUALIFICATION` / version 9
- `bundle.json` SHA-256: `1689917375f274e28e82b0ae23e12dba6c1454acb81773217e78adb67507eab7`
- Physical execution: **Not run**

The manifest remains bound to captured `samsung` / `SM-X400` / Android `16` / API `36` / build `BP4A.251205.006` / security patch `2026-07-05`, the passed calibration and exact APKs. `Galaxy Tab S10 Lite` and `One UI 8.5` remain separate owner labels.

## Payload hashes

| File | SHA-256 |
| --- | --- |
| `Start-KR003.ps1` | `63e769f48baeb7d498151cc2f812df2325a422a84318cec8cd0487b5a603eb98` |
| `Clear-KR003-Lab.ps1` | `d7b669078b3acde025d3df4db0d15a035b2e1e92d05389e39407cf80689fa16b` |
| `Qualification.psm1` | `c279b42e63e482e61e89b4b2e3ec13ee463ac6b192a86e3f6bc895d30fae72eb` |
| `DevicePreflight.psm1` | `e0d77b65b7d5ea3e8f26245247ba33fadcf985b11af43aa0b2d032375f5449d3` |
| `protocol.md` | `c962b4553080d537d430b5c745c196922bc9ed88867c339a8c7a082749e20041` |
| `candidate.apk` | `5b27c891fe155ee4d26e4da68f8323f178f7116e73d8097ce07199e5800e318b` |
| `ordinary-fixture.apk` | `223219c17a31439b52698e769bdf03ead0998bbbe8bbb5c1b0ff5be3cfaf21dc` |

Every manifest payload hash was independently recomputed from mounted Windows storage. The APK hashes remain exactly those from the passed calibration.

## Network model

Before any network mutation, the runner queries exactly `android.hardware.wifi` and `android.hardware.telephony.data` through `pm has-feature`.
The result is `PRESENT`, `ABSENT` or `UNKNOWN`; `UNKNOWN` is INVALID. Only present paths have state read as an offline prerequisite. Enabled
present paths are disabled and read back; originally enabled paths are restored and read back in finalization. Absent paths are retained as
`NOT_APPLICABLE`, not mutated and not allowed to turn a stale global setting into a cellular requirement. The owner must still confirm that no
other Internet path exists. Airplane mode is unchanged.

`network-operations.json` retains only sequence, operation enum, phase, accepted/rejected/timeout, integer exit code, coarse stderr class and time.
Raw stdout/stderr, package history, serial, account/content data and unrelated settings are not persisted.

## Validation boundary

- Node evidence/security: 21/21 passed, including rejection of added raw network fields and zero-cycle preflight INVALID preservation.
- Native Windows PowerShell 5.1.26100.9168: qualification network tests, all runner suites, reserved-variable scan and actual mounted-bundle redirected-input startup passed without a device.
- Exact pushed-head [CI run 34313431060](https://github.com/felipebarbosa4/KidRemote/actions/runs/34313431060) passed all three jobs, including the full PowerShell suite under PowerShell 7 and native Windows PowerShell 5.1.
- Android isolated suite: 24/24 JVM executions, debug/release lint and builds passed; merged permissions, protected receiver and release DEX isolation passed for all modules.
- Strict reingestion of the v8 physical run, calibration provenance, repository validation, mounted payload rehash and `git diff --check` passed.

These results validate runner/build behavior only. They do not create a qualification row, establish the runtime feature values or authorize automatic physical execution.

## Future command — not executed

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\platform-tools\kr003-qualification-bundles\532bc22\Start-KR003.ps1" -OfflineNetwork
```

Before that one future owner-run attempt, confirm ordinary Wi-Fi use is currently restored/on. No mobile-data restoration action is meaningful for the manufacturer-labelled Wi-Fi-only SM-X400 SKU; runner-v9 will independently verify the device-reported telephony-data feature and fail closed if it cannot.
