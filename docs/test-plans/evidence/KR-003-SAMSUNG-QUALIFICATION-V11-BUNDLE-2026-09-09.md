# KR-003 Samsung qualification runner-v11 bundle — 2026-09-09

- **Goal:** Publish one immutable navigation-aware replacement after preserving runner-v10's checkpoint-3 FAIL, without executing it.
- **Context:** Runner-v10 retained 100 automated PASS rows and final visibility PASS, then its automated Home-phase hold poll observed an out-of-sequence overlay Settings action before any Home response/action was established.
- **Constraints:** Exact calibrated Samsung configuration and APK hashes; read-only/minimized navigation evidence; no physical execution, navigation-mode mutation, pooling/resume, enforcement/oracle weakening, content capture, production move or KR-004 work.
- **Done when:** Clean source and every payload hash are pinned; PowerShell 5.1/7, Node, Android build/lint/release isolation and repository checks pass; the mounted bundle matches source; execution stops before a future owner run.

## Immutable handoff

| Field | Value |
| --- | --- |
| Source commit | `6cf04ab8a9455689783ef97d8babb8cc07d81485` |
| Windows path | `C:\platform-tools\kr003-qualification-bundles\6cf04ab` |
| Mounted path | `/mnt/c/platform-tools/kr003-qualification-bundles/6cf04ab` |
| Protocol / runner | `KR003-CONFIGURATION-ACTIVE-ORACLE-QUALIFICATION` / v11 |
| `bundle.json` SHA-256 | `fb653fb42b7ea6334a5118e59dce609ad80520f14f76985545d3dc95f445f1c8` |
| Physical execution | **Not run** |

The bundle remains bound to captured `samsung` / `SM-X400` / Android 16 / API 36 / build `BP4A.251205.006` / security patch `2026-07-05`, passed calibration `calibration-20260908-231756-97a0855b`, candidate SHA-256 `5b27c891fe155ee4d26e4da68f8323f178f7116e73d8097ce07199e5800e318b`, and fixture SHA-256 `223219c17a31439b52698e769bdf03ead0998bbbe8bbb5c1b0ff5be3cfaf21dc`. `Galaxy Tab S10 Lite` / `One UI 8.5` remain owner-provided labels.

## Bounded change

Runner-v11 reads the current user's AOSP `navigation_mode` without writing it and persists only `THREE_BUTTON`, `TWO_BUTTON`, `GESTURE` or `UNKNOWN`, its parse/source enum, verification count and time. Unknown or changed mode stops INVALID. The checkpoint instructs a tap on the on-screen Home control for button modes or one swipe up from the bottom edge for gesture mode; it explicitly forbids the overlay Settings control until the recovery phase.

The retained result distinguishes `HOME_ACTION_EXERCISED_AND_RESISTED`, `HOME_ACTION_EXERCISED_AND_ESCAPED`, and `HOME_ACTION_NOT_EXERCISABLE_OR_UNKNOWN`, plus owner, automated-hold-oracle, or out-of-sequence-Settings source. A real automated ordinary-surface hold violation still raises FAIL. An overlay Settings activation during the Home phase stops INVALID before its allowed safe-surface detach can be mislabelled as a Home escape. Candidate, permission, attachment, input/focus, offline, stay-awake, recovery and cleanup semantics are unchanged.

Android's user guidance defines gesture Home as swiping up from the bottom and three-button Home as tapping the on-screen Home control. Android 16 AOSP defines the internal navigation interaction modes as 0/1/2 for three-button/two-button/gestural; OEM or unparseable values remain fail-closed. [Android system navigation](https://support.google.com/android/answer/9079644), [Android 16 `Settings.Secure.NAVIGATION_MODE`](https://android.googlesource.com/platform/frameworks/base/+/android16-release/core/java/android/provider/Settings.java), [Android 16 navigation resource](https://android.googlesource.com/platform/frameworks/base/+/android16-release/core/res/res/values/config.xml).

## Payload hashes

| File | SHA-256 |
| --- | --- |
| `Start-KR003.ps1` | `a59ed33ce780719cf8d8e81b04ae5e338d290189240e75f554afbf45ca566b93` |
| `Clear-KR003-Lab.ps1` | `986401ea5b2805e75234305c58d7c21fbe33e429fb7a11431145a08a3e27d5c4` |
| `Qualification.psm1` | `a1b44631db69b4bf3c9207a93da5f8517c3721850b25571d20006e35d8c9ca4f` |
| `DevicePreflight.psm1` | `e0d77b65b7d5ea3e8f26245247ba33fadcf985b11af43aa0b2d032375f5449d3` |
| `protocol.md` | `dd9dd62b032de5f1326876d3befaa6197f5345752eb438c2efda0ab4b554699f` |
| `candidate.apk` | `5b27c891fe155ee4d26e4da68f8323f178f7116e73d8097ce07199e5800e318b` |
| `ordinary-fixture.apk` | `223219c17a31439b52698e769bdf03ead0998bbbe8bbb5c1b0ff5be3cfaf21dc` |

## Validation

Before publication, local checks passed 148 PowerShell qualification assertions, 158 finalization/orchestration assertions, every transport/calibration suite, reserved-variable inspection, and redirected-input entrypoint checks under native Windows PowerShell `5.1.26100.9168`; all used synthetic/stubbed state and no device command. The actual mounted bundle then passed its native 5.1 entrypoint and reserved-variable checks. Also passed: 22 Node evidence/security tests, repository validation, `git diff --check`, isolated Gradle debug/release unit/lint/assembly (24/24 JVM executions), merged-manifest checks and release DEX isolation.

Exact-source [CI run 34374977856](https://github.com/felipebarbosa4/KidRemote/actions/runs/34374977856) passed all three jobs: repository/Node/PowerShell 7 validation, native Windows PowerShell 5.1 runner tests, and the isolated Android enforcement spike. Packaging recopied the hash-pinned source payloads and rebuilt the unchanged APK sources from this clean commit.

## One future owner command

Do not run automatically. If the owner later authorizes one entirely fresh attempt:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\platform-tools\kr003-qualification-bundles\6cf04ab\Start-KR003.ps1" -OfflineNetwork
```

Begin unlocked, interactive, on stable external power/ADB, with Usage Access and the disposable Accessibility service enabled and ordinary Wi-Fi available. Follow checkpoints 1/2, leave the device untouched during the 100 automated cycles, then at checkpoint 3 use exactly the displayed current-mode Home action. Do not tap **Open device settings** until its later recovery prompt. `I` stops INVALID if Home is not exercisable or the result is uncertain.

Press `Q` at an active prompt if the device becomes inconvenient; normal finalization attempts diagnostic CLEAR plus exact stay-awake/network restoration. If the console is unusable, run the bundle's `Clear-KR003-Lab.ps1` from another PowerShell window to release only the disposable timer, then use retained journals to determine whether any network/stay-awake state needs manual restoration.
