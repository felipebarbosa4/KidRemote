# KR-003 Samsung excluded visual-channel calibration bundle — 2026-09-10

- **Goal:** Publish one short, configuration-bound calibration of a local visual evidence channel without executing it.
- **Context:** OD-41 prospectively allows calibrated visual evidence to replace eligible human VISUAL checkpoints only after this separate mechanism test agrees with the independent fixture/input/focus oracle.
- **Constraints:** Owner-operated local lab only; raw/image-bearing media outside repository and cloud paths; no upload, assistant/tool vision, OCR, UI node/text capture, secure-content bypass, production capture path, network mutation, qualification/TIME-04 row, matrix claim, historical reinterpretation or KR-004 work.
- **Done when:** Clean exact source and payload hashes are pinned, local synthetic/security and native Windows entrypoint/bailout checks pass, CI passes Windows PowerShell 5.1/7 and Android release isolation, physical execution remains **Not run**, and handoff stops at one owner command.

## Immutable handoff

| Field | Value |
| --- | --- |
| Source commit | `0596173c0086fcf76fcf46c7f98dabbc6ba8a874` |
| Windows path | `C:\platform-tools\kr003-visual-calibration-bundles\0596173` |
| Mounted path | `/mnt/c/platform-tools/kr003-visual-calibration-bundles/0596173` |
| Protocol / runner | `KR003-VISUAL-CHANNEL-CALIBRATION` / v1 |
| `bundle.json` SHA-256 | `c69c2d0aa76574afee874fa0b01e89b4f4a92588816f99a20b8178573e357af7` |
| Physical execution | **Not run** |
| Qualification / TIME-04 rows | `0` / `0` |
| Human observations | `0` |
| Matrix contribution | `NONE` |

The bundle is bound to captured `samsung` / `SM-X400` / Android 16 / API 36 / build `BP4A.251205.006` / security patch `2026-07-05`, passed calibration `calibration-20260908-231756-97a0855b`, candidate SHA-256 `5b27c891fe155ee4d26e4da68f8323f178f7116e73d8097ce07199e5800e318b`, and fixture SHA-256 `223219c17a31439b52698e769bdf03ead0998bbbe8bbb5c1b0ff5be3cfaf21dc`. `Galaxy Tab S10 Lite` / `One UI 8.5` remain owner-provided labels.

## Capture, classification and evidence boundary

The owner-operated runner first foregrounds the disposable ordinary fixture, then repeatedly invokes official `adb exec-out screencap -p`. Every accepted PNG stays beneath the owner-local run's `raw-frames` directory. The worker emits only a filename, SHA-256, byte count, coarse result and actual host-monotonic request start/end interval. PNG has no device presentation timestamp, so the runner neither manufactures one nor imposes a frame rate; it treats the complete request duration as timestamp-alignment uncertainty.

Local Windows `System.Drawing` decoding reduces each complete frame in memory to a 24×24 RGB grid. Only sanitized distances, spatial coverage, hashes, timing bounds and typed classifications persist. The grid and image bytes are not emitted. Phase labels come from independent ordinary-fixture controls, a fresh restriction/attachment oracle, and verified CLEAR—not candidate visual telemetry alone. PASS requires repeatable ordinary references, spatially distributed ordinary/restricted separation, at least three frames in each main phase, a restricted window of at least ten seconds, at least 90% measured span coverage, strictly advancing/non-overlapping requests, worst-case sampling gap no greater than 1,500 ms, and agreement with the independent fixture/candidate health oracle.

The run-reported `DefensibleInterruptionDetectionBoundMillis` is the shortest interruption duration the sampled channel can conservatively claim it would detect for that run; PASS caps it at 1,500 ms. Shorter events, events wholly between samples, compositor/display behavior not represented by `screencap`, and sub-threshold visual changes remain unobserved. Repeated images on a static surface are allowed when capture intervals advance and the controlled ordinary → restricted → ordinary transitions remain visible. Frozen output across transitions, reused timestamps, blank/protected output, ambiguous classification or insufficient coverage is INVALID. A confidently decoded ordinary surface during the restricted window, or restricted surface after verified CLEAR, is FAIL.

The same run continuously checks permission/heartbeat/health, service-connection stability, fixture displacement/focus and twenty blocked input probes, then CLEAR, ordinary fixture focus/input restoration and exact stay-awake restoration. This tests whether capture interferes with the candidate and fixture, but that interference result is **UNSPECIFIED** until the physical calibration runs.

