# KR-003 Q7 active-oracle Mi 8 qualification

Status, 2026-09-08: **BLOCKED before sample 1 on the unchanged Mi 8 configuration**. [All three bounded input transports were denied](evidence/KR-003-MONKEY-DENIAL-2026-09-07.md).
The independent oracle prerequisite is unsatisfied; the per-cycle visual fallback conflicts with the maximum-three-human constraint.
Do not run Q7 on the unchanged configuration. OD-31's separate generic path subsequently produced a Samsung transport PASS and
[configuration-specific calibration PASS](evidence/KR-003-SAMSUNG-ORACLE-CALIBRATION-PASS-2026-09-08.md). Its separate runner-v8 qualification
attempt stopped INVALID in network preflight with zero cycles; runner-v9 corrected that capability assumption. Its next Samsung execution retained
100 automated PASS rows but stopped `INVALID:SCREEN_OR_KEYGUARD` before checkpoint-3 owner agreement. Runner-v10 adds reversible verified Stay
awake while plugged in orchestration. Its later Samsung execution retained another 100 automated PASS rows but emitted an automated
`FAIL:RESTRICTION_LOST` during the Home prompt after an out-of-sequence overlay Settings action; Home remained unrecorded and restriction stayed
true on an allowed safe surface. Runner-v11 made the current button/gesture Home action explicit and fail-closed. Two later runner-v11 attempts
show that a coarse `THREE_BUTTON` mode does not establish control availability under the overlay: one stopped on an unrelated ADB rejection before
the Home prompt, and one retained no exercisable Home control/action. OD-39 prospectively approves runner-v12's dual-path Home gate; it does not
reclassify either run. All stopped attempts remain
non-resumable. Q7 and its Mi 8 evidence stay
historical/configuration-specific, and the evidence contract below is not weakened.

- **Goal:** Measure 100 offline expiry cycles without 100 repetitive human confirmations while retaining an independently calibrated enforcement oracle.
- **Context:** Q6 was packaged but not run. The owner limits this redesign to at most three human checkpoint sessions and does not authorize silently weakening the evidence gate.
- **Constraints:** Exact Mi 8 configuration; owner-operated Windows ADB; no screenshot, UI-node/content inspection, raw package/window history, destructive action, permission mutation, result pooling or production implementation.
- **Done when:** The active oracle is physically calibrated, exactly 100 unattended cycles pass it, three strategically different human checkpoints pass, p95 is at most 2,000 ms, and cleanup/restoration evidence is complete.

Protocol: **`KR003-Q7-MI8-ACTIVE-ORACLE-QUALIFICATION`**, runner version 7. Q7 supersedes unexecuted Q6 for this owner constraint. It changes the evidence model, not the enforcement candidate.

Physical status: three owner executions on 2026-09-06 stopped during attempt 0 before ARM with `INVALID:ADB_REJECTED`. Evidence localizes the
rejected fixed operation to the unblocked fixture's `adb shell input tap`; zero Q7 samples and zero human checkpoints began. See the
[preserved INVALID evidence](evidence/KR-003-Q7-PREFLIGHT-INVALID-2026-09-06.md). The later standalone
[oracle-transport preflight](KR-003-Q7-ORACLE-TRANSPORT-PREFLIGHT.md) classified the shell denial; it did not resolve the transport gate.

Subsequent [transport/configuration evidence](evidence/KR-003-MI8-INPUT-DENIAL-2026-09-06.md) confirms INPUT_TAP exit 1 / SECURITY_EXCEPTION and the
disabled, SIM-gated input-security switch. Separate [UiAutomation](evidence/KR-003-UIAUTOMATION-DENIAL-2026-09-06.md) and
[bounded Monkey](evidence/KR-003-MONKEY-DENIAL-2026-09-07.md) preflights subsequently returned `SECURITY_EXCEPTION` with zero fixture taps.
Together these results block Q7 on the unchanged Mi 8 and supply zero qualification samples.

## Evidence-contract change

Q7 deliberately does **not** claim 100 human-visible observations. It replaces that operational requirement with:

- 100 independently paired latency cycles;
- 100 active input/focus oracle results;
- two human-visible expiry observations, one before and one after the unattended set;
- one human-visible controlled-unblocked negative control;
- a guided final Home/Settings/recovery/re-entry safety route.

A successful run is named `PASSED_AUTOMATED_ORACLE_WITH_THREE_PHYSICAL_CHECKPOINTS_THIS_CONFIGURATION_ONLY`. It must never be relabelled as the historical `100 observer-confirmed expiries` result. This owner-approved evidence change reduces repeated visual sampling and leaves short, rendering-only anomalies outside automated proof. Those residual risks are explicit below.

## Independent active oracle

The disposable ordinary fixture has no Accessibility service, shared UID, candidate storage, network permission or candidate callback. Its debug receiver is sender-protected by `android.permission.DUMP` and absent from release. It exposes only:

- process instance;
- current resumed/focus booleans;
- monotonic focus-gain/loss counters and last-change time;
- a synthetic interaction counter;
- one transient numeric coordinate for its own bottom-screen test button.

