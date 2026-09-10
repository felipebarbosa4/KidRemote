# KR-003 Samsung excluded dual-Home diagnostic bundle — 2026-09-09

- **Goal:** Publish one short, configuration-bound diagnostic of the exact runner-v12/OD-39 Home gate before another full qualification attempt, without executing it.
- **Context:** Multiple complete automated sections have ended at checkpoint 3. OD-40 authorizes a zero-row check of whether Path A or Path B is operational on this Samsung configuration.
- **Constraints:** Reuse the runner-v12 candidate, fixture, permission verifier, Home transport and hold logic; exact configuration and calibration binding; no network/navigation/credential mutation, historical reclassification, resume/pooling, physical execution, matrix claim, production move or KR-004 work. Unknown remains fail-closed.
- **Done when:** Clean source and every payload hash are pinned; native PowerShell 5.1/7, Node/security, Android release-isolation and repository checks pass; mounted payloads equal source; physical execution remains **Not run**.

## Immutable handoff

| Field | Value |
| --- | --- |
| Source commit | `4288c798bdf959857a2e0729e529d63910f9480c` |
| Windows path | `C:\platform-tools\kr003-dual-home-diagnostic-bundles\4288c79` |
| Mounted path | `/mnt/c/platform-tools/kr003-dual-home-diagnostic-bundles/4288c79` |
| Protocol / runner | `KR003-DUAL-HOME-CALIBRATION-DIAGNOSTIC` / v12 |
| `bundle.json` SHA-256 | `041ce2546f6e8dd374674ce0c031ed26fed2c91293b63bdc176edc9148ef4999` |
| Physical execution | **Not run** |
| Qualification / TIME-04 rows | `0` / `0` |
| Matrix contribution | `NONE` |

The bundle is bound to captured `samsung` / `SM-X400` / Android 16 / API 36 / build `BP4A.251205.006` / security patch `2026-07-05`, passed calibration `calibration-20260908-231756-97a0855b`, candidate SHA-256 `5b27c891fe155ee4d26e4da68f8323f178f7116e73d8097ce07199e5800e318b`, and fixture SHA-256 `223219c17a31439b52698e769bdf03ead0998bbbe8bbb5c1b0ff5be3cfaf21dc`. `Galaxy Tab S10 Lite` and `One UI 8.5` remain owner-provided labels.

## Scope and evidence semantics

This diagnostic is an explicit mode of `Start-KR003.ps1`, not a second Home implementation. It uses the same `Invoke-HomeKeyPositiveControl`, `Invoke-QualificationSafetyCheckpoint -HomeOnly`, Path A, Path B, restricted-stimulus and hold-oracle functions shipped in runner-v12. Its manifest hard-codes `diagnosticOnly=true`, `qualificationCycles=0`, `time04Rows=0`, `matrixContribution=NONE`, and disables resume/pooling. Strict ingestion rejects attempts, qualification rows, network-operation artifacts or Path B mislabeled as physical resistance.

The runner verifies exact metadata/APK hashes, Usage Access, Accessibility, heartbeat, health/eligibility, shell-tap delivery, unlocked interactive state and reversible stay-awake state. With CLEAR and the independent fixture focused, one fixed host `KEYCODE_HOME` must be accepted, displace the fixture without a tap, and permit return to the same known fixture. Only then does the runner arm one excluded ten-second restriction and perform one visible ten-second Home safety check.

- Path A applies when the owner reports an exercisable control/gesture and performs exactly one displayed physical action. Held restriction plus independent corroboration records `HOME_ACTION_EXERCISED_AND_RESISTED`; escape is FAIL; uncertainty is INVALID.
- Path B applies only when the owner reports the control unavailable. One already-calibrated fixed host stimulus must preserve restriction/attachment/health and cause no fixture focus/input return, and the owner must confirm continued visible restriction. Its distinct success is `HOME_ESCAPE_PATH_BLOCKED_WITH_CONTROL_UNAVAILABLE`; it is never physical Home resistance.

Cleanup issues CLEAR, verifies unarmed/unrestricted/unattached candidate state, proves restored ordinary fixture input, and restores/verifies the exact original stay-awake setting. The diagnostic does not require offline state and never changes Wi-Fi/mobile data.

## Payload hashes

| File | SHA-256 |
| --- | --- |
| `Start-KR003.ps1` | `6a66b105c6f9b0b04f5b936087addc8e379f4b0622e44dcd77f4eba291ee5c75` |
| `Clear-KR003-Lab.ps1` | `0bf3f0e3fab62804555aaa194c67424ac123f9b367f496761a4bd572a23eb326` |
| `Qualification.psm1` | `d6bd28f68ee8f1c8ee8b13b0fe9b0e90a19c0474cd183aac6c8f26bd292a0e6b` |
| `DevicePreflight.psm1` | `e0d77b65b7d5ea3e8f26245247ba33fadcf985b11af43aa0b2d032375f5449d3` |
| `protocol.md` | `5e040018d0532ed70add5f8da64bac36295712e079460d45097c1adc90710367` |
| `candidate.apk` | `5b27c891fe155ee4d26e4da68f8323f178f7116e73d8097ce07199e5800e318b` |
| `ordinary-fixture.apk` | `223219c17a31439b52698e769bdf03ead0998bbbe8bbb5c1b0ff5be3cfaf21dc` |

## Validation and stopped state

Local checks passed 23 Node evidence/security tests, all 697 native Windows PowerShell 5.1 assertions across the KR-003 suites, repository validation, `git diff --check`, Gradle debug/release unit tests, lint and assemblies, 24/24 audited JVM executions, merged-manifest checks and release DEX isolation. Exact-source [CI run 34415929533](https://github.com/felipebarbosa4/KidRemote/actions/runs/34415929533) passed repository/Node checks, native Windows PowerShell 5.1, PowerShell 7, and Android build/lint/release-isolation. The mounted payload hashes match `bundle.json`, its scripts/protocol are byte-identical to source, and its actual entrypoint passed six native PowerShell 5.1 startup assertions without a device command.

No device or ADB command was executed during preparation, tests, packaging or mounted verification. The expected owner-side duration is approximately 3–5 minutes, depending on ADB/install speed and response time. A future configuration-specific diagnostic PASS can justify offering one final entirely fresh runner-v12 100-cycle attempt; it does not authorize, execute or contribute evidence to that attempt.

## One future owner command

Do not run automatically. If the owner later chooses to execute this short diagnostic once:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\platform-tools\kr003-dual-home-diagnostic-bundles\4288c79\Start-KR003.ps1" -DualHomeDiagnostic
```

Start with the tablet unlocked, interactive and on stable external power/ADB, with Usage Access and the disposable Accessibility service enabled. Watch the visible restriction for ten seconds. At `HOME CONTROL CHECK`, answer `A` if Home is currently exercisable, `U` if unavailable as presented, `I` if uncertain, or `Q` to stop. For `A`, perform exactly one instructed physical Home action and answer the result prompt. For `U`, do not change navigation mode or seek a hidden control; allow the runner's one calibrated host stimulus and answer whether the restriction remained visibly effective. No Settings/recovery checkpoint is part of this diagnostic.

## Subsequent execution

The owner later ran this immutable diagnostic once. Its [strictly ingested configuration-specific Path-B PASS](KR-003-SAMSUNG-DUAL-HOME-DIAGNOSTIC-PASS-2026-09-10.md) is separate physical evidence. The publication-time **Not run** field above remains the immutable handoff state; do not rerun or reinterpret it as qualification.
