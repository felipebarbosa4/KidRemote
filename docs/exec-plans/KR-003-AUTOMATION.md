# KR-003 qualification automation

- **Goal:** Ingest the completed Mi 8 checkpoint and prepare reproducible qualification with minimal operator work.
- **Context:** Fix `de941a9`; ten completed owner-observed cycles; Windows ADB is an owner-assisted execution boundary.
- **Constraints:** KR-003 only; no host changes or device execution from WSL; no invented physical passes; release controls/trace absent or no-op; no destructive execution.
- **Done when:** Evidence is ingested and published, qualification semantics reconciled, debug controls and runner tested, release isolation audited, remaining matrix work queued, and a single Windows command is ready.

## Execution

1. Validate mounted CSV and trace, preserve hashes/results and evidence limitations; commit/push.
2. Resolve the 100-sample contract from physical protocol, KR-003, ADR-0002, matrix and capacity definitions.
3. Implement debug-only lab control/metrics and a fail-closed qualification runner; test with synthetic failures and build both variants.
4. Package exact APK/source/runner/protocol hashes and prepare owner execution; no physical qualification is run in WSL.
5. Record the remaining automation/device/policy roadmap and synchronize KR-003 issue/Project without closing it.

## Current findings

The mounted observer CSV has exactly ten sequential unique cycles with all five recorded outcomes successful. The trace has only main/system
buffer headers, with an empty stderr file. This is a trace-collection gap whose cause is **UNSPECIFIED**, not evidence of absent attachment.
The next runner must verify direct telemetry availability before arming and preserve every failed/invalid attempt.

## Completed repository work

- Mounted checkpoint ingestion committed/pushed as `8786dc5`; the count is ten independent successful cycles, not fifty expiries.
- Qualification contract v1 resolves paired physical/timing observations, the existing ten-second persistence rule, failure/invalid handling and no pooling.
- ADR-0008 selects debug sender-protected controls plus an independent ordinary fixture; no enforcement decision or production permission was changed.
- Desktop checks passed: 22 JVM cases, 43 synthetic PowerShell assertions, three Node suites, both debug/release lint/builds and manifest/DEX isolation.
- Remaining matrix categorized and queued in [KR-003-REMAINING](../test-plans/KR-003-REMAINING.md); required API 28/35/36 hardware and policy evidence remain outstanding.
- Owner operation of the new debug telemetry/calibration and 100-sample run is the next boundary. No new device commands ran in WSL.
- Source `d81f19a` passed local and GitHub CI checks; [exact bundle/handoff](../test-plans/evidence/KR-003-BUNDLE-2026-09-06.md) is prepared in Windows storage.
- KR-003 issue/Project were synchronized and verified; draft PR #16 is open, not merged. KR-004 remains Backlog and untouched.

## Calibration incident follow-up — 2026-09-06

- **Goal:** Preserve the interrupted calibration, remove reporting/cleanup failure paths and correlate the recovery oracle with actual operator phases.
- **Context:** Latest owner run `run-20260906-025608-9dd0c8c7`: expiry PASS, Home/Settings owner PASS, post-P Settings oracle timeout, then empty-row StrictMode exception.
- **Constraints:** No physical execution, destructive actions, production enforcement change or KR-004. Original directories/bundles remain immutable. Android-side disagreement remains **UNSPECIFIED** until evidence establishes it.
- **Done when:** Incident/source hashes are documented; zero/partial/full finalization and correlated-phase tests pass; cleanup cannot mask the primary reason; a new immutable bundle passes exact-source CI and is ready for owner calibration only.

1. Read all existing run artefacts and preserve their hashes; distinguish missing summary/observer journal from missing physical success.
2. Test/fix finalization, independent network restoration and durable partial observer results.
3. Correlate recovery-phase polling/trace with revision and monotonic bounds; instrument only debug-owned overlay/recovery signals if needed.
4. Run complete desktop/build/release suites, commit/push, wait for exact-source CI, package and verify a new bundle. No physical run occurs here.

Incident ingestion and bounded fixes are implemented; [evidence](../test-plans/evidence/KR-003-CALIBRATION-2026-09-06.md) preserves originals and
the unresolved Android discrepancy. Q2 separates owner PASS from phase corroboration, includes debug-only owned-window diagnostics, guards
cleanup/reporting, and adds calibration-only mode. Local tests passed (23 JVM, 45 + 65 PowerShell assertions, six Node tests, debug/release lint/build
and manifest/DEX audits). Exact-source `37ad70b` subsequently passed all three CI jobs, including Windows PowerShell 5.1. The new
[immutable bundle](../test-plans/evidence/KR-003-Q2-BUNDLE-2026-09-06.md) was built and hash/source-byte verified; issue #3's evidence was updated
without changing acceptance checkboxes. The remaining boundary is owner-run calibration-only, not KR-004 or a completed physical/policy gate.

## Q2 physical recovery failure — 2026-09-06

- **Goal:** Preserve the completed Q2 physical FAIL and determine what the sanitized trace establishes before changing recovery policy.
- **Context:** Owner reports successful expiry/Home, selective MIUI Settings paths blocked, then the Settings recovery button unable to recover.
- **Constraints:** No new physical run, 100 samples, KR-004, guessed OEM allowlists or expanded identity collection. Originals immutable. Propose any additional diagnostic before implementing it.
- **Done when:** Runner/observer/software outcomes are separately recorded, trace and radio restoration correlated, established versus inferred causes stated, and the smallest bounded next diagnostic/fix is proposed.