No node, text, content, screenshot, package/component, task history, account, device serial or real application activity is exposed.

For every cycle, the Windows runner:

1. clears only the lab timer, foregrounds the fixture and requires resumed + focused state;
2. injects a real `adb shell input tap` at the fixture-owned coordinate and requires exactly one counter increment — the per-cycle positive control;
3. arms a fresh revision and waits for zero/attachment;
4. establishes a post-attachment fixture baseline;
5. injects 20 real input-layer taps at 500 ms intervals across at least ten seconds;
6. requires zero fixture counter increments, zero fixture focus gains, unchanged fixture process/coordinate, and a still-resumed underlying fixture;
7. simultaneously rejects revision change, service reconnect/process trace reset, permission/configuration change, stale heartbeat, eligibility loss, overlay removal, non-applied adapter state or latency mismatch.

The fixture counter and focus callbacks are independent of the candidate's Accessibility classification/enforcement decision. Candidate telemetry corroborates timing/revision/adapter state but cannot create an active-oracle PASS by itself. A block that never appears is detected by the fixture remaining interactive and by the attachment timeout. Structural disappearance or flicker is detected by fixture focus regain/input delivery and corroborating removal transitions. The per-cycle positive control detects a broken input command, stale coordinate or non-responsive fixture.

## Three human checkpoint sessions

1. **Preflight normal PASS:** the active oracle runs on an excluded fresh expiry. The owner watches the complete ten-second restricted hold and confirms continuous visible blocking with no flicker or ordinary use.
2. **Preflight controlled negative:** the runner deliberately clears only that disposable restriction and injects the same real tap. Automation requires the fixture counter to increment; the owner confirms the overlay is absent and ordinary fixture feedback is visible. This is an excluded negative control, not a consumer recovery claim or qualification sample.
3. **Post-run safety/agreement:** after unattended sample 100 remains restricted, the owner validates visible persistence. Navigation mode is only coarse context. The runner asks whether Home is physically exercisable without performing it. If available, the owner exercises that real action once and physical plus independent hold evidence must show no ordinary-use escape. If unavailable, the owner's absence observation is combined with one host `KEYCODE_HOME` whose transport was separately proven against the unblocked fixture, plus continuous candidate state, no fixture focus/input regain, and a second owner visible-result observation. The unavailable-control success is distinctly named and never reported as physical Home resistance. Unknown stops INVALID. The separately prompted root Settings, expected Digital Wellbeing block, one-button persistent Settings recovery, ordinary re-entry and automated CLEAR follow only after either Home path passes. The overlay Settings button must not be used during Home phases. This remains one checkpoint session with separately journalled substeps.

Any non-PASS checkpoint stops the run. The two preflight checkpoints occur before metrics are reset for the 100 rows. The final safety checkpoint adds no latency sample.

## What automation can and cannot prove

The active oracle can detect:

- no attachment/no block;
- overlay removal/structural flicker that returns input focus;
- input reaching the underlying ordinary fixture;
- broken injection/counter/focus instrumentation;
- stale/wrong revision or metric pairing;
- candidate trace/process replacement or service reconnect;
- permission, eligibility, heartbeat or tracked configuration changes.

It cannot independently prove text readability, exact rendered pixels, visual occlusion by an unrelated non-interactive surface, or a sub-sampling rendering-only flash that neither changes focus nor leaks input. Screenshots and UI-node inspection are prohibited. The two visible expiry checkpoints and earlier 10/10 Mi 8 observations reduce but do not eliminate that residual risk. If the Mi 8 preflight cannot demonstrate real input delivery after CLEAR and denial while blocked, the runner stops before sample 1 and Q7 is invalid: the 100-human Q6 contract then remains incompatible with the three-checkpoint owner constraint pending explicit go/no-go/product resolution.

## Run and stopping rules

- Use the exact bundled candidate and Q7 fixture hashes; installation is `adb install -r` only.
- Mandatory offline setup journals and restores Wi-Fi/mobile flags independently.
- Attempts 1–100 are unattended. Each is a fresh revision; no failed/invalid row is replaced.
- Any fixture tap during restriction, focus regain, process replacement, overlay removal, stale state, permission/configuration change, missing input control or host error stops immediately and preserves the current row.
- No resume or pooling. A stopped run restarts from preflight in a new directory.
- Nearest-rank p95 above 2,000 ms is a failure after all 100 rows.
- Final success requires exactly 100 active-oracle rows, all three human checkpoints, final safety, sample-preserving CLEAR, exact aggregate agreement, verified radio restoration and no finalization errors.

Estimated unattended portion: approximately **35–45 minutes**. Human work is limited to the three checkpoint sessions; there is no P prompt for attempts 1–100.

## Interpretation boundary

Passing Q7 establishes an engineering feasibility result only for this exact Mi 8/candidate/fixture/configuration under the revised evidence model. It does not prove 100 human-visible outcomes, every possible transient visual defect, other Android/OEM versions, remaining lifecycle/tamper/safe-surface rows, production readiness or Google Play acceptance. KR-003 remains open until its other gates and owner go/no-go are resolved.
