# KR-003 excluded dual-Home diagnostic

- **Goal:** Determine whether OD-39 Path A or Path B is operational on the exact authorized Samsung configuration before spending another full qualification run.
- **Context:** The published runner-v12 qualification already defines the dual-path gate. This short diagnostic invokes the same implementation with a diagnostic-only manifest and produces no qualification evidence.
- **Constraints:** Exact configuration/APK/calibration binding; zero qualification and TIME-04 rows; no network isolation, navigation or credential change, candidate-generated Home, raw command output, content/package-history/account/serial capture, uninstall, clear-data, resume/pooling, historical reclassification, matrix PASS, production inference or automatic physical execution.
- **Done when:** Preconditions, one Home-key positive control, one excluded restriction, one Home path and complete reversible cleanup are retained with typed minimized evidence; uncertainty fails closed.

Protocol: **`KR003-DUAL-HOME-CALIBRATION-DIAGNOSTIC`**, runner-v12 Home logic, diagnostic-only.

## Binding and exclusion

The immutable bundle is bound to `samsung` / `SM-X400` / Android 16 / API 36 / build `BP4A.251205.006` / security patch `2026-07-05`, the passed runner-v5 calibration provenance, and the exact candidate/fixture hashes. Owner labels remain separate from captured metadata.

The manifest fixes `diagnosticOnly=true`, `diagnosticScope=HOME_GATE_ONLY`, `qualificationCycles=0`, `time04Rows=0`, `matrixContribution=NONE`, `resumeAllowed=false`, `poolingAllowed=false`, `requiresOffline=false`, and `networkIsolation=NOT_REQUIRED_AND_NOT_PERFORMED`. `attempts.json` must remain empty. A PASS is configuration-specific diagnostic evidence only; it cannot satisfy TIME-04, add a qualification row, alter a historical run or advance the matrix.

## Procedure

1. Verify the bundle, captured configuration, installed candidate and independent fixture hashes. Start from CLEAR. Independently verify Usage Access, Accessibility enabled state, fresh service heartbeat, healthy/eligible candidate, unlocked interactive state and stable external power. Read navigation mode only into coarse contextual metadata and do not change it.
2. Open the independent fixture and inject one fixture-coordinate shell tap. Require the same focused/resumed fixture and exactly one tap-count increment. Retain only the typed result.
3. With the restriction clear and that fixture focused/resumed, invoke the exact runner-v12 Home positive control: inject exactly one fixed `adb shell input keyevent KEYCODE_HOME`; require accepted transport, foreground/focus displacement, no tap increment, then return to and verify the same fixture instance/state. Rejection, no effect or failed return is INVALID and stops before ARM.
4. ARM one fresh disposable ten-second timer without resetting or qualifying existing metrics. Require restriction, attachment, `ORDINARY_APP`, healthy/eligible candidate and an unfocused independent fixture. The diagnostic record may retain its paired attachment latency, but it is not a row or TIME-04 sample.
5. Watch the visible restriction continuously for ten seconds. Then answer `A` if the current Home control/gesture is physically exercisable, `U` if it is unavailable while restriction is active, `I` if uncertain, or `Q` to stop. Navigation mode never supplies this answer.
6. Path A uses the exact runner-v12 physical-action prompt and hold oracle. The owner performs exactly one real Home action. Held restriction records `HOME_ACTION_EXERCISED_AND_RESISTED`; escape records `HOME_ACTION_EXERCISED_AND_ESCAPED`; uncertainty is INVALID.
7. Path B records `CONTROL_UNAVAILABLE`, invokes exactly one already-calibrated host `KEYCODE_HOME`, and uses the exact runner-v12 restricted-stimulus oracle. Restriction/attachment/health/ordinary-surface semantics must remain continuous, and the fixture must not regain focus or receive input. Owner-visible agreement records `HOME_ESCAPE_PATH_BLOCKED_WITH_CONTROL_UNAVAILABLE`, never physical resistance. Established escape is FAIL; any transport, state or owner uncertainty is INVALID.
8. In guarded cleanup, CLEAR the timer; require unarmed/unrestricted/unattached healthy candidate state; return to the focused/resumed fixture and prove ordinary input with one counter increment; then restore and verify the exact original stay-awake setting if changed. Do not uninstall or clear data. Network is read only as part of configuration drift checks and is never mutated.

## Verdicts

- **PASS:** `PASSED_DUAL_HOME_DIAGNOSTIC_THIS_CONFIGURATION_ONLY`, one Path A or Path B PASS, complete typed evidence, zero rows, verified CLEAR/fixture ordinary use/stay-awake restoration, no finalization error.
- **FAIL:** an established physical Home escape, ordinary-use return, restriction loss, fixture focus regain/input leak or failed physical restriction observation. The exact Home sub-result remains retained.
- **INVALID:** configuration/hash/permission/heartbeat/health/eligibility uncertainty; failed shell input precondition; rejected/no-effect/unreturned Home positive control; unknown control availability; rejected restricted stimulus; uncertain owner/oracle state; incomplete evidence; or unverified cleanup/restoration.

All results remain local, excluded and exact-configuration-only. A successful diagnostic can justify offering the owner one final fresh runner-v12 qualification attempt; it does not authorize or execute that attempt.