1. Ingest the finalized `run-20260906-143058-1a877aa4` artefacts directly; hash original files and verify exact APK/source.
2. Correlate expiry, recovery dispatches, known-safe/ordinary/unknown transitions, window flags and final observer failure.
3. Compare actual policy/intent behaviour with official guidance; do not infer destination identities from UI labels or a boolean safe observation.
4. Update evidence/current gate and GitHub status; validate and publish documentation only. Physical confirmation of a future repair requires a fresh calibration-only run.

Ingestion confirms `FAIL:OBSERVER_4`, one successful calibration expiry, owner Home PASS and Settings/recovery FAIL, zero qualification rows,
no finalization errors and verified radio flags. [Q2 failure analysis](../test-plans/evidence/KR-003-Q2-SETTINGS-2026-09-06.md) separates the
established ordinary-classification/overlay chain from the unresolved destination/task cause. Proposed next work is labelled, bounded recovery
diagnostics with a lab bailout; no APK/policy/runner change or physical execution occurred in this investigation.

## Q3 focused diagnostic checkpoint

- **Goal:** Make one Digital Wellbeing/recovery reproduction phase-local, privacy-bounded and recoverable.
- **Context:** Q2's phase-wide latch could not attribute the final recovery attempt, while the existing coarse trace already distinguishes safe,
  ordinary and unknown dispositions without raw identity.
- **Constraints:** Diagnostic bundle only; no qualification path, Android policy/event change, identity equality capture, network change or KR-004.
- **Done when:** Four phase journals, three separate physical fields, automatic/standalone CLEAR verification, ingestion and negative tests pass;
  exact-source CI and immutable bundle are verified before owner execution.

Implemented `KR003-Q3-RECOVERY-DIAGNOSTIC`: each phase receives a fresh trace/time floor; Settings-button corroboration requires a post-dispatch
safe transition/removal or post-dispatch safe sample. Digital Wellbeing records ordinary reattachment, safe, unknown or pending independently.
Repeated button attempts invalidate that phase. Normal finalization clears only the disposable timer and verifies the entire latency sample array
is unchanged; the bundled standalone bailout covers a forcibly interrupted terminal. All physical failures remain evidence rather than retries.
The equality diagnostic remains unimplemented because existing coarse telemetry is sufficient for this checkpoint. Q3 physical execution subsequently
recorded expiry/root PASS, Digital Wellbeing/recovery FAIL, phase-local ORDINARY_APP reattachment and a verified bailout; see the
[preserved evidence](../test-plans/evidence/KR-003-Q3-RECOVERY-2026-09-06.md).
Exact source `53327c5` passed all three CI jobs; the [immutable bundle and operator handoff](../test-plans/evidence/KR-003-Q3-DIAGNOSTIC-BUNDLE-2026-09-06.md)
were independently hash/source-byte verified. No device action occurred during packaging.

## Q4 bounded recovery-launch calibration

Q3 established that the labelled destination is classified ORDINARY_APP and that NEW_TASK-only recovery can be transient or absent. The bounded
[Q4 decision/contract](../test-plans/KR-003-RECOVERY-REPAIR.md) adds only CLEAR_TOP to the Settings recovery intent; safe classification, event
collection and permissions remain unchanged. The runner enforces a ten-second minimum before recovery PASS and still rejects multiple dispatches.
Build/static evidence is not physical repair evidence; package and run Q4 only after exact-source CI passes.
Source `768aaa0` passed all three CI jobs. The [immutable Q4 bundle and operator handoff](../test-plans/evidence/KR-003-Q4-BUNDLE-2026-09-06.md)
were independently hash/source-byte verified. The owner then executed it: [Q4 evidence](../test-plans/evidence/KR-003-Q4-RECOVERY-2026-09-06.md)
records expiry/root PASS, expected Digital Wellbeing blocking and a single recovery physical FAIL. `CLEAR_TOP` reached Settings only transiently;
ordinary enforcement returned 681 ms after the safe transition. Zero qualification rows began and the lab bailout passed. This candidate is rejected.

## Q5 final flag-only task reset

- **Goal:** Test whether clearing the associated Settings task produces persistent root recovery after the exact Q4 failure route.
- **Context:** Q4 showed a fresh safe transition followed by `ORDINARY_APP` 681 ms later; `CLEAR_TOP` did not reset the retained route.
- **Constraints:** `ACTION_SETTINGS` with `NEW_TASK | CLEAR_TASK` only; no allowlist, identity/history collection, parallel task, qualification or KR-004.
- **Done when:** Pure intent/verdict/transition tests, Windows runner tests, debug/release isolation, build/validation, immutable hashes and exact-source CI pass; then one owner-operated calibration determines the physical result.

The [Q5 contract](../test-plans/KR-003-RECOVERY-TASK-RESET.md) treats this as the last flag-only candidate. The runner now explicitly records
safe-then-ordinary reattachment as a regression rather than leaving the safe-transition label latched. Source `97173d2` passed all three CI jobs;
the [immutable bundle and owner handoff](../test-plans/evidence/KR-003-Q5-BUNDLE-2026-09-06.md) were independently hash/source-byte verified.
Physical execution remains **Not run**.
