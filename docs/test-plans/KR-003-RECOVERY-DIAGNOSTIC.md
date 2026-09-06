# KR-003 focused Settings recovery diagnostic

- **Goal:** Isolate one MIUI Digital Wellbeing transition and one subsequent Settings recovery attempt without changing enforcement policy.
- **Context:** Q2 physically failed broad Settings/recovery on Mi 8; coarse telemetry showed ordinary reattachment and later recovery dispatches without a safe event.
- **Constraints:** One authorized Mi 8; owner-operated Windows ADB; no 100 samples, KR-004, allowlist change, raw identity, Accessibility content or destructive command.
- **Done when:** Four non-overlapping phases, three separate physical results, coarse software evidence and a verified lab-only bailout are preserved for review.

Protocol: **`KR003-Q3-RECOVERY-DIAGNOSTIC`**. This is a diagnostic-only bundle and cannot start qualification. It does not disable networking,
reset latency samples or alter permissions. It installs the same disposable candidate/fixture in place, runs one fresh expiry observation and then
executes only the labelled recovery case below. A completed command is evidence capture, not a successful feasibility gate.

## Phase contract

Every phase records a new `StartedUtc`, `StartedElapsed`, `AfterSequence` trace floor, `LastSequence`, end time, physical result where applicable,
and coarse oracle. Events at or before another phase's floor cannot satisfy the new phase. The runner exports only the existing typed classes and
transitions: no raw package/component, node, text, content, task history, screenshot, account, device serial or persistent identity hash.

| Phase | Operator action / physical result | Independent software evidence |
| --- | --- | --- |
| `SETTINGS_ROOT` | Tap the overlay button once; report top-level Settings usable as PASS/FAIL/INVALID | A post-dispatch SAFE transition plus removal, or a fresh post-dispatch SAFE/detached sample |
| `DIGITAL_WELLBEING_ATTEMPT` | Tap only Digital Wellbeing & parental controls once; report destination usable as PASS/FAIL/INVALID | Phase-local ordinary transition/reattachment, safe observation, unknown fail-open, or PENDING |
| `RECOVERY_BUTTON_ATTEMPT` | If the overlay exists, tap its Settings button once; report restored usable top-level Settings as PASS/FAIL/INVALID | A **new**, post-dispatch SAFE transition/removal or fresh post-dispatch SAFE/detached sample |
| `POST_RECOVERY_STATE` | No physical prompt | Two seconds of phase-local SAFE, ordinary-attached, unknown or PENDING final-state telemetry |

The root phase must physically pass to continue navigation. Digital Wellbeing FAIL is expected diagnostic evidence and does not stop the subsequent
recovery attempt. If no overlay is available after the destination attempt, recovery is recorded INVALID with reason
`OVERLAY_NOT_AVAILABLE_AFTER_DESTINATION`; the runner does not manufacture an unrelated block. Physical results and software oracles remain
separate even when they disagree.

## Physical classification

- **PASS:** the operator directly observed the exact requested surface usable/result achieved during that phase.
- **FAIL:** the operator directly observed blocking, unusability or failure of the exact requested recovery result.
- **INVALID:** the required observation was missed, ambiguous, interrupted, or its precondition (such as a visible recovery button) did not exist.

`DIAGNOSTIC_COMPLETED_ONLY` means journalling and cleanup completed. Its reason says whether physical PASS, FAIL or INVALID was recorded; it is not
product PASS, qualification, production approval or Play acceptance. One expiry observation remains separate and excluded from the 100 samples.

## Lab-only bailout

On every normal success/failure/interrupt path after debug control is ready, finalization invokes CLEAR before reporting. It verifies:

- timer/restriction is unarmed and the overlay is detached;
- the full latency sample array is byte-for-byte equivalent as serialized numeric values before and after CLEAR;
- no app data, uninstall, permission or network action occurred;
- the record explicitly says `ConsumerRecoveryEvidence=false`.

`diagnostic-bailout.json` preserves that result independently. A bailout failure makes finalization non-successful but never rewrites physical
observations. If the runner terminal is forcibly closed or the phone is trapped while waiting for input, the immutable bundle includes
`Clear-KR003-Lab.ps1`. It integrity-checks itself and the reply parser, invokes only SNAPSHOT/CLEAR, polls for release and verifies samples remain.
Neither automatic nor standalone CLEAR counts as consumer recovery success.

## Evidence output

The existing unique run directory contains the manifest/APK verification, prior metrics, one calibration expiry row, typed trace/telemetry,
`recovery-diagnostic.json`, `diagnostic-bailout.json`, summary files and final installed-APK/configuration checks where reached. Ingest with:

```sh
node tools/kr003/ingest.mjs diagnostic /mnt/c/platform-tools/kr003-qualification/ACTUAL_RUN_DIRECTORY
```

The ingester verifies protocol/mode, ordered non-overlapping phase floors, allowed physical values, software/physical separation, zero qualification
meaning and non-destructive bailout fields. Original run files remain immutable.

## Decision after evidence

The existing telemetry is sufficient for this checkpoint, so the short-lived equality diagnostic is **not implemented**. Exact destination
package/component, Android task-stack behaviour and cause of a no-event launch remain **UNSPECIFIED**. Review the Q3 evidence before designing any
enforcement/recovery repair. Do not add OEM allowlists, task flags, timing grace or further identity collection from this plan alone.
