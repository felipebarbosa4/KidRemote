# KR-003 Samsung qualification runner-v12 dual-Home bundle — 2026-09-09

- **Goal:** Publish one immutable configuration-bound qualification bundle implementing OD-39's prospective dual-path Home safety gate, without executing it.
- **Context:** Runner-v11 established that coarse navigation mode does not prove that a Home control is available while the restriction is active. The owner approved a real physical Home path when exercisable and a separately named control-unavailable path using an independently calibrated host Home stimulus.
- **Constraints:** Exact calibrated Samsung configuration and APK hashes; no historical reclassification, resume/pooling, candidate-generated Home, navigation/lock change, raw command output, launcher/package history, content capture, physical execution, production move or KR-004 work. Unknown remains fail-closed.
- **Done when:** The clean source and every payload hash are pinned; Path A and Path B retain distinct semantics; PowerShell 5.1/7, Node, Android build/lint/release isolation and repository checks pass; the mounted bundle matches source; execution stops before a future owner run.

## Immutable handoff

| Field | Value |
| --- | --- |
| Source commit | `80dcdf4846ccbe4fbb0eabb7c226ecf88c58bafd` |
| Windows path | `C:\platform-tools\kr003-qualification-bundles\80dcdf4` |
| Mounted path | `/mnt/c/platform-tools/kr003-qualification-bundles/80dcdf4` |
| Protocol / runner | `KR003-CONFIGURATION-ACTIVE-ORACLE-QUALIFICATION` / v12 |
| `bundle.json` SHA-256 | `9d68d18a4e71f6d524a7fae77a0f5eedf4949d7d739bfedafd67054f08f30a28` |
| Physical execution | **Not run** |

The bundle is bound to captured `samsung` / `SM-X400` / Android 16 / API 36 / build `BP4A.251205.006` / security patch `2026-07-05`, passed calibration `calibration-20260908-231756-97a0855b`, candidate SHA-256 `5b27c891fe155ee4d26e4da68f8323f178f7116e73d8097ce07199e5800e318b`, and fixture SHA-256 `223219c17a31439b52698e769bdf03ead0998bbbe8bbb5c1b0ff5be3cfaf21dc`. `Galaxy Tab S10 Lite` / `One UI 8.5` remain owner-provided labels.

## Prospective Home evidence gate

Navigation mode is contextual metadata only. At checkpoint 3, the runner asks whether the current Home control/gesture is physically exercisable.

- **Path A — physical Home action:** `AVAILABLE` leads to the appropriate button/gesture instruction. The owner performs exactly one real Android system Home action. An owner-observed held restriction plus the independent hold oracle records `HOME_ACTION_EXERCISED_AND_RESISTED`; an observed or independently established ordinary-use escape records `HOME_ACTION_EXERCISED_AND_ESCAPED`; uncertainty records `HOME_ACTION_RESULT_UNCERTAIN` and is INVALID.
- **Path B — control unavailable:** `UNAVAILABLE` records the physical control-unavailability observation, not resistance. Before sample 1, while the ordinary fixture is unblocked and focused, the host injects exactly one fixed `adb shell input keyevent KEYCODE_HOME`. The fixture must independently record foreground/focus displacement without a tap, and the runner must return and verify the same fixture state. Under restriction it snapshots fixture/candidate state, injects exactly one more fixed host stimulus, and requires restriction/attachment/health continuity, no fixture focus regain or input delivery, and owner-observed continued restriction. Only that combination records `HOME_ESCAPE_PATH_BLOCKED_WITH_CONTROL_UNAVAILABLE`. It never records physical Home resistance.
- **Fail closed:** owner uncertainty, absent/rejected/no-effect calibration when Path B is selected, failed fixture return, rejected restricted stimulus, unknown state, or uncertain physical/oracle result is INVALID. A real physical Home escape, restriction loss, fixture focus regain/input leak, or owner-observed ordinary-use return is FAIL.