Raw media is never auto-deleted. PASS media is retained until strict minimized ingestion and owner review complete; FAIL/INVALID media remains until root-cause disposition is recorded. Deletion is an explicit owner action. Repository ingestion reads only minimized JSON and the frame journal; it never opens `raw-frames`.

## Payload hashes

| File | SHA-256 |
| --- | --- |
| `Start-KR003.ps1` | `f500d67d601aab7e4a8aa4810bae7d52f07af5d117c05a5758797c8972838e30` |
| `Clear-KR003-Lab.ps1` | `ad869e93c414931b91426a47aad657d93990c2fb7a7958942a60db07892313f9` |
| `Qualification.psm1` | `771bd32cf5d86beeb41d69b8fb6b2aa8d67b248abdd8c550c5cc6d1e790cae6f` |
| `DevicePreflight.psm1` | `e0d77b65b7d5ea3e8f26245247ba33fadcf985b11af43aa0b2d032375f5449d3` |
| `Capture-KR003-Frames.ps1` | `78e118368a940277f91925e8e6ab9db0f34fd77a559b2f4a9db4d63503e81d2c` |
| `VisualCalibration.psm1` | `bc68f0907fe6724e21de66a1209afb56f6b135f1bd4cf454287378b9e2afd5fb` |
| `protocol.md` | `e9fa5629ef472bc9fce3f2c8f0abe94730fb83192dbc547a87614b353be3cd26` |
| `candidate.apk` | `5b27c891fe155ee4d26e4da68f8323f178f7116e73d8097ce07199e5800e318b` |
| `ordinary-fixture.apk` | `223219c17a31439b52698e769bdf03ead0998bbbe8bbb5c1b0ff5be3cfaf21dc` |

## Validation and stopped state

Local checks passed 27 Node evidence/security tests, native Windows PowerShell 5.1 classifier/runner/entrypoint/capture-worker/bailout suites, repository validation, `git diff --check`, isolated Gradle debug/release unit tests, lint and assemblies, 24/24 audited JVM executions, merged-manifest checks and release DEX isolation. All nine mounted payloads match `bundle.json`. The actual mounted main entrypoint stopped before ADB/capture, and the mounted standalone CLEAR helper accepted this protocol then stopped at fake ADB; neither test contacted a device. [CI run 34482702876](https://github.com/felipebarbosa4/KidRemote/actions/runs/34482702876) passed Linux/PowerShell validation, native Windows PowerShell 5.1 and 7, and the Android build/lint/release-isolation job with the exact runner source.

No ADB or Samsung operation was performed during preparation, testing, packaging or mounted verification. Pre-publication artifacts `d303082`, `03f4bc2` and `5150e72` were successively rejected or superseded while the standalone bailout and PowerShell 7 test harness were tightened. Their runner payloads after `03f4bc2` are byte-identical to the final one, but none is recommended. All remain unmodified and must not be used. Only `0596173` is published.

## One future owner command

Do not run automatically. To perform this one short calibration once:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\platform-tools\kr003-visual-calibration-bundles\0596173\Start-KR003.ps1" -VisualCalibration
```

Before starting, keep the authorized tablet unlocked, interactive and on stable external power/ADB; leave Usage Access and the disposable Accessibility service enabled; close personal/sensitive surfaces; and ensure `C:\platform-tools` is owner-controlled and not cloud-synced. Then run the command and do not touch the tablet during the automatic ordinary → restricted → ordinary sequence. No network change or owner response is requested. Expected duration is approximately 2–4 minutes, depending on install/hash checks and screenshot cadence.

Press `Q` while the runner is active to request normal cleanup. If the main console is unusable, run `Clear-KR003-Lab.ps1` from this same bundle in a second PowerShell window; it clears only the disposable timer and preserves evidence. If an abnormal host termination leaves the bundle-started capture PowerShell process alive, close only that process after CLEAR and preserve all completed/partial files. Do not delete raw media until the retention condition above is met.

## Prospective qualification scope

A configuration-specific calibration PASS could justify a later, separately approved runner design replacing only human assertions of visible persistence/disappearance on these known calibrated ordinary/restricted surfaces, such as the ten-second visible portions of the normal and post-run checkpoints, and only with the independent fixture/input/focus oracle. It does not itself modify immutable runner-v12 or advance qualification.

It cannot establish Home-control exercisability, serialize a human observation, replace OD-39 Path A's physical Home action or Path B's physical control-unavailable observation, or replace Settings, Digital Wellbeing, recovery/re-entry, emergency/accessibility, keyguard/lock or other unresolved physical safety actions without separate calibration and owner approval.
