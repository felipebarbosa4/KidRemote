# KR-003 Q6 Mi 8 offline qualification

> **Superseded before execution:** Q6 was never physically run. Owner decision OD-29 replaces its 100 repetitive human prompts with the independently calibrated Q7 active-oracle contract. Preserve this file and immutable bundle as historical planning evidence; do not execute it.

- **Goal:** Execute the existing 100-sample physical expiry contract on the authorized Mi 8 while offline, using the exact APK pair that passed Q5 recovery calibration.
- **Context:** The ten-cycle stability checkpoint passed, Q2/Q3/Q4 exposed recovery defects, and [Q5](evidence/KR-003-Q5-RECOVERY-2026-09-06.md) physically passed the final bounded recovery route once. Q5 contains zero qualification samples.
- **Constraints:** Owner-operated Windows ADB; exact device/build/APKs; 100 new independent samples; no destructive action, input injection, raw identity, production implementation, result pooling or resume.
- **Done when:** Fresh calibration and both safety checkpoints pass, exactly 100 new observer-confirmed persistent expiries have paired monotonic measurements, p95 is at most 2,000 ms, offline state and restoration are verified, and all evidence finalizes without error.

Protocol: **`KR003-Q6-MI8-OFFLINE-QUALIFICATION`**, runner version 6. This specializes, but does not weaken, the [qualification contract](KR-003-QUALIFICATION.md) and [physical protocol](KR-003-PHYSICAL.md).

## Fixed candidate

| Item | Required value |
| --- | --- |
| Device | Xiaomi Mi 8, codename `dipper` |
| OS | MIUI Global 12.0.3, Android 10 / API 29 |
| Candidate APK SHA-256 | `5b27c891fe155ee4d26e4da68f8323f178f7116e73d8097ce07199e5800e318b` |
| Ordinary fixture SHA-256 | `6653f10b527cc9a273a8c0ea045cd250f6978c1acfb8e92b00b701f6c14f84bb` |
| Q5 calibration source | `97173d207c8076219c6c4c8d780db43d8f9fc566` |
| Q5 evidence run | `run-20260906-171929-69a3abda` |

Packaging fails if rebuilt APK bytes differ. Installation uses `adb install -r`; no uninstall or data clear fallback exists. Installed base APKs are pulled and hash-verified before and after the run.

## One run, in order

1. Create an exclusive timestamped evidence directory and verify bundle integrity, the authorized configuration, required permissions/service health and both installed APKs.
2. Record original Wi-Fi/mobile-data flags, disable any enabled radio, verify both flags are off, and obtain a separate physical confirmation that no other Internet route exists. `-OfflineNetwork` is mandatory.
3. Reset only debug timing samples. Run one fresh 10-second calibration expiry with a ten-second continuous physical restriction observation.
4. Run the **calibration safety checkpoint** defined below. Calibration and safety observations contribute zero qualification samples.
5. Reset only debug timing samples again and verify count zero.
6. Run attempts 1–100. Every attempt clears only the lab timer, foregrounds the disposable ordinary fixture, creates a fresh revision, waits through expiry, pairs the revision to one internal attachment measurement, continuously checks software invariants for at least ten seconds, and then requires one physical P/F/I/Q response.
7. Run the same **final safety checkpoint** after sample 100.
8. Verify the final internal sample array exactly equals the 100 row measurements, compute nearest-rank p50/p95/max, re-check configuration/APK bytes, perform a sample-preserving lab CLEAR, restore changed radios independently, and write machine-readable plus Markdown summaries.

## Safety checkpoint contract

Each checkpoint begins from the still-active restriction produced by calibration or sample 100 and records `IndependentExpirySamples=0`.