The candidate Accessibility service does not issue Home. The host command is stimulus only. The fixture remains a separate package/UID with no candidate callback, shared storage or network permission and supplies the primary non-candidate focus/input oracle. Candidate telemetry only corroborates restriction, attachment, eligibility and health.

Historical Mi 8 and Samsung evidence remains byte-for-byte unmodified and keeps its recorded verdict. No prior row is resumed, replaced or pooled.

## Payload hashes

| File | SHA-256 |
| --- | --- |
| `Start-KR003.ps1` | `2ada3c7d06525c02346d4143ebb2566b21deaa9f31f595851c1f0f8e9645b98e` |
| `Clear-KR003-Lab.ps1` | `0bf3f0e3fab62804555aaa194c67424ac123f9b367f496761a4bd572a23eb326` |
| `Qualification.psm1` | `f8b1befab309e53731be5de90772028811ac673741317d3a529bb2ba4a006d25` |
| `DevicePreflight.psm1` | `e0d77b65b7d5ea3e8f26245247ba33fadcf985b11af43aa0b2d032375f5449d3` |
| `protocol.md` | `cb940378a69748d9c2a759ed09f0999c703f798245e2606136b80e5110776eae` |
| `candidate.apk` | `5b27c891fe155ee4d26e4da68f8323f178f7116e73d8097ce07199e5800e318b` |
| `ordinary-fixture.apk` | `223219c17a31439b52698e769bdf03ead0998bbbe8bbb5c1b0ff5be3cfaf21dc` |

## Validation

Local synthetic/stubbed checks passed 157 PowerShell qualification assertions, 220 runner/finalization assertions and all transport, preflight, calibration, reserved-variable and entrypoint suites under native Windows PowerShell `5.1.26100.9168`; no device command was executed. The mounted bundle is byte-identical to the pinned source payload and passed native 5.1 startup plus reserved-variable inspection. Also passed: 22 Node evidence/security tests, repository validation, `git diff --check`, isolated Gradle debug/release unit/lint/assembly, 24/24 JVM executions, merged-manifest checks and release DEX isolation.

Exact-source [CI run 34406041885](https://github.com/felipebarbosa4/KidRemote/actions/runs/34406041885) passed all three jobs: repository/Node/PowerShell 7 validation, native Windows PowerShell 5.1 runner tests, and the isolated Android enforcement spike. Packaging rebuilt the unchanged APK sources and copied the hash-pinned payloads from the clean source commit.

## One future owner command

Do not run automatically. If the owner later authorizes one entirely fresh attempt:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\platform-tools\kr003-qualification-bundles\80dcdf4\Start-KR003.ps1" -OfflineNetwork
```

Begin unlocked, interactive, on stable external power/ADB, with Usage Access and the disposable Accessibility service enabled and ordinary Wi-Fi available. Complete checkpoints 1/2, leave the device untouched during all 100 automated cycles, and return for checkpoint 3. Watch the restriction for ten seconds, then answer `A` if Home is exercisable, `U` if it is genuinely unavailable as presented, or `I` if uncertain. With `A`, perform exactly one displayed physical Home action and report the visible result. With `U`, do not change navigation mode or seek a hidden control; let the already calibrated host stimulus run once under restriction, then report whether restriction remains visibly effective. Complete Settings/Digital Wellbeing/recovery/re-entry only after the Home path passes. Do not tap **Open device settings** during a Home prompt.

Allow approximately 75–90 minutes, including approximately 60–70 unattended minutes. Press `Q` at an active prompt if the device becomes inconvenient; normal finalization attempts diagnostic CLEAR and exact stay-awake/network restoration. If the console is unusable, run `Clear-KR003-Lab.ps1` from another PowerShell window to release only the disposable timer, preserve the run directory, and use its minimized journals to determine whether network or stay-awake state needs owner-assisted restoration.

No matrix row advances at publication. A future PASS would apply only to the exact bound configuration and would not complete lifecycle, tamper, broader safety, Play or production gates.