1. **Home:** owner presses Home physically once. PASS requires the restriction to remain continuously visible and Home/ordinary use to remain unavailable; software restriction/fixture invariants must also hold.
2. **Settings root:** owner uses the overlay button once. Top-level Settings must be physically usable and a phase-local known-safe transition must be corroborated.
3. **Digital Wellbeing:** owner attempts that labelled destination once. On this exact candidate, expected physical result is blocked/restriction returned, corroborated as ordinary-app reattachment. This is a deliberate regression precondition, not a safe destination.
4. **Recovery button:** owner uses the overlay button exactly once. PASS is disabled until a new phase-local safe transition has remained `SAFE_SYSTEM`/detached for at least ten seconds with no later ordinary reattachment; the owner must separately observe usable Settings for that interval.
5. **Ordinary re-entry:** runner opens the disposable ordinary fixture. Owner confirms persistent restriction; software restriction and fixture counters must agree.
6. **Clear:** debug CLEAR releases only the disposable timer. The owner taps the fixture once and its independent counter must increment exactly once. Timing samples must remain byte-for-byte equivalent.

The checkpoint result is FAIL or INVALID if its physical or software components disagree. An earlier phase's safe event cannot satisfy a later phase. These checks do not satisfy every SAFE/TAMP matrix row and do not add expiry samples.

## Sample semantics and stopping

One sample is exactly one fresh persisted revision with eligible interactive/unlocked ordinary-fixture use through mathematical zero, one paired internal attachment measurement, at least ten seconds of continuously held software restriction, and one observer PASS after visibly continuous blocking without flicker, disappearance or ordinary use.

- Attachment, trace, Home, Settings, re-entry and clear events are never promoted to physical expiry passes.
- The calibration row is retained but excluded. The two safety checkpoints each add zero samples.
- Any physical FAIL, software enforcement failure, physical INVALID, eligibility loss, trace gap, stale heartbeat, configuration change, operator stop or host error stops the run. The current row and every prior row remain; no replacement is appended.
- A failed, invalid or interrupted run cannot resume or pool with another run. A new execution starts again at calibration and sample 1 in a new directory.
- A slow valid sample remains. Nearest-rank p95 above 2,000 ms returns `FAILED_P95` after all 100.
- Exit zero requires `PASSED_THIS_CONFIGURATION_ONLY`, offline confirmation, both safety checkpoints, verified sample-preserving bailout, verified radio restoration and no finalization error.

## Operator workload

The runner asks for:

- one offline confirmation;
- one key after calibration expiry;
- Home, Settings root, Digital Wellbeing and recovery actions plus short P/F/I responses during each of two safety checkpoints;
- one ordinary re-entry response and one real fixture tap during each safety checkpoint;
- one key after each of 100 expiry holds.

For the expected Q5 route, the safety response sequence is Home **P**, Settings root **P**, Digital Wellbeing **F**, recovery **P**, ordinary re-entry **P**, followed by one fixture tap after CLEAR. An unexpected usable Digital Wellbeing destination is not silently accepted because it changes the calibrated route and must be reviewed.

Expected uninterrupted duration is approximately **40–60 minutes**. The runner polls and journals continuously; the owner must keep the screen interactive/unlocked and watch every expiry. P cannot be inferred or auto-entered.

## Outputs and recovery

The run directory contains manifest and bundle identity, verified APK copies, prior/final metrics, `attempts.json`/CSV, sanitized telemetry and typed trace JSONL, fixture snapshots, `safety-calibration.json`, `recovery-calibration.json`, `safety-final.json`, `recovery-final.json`, network journals, sample-preserving bailout evidence, `summary.json` and `SUMMARY.md`. No node content, text, raw package/component, screenshot, account, serial or app-history timeline is collected.

Normal finalization runs lab CLEAR and radio restoration in independently guarded steps; neither can mask the primary result. A hard host/power loss cannot guarantee cleanup. The bundled `Clear-KR003-Lab.ps1` is the emergency non-destructive timer-only bailout and does not alter app data, installation, permissions or network.

## Interpretation boundary

A passing Q6 result establishes only the 100-expiry/offline timing and repeated bounded safety route for this exact Mi 8 configuration/APK. It does not close KR-003, establish other APIs/OEMs/users, satisfy remaining lifecycle/tamper/safety rows, prove production readiness, or constitute Google Play acceptance.
