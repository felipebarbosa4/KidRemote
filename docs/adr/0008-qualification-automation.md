# ADR-0008 — Debug qualification controls and observation oracle

Status: Accepted for the KR-003 disposable lab, 2026-09-06. Q1 controls operated on Mi 8; Q2/Q3 physically failed Settings/recovery, and Q4
physically rejected `NEW_TASK | CLEAR_TOP`. Q5 physically passed its focused `NEW_TASK | CLEAR_TASK` route. The 100-sample, broader safety/device,
lifecycle and external policy gates remain open.

- **Goal:** Remove repetitive lab interaction while preserving independent physical evidence and release isolation.
- **Context:** Ten Mi 8 cycles passed by owner observation; the captured log had only buffer headers. Persisted metric count was not transcribed.
- **Constraints:** Debug/test only; no content/node/text/screenshot/gesture collection; no host changes; Windows ADB is owner-operated.
- **Done when:** Controls, metrics, runner and safety checks are reproducible; physical PASS remains an explicit observer response.

## Alternatives evaluated

1. Manual controls and logcat: existing flow works but repeats five strings per cycle and the empty trace failed to export metrics.
2. A debug receiver with a protected sender permission and typed ordered result: chosen for window-free clear/arm and direct state/metric export.
3. Instrumenting the target app with `am instrument` per cycle: can change target lifecycle; unsuitable as the timer/enforcement control path.
4. `dumpsys window`/activity: independent OS evidence, but outputs can contain titles/packages and are OEM-dependent; window presence/focus cannot
   prove continuous visual restriction or touch blocking. Do not save broad dumps. This is not a substitute for observer evidence.
5. UIAutomator/external input: useful for conventional UI tests but node/text collection is outside this task, and MIUI already rejected shell Home
   injection. No bypass of that restriction and no dependency on injection for qualification.
6. A separate ordinary fixture: selected to give a stable explicit launch target, a synthetic touch counter and independent focus signal. It has
   no permissions, no Accessibility capability and no shared UID/state with enforcement. Its own state query is sender-protected and debug-only.

## Decision and reasons

Use Android debug source sets for `LabControlReceiver`, bounded typed state/trace memory and `EnforcementTrace` telemetry; release trace/probe are
no-ops and the receiver/manifest entry are absent. Protect exported debug receivers with `android.permission.DUMP` as a **sender requirement**;
neither APK requests this permission. AOSP declares it signature/privileged/development and the shell requests it. Ordinary apps cannot normally
send these controls. Confirm actual availability during preflight; OEM refusal is a tooling boundary, not permission to relax protection.
[Receiver permission](https://developer.android.com/guide/topics/manifest/receiver-element#prmsn),
[AOSP permission definition](https://android.googlesource.com/platform/frameworks/base/+/refs/heads/main/core/res/AndroidManifest.xml),
[AOSP shell manifest](https://android.googlesource.com/platform/frameworks/base/+/refs/heads/main/packages/Shell/AndroidManifest.xml).

The receiver allows only fixed lab operations and returns sanitized typed JSON in ordered broadcast result data. It performs no navigation or
policy enforcement itself. API behaviour: [BroadcastReceiver result data](https://developer.android.com/reference/android/content/BroadcastReceiver#setResultData(java.lang.String)),
[ADB activity-manager commands](https://developer.android.com/tools/adb), [source-set isolation](https://developer.android.com/build/build-variants).

## Security/privacy implications

No free-form data is echoed, no account/device serial/package history is collected, and no raw shell output is evidence. The runner reads only the
two known lab APK paths and typed debug responses. A bounded ring tracks coarse transitions and no content. A query cannot choose an arbitrary
file, command, package, time grant or URL. On-device controls remain unavailable to ordinary apps; release artefact auditing checks both manifest
and DEX for debug controls. Authorized ADB can control the debug lab; it is already outside the consumer tamper guarantee.

## Operational implications

One human key per observed expiry remains necessary under the physical protocol. Automation polls exported technical state and retains every
attempt. Fixture focus/touch are independent corroboration, not proof of continuous visible restriction. A new build/fixture requires calibration.
No background logcat process or Windows interop repair is needed. No new library/SDK is needed by the Android lab.

## Risks and tests that invalidate the decision

Invalidate or revise if OEM broadcast results are unavailable, ordinary apps can call controls, debug classes leak into release, queries perturb
surface/clock behaviour, ring overflow/stale telemetry is accepted, or any fixture/attachment signal is promoted into a physical pass. Regression
tests inject missing data, duplicate revisions, clock regressions, delayed attachment, permission loss, and false observer classifications.

Official API sources above and [dumpsys](https://developer.android.com/tools/dumpsys),
[UIAutomator](https://developer.android.com/training/testing/other-components/ui-automator),
[Activity focus](https://developer.android.com/reference/android/app/Activity#onWindowFocusChanged(boolean)) checked 2026-09-06.

## Q2 incident reconciliation — recovery oracle and finalization

- **Goal:** Preserve observer evidence independently of a software oracle and make failed calibration safely reportable.
- **Context:** [d81f19a incident](../test-plans/evidence/KR-003-CALIBRATION-2026-09-06.md): physical Settings PASS, twenty fresh ordinary/attached samples,
  no safe transition in the captured journal, then StrictMode failure on empty-array member enumeration.
- **Constraints:** No enforcement/allowlist change, speculative Android root cause, timeout inflation, new permissions or substitution for observation.
- **Done when:** Real runner finalization and phase-correlation regressions pass; exact-source CI and release audit pass; owner calibration corroborates
  recovery or preserves a precisely classified disagreement. Repository checks alone cannot complete the last condition.

Alternatives evaluated:

1. Increase the post-P timeout: rejected; existing samples were fresh and no delayed safe event is established.
2. Drop the oracle or automatically trust attachment/focus: rejected; this would conceal contradictory state and weaken evidence integrity.
3. Require SAFE_SYSTEM at the exact later P query: rejected as the sole temporal definition. A recovery action happens during an operator phase;
   subsequent navigation can legitimately change the current surface. That possibility is not claimed as the root cause of this run.
4. Correlate during-phase samples and trace with revision/time/sequence and actual Settings-button dispatch: selected. Retain independent physical
   response and all contradictory signals. Uncorroborated recovery is INVALID pending investigation, never a fabricated physical FAIL or PASS.

Decision/reasons: use Q2 phase polling and typed button request/dispatch diagnostics; add only the owned overlay View's window-visibility, focus
and framework-attachment flags to debug telemetry. Existing `attached` means the adapter holds an overlay reference; it does not independently prove
that the window is currently visible. The new fields help distinguish those cases without changing that field's meaning or enforcement behaviour.
[View window visibility](https://developer.android.com/reference/android/view/View#getWindowVisibility()),
[focus](https://developer.android.com/reference/android/view/View#hasWindowFocus()),
[attachment](https://developer.android.com/reference/android/view/View#isAttachedToWindow()), checked 2026-09-06.

Security/privacy: read only the View created by this spike; no system window enumeration, Accessibility nodes/content, other-app identifiers,
screenshots or additional permissions. Release sampling remains no-op; source and merged-manifest/DEX audits enforce debug isolation. Fixed enum/
boolean/numeric schemas reject unexpected diagnostic data. No new libraries or SDK versions are introduced.

Operations: save P/F/I/Q before corroboration; retain calibration and partial rows; statistics enumerate rows explicitly so empty arrays are safe.
Guard each radio recovery/readback and report independently; never replace the primary reason with a reporting exception. Summary fallback cannot
guarantee unavailable storage or hard-kill recovery. Add native Windows PowerShell CI coverage in addition to Linux synthetic checks; GitHub's
[explicit PowerShell shell](https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax#jobsjob_idstepsshell) was reviewed
2026-09-06. Next owner execution is calibration-only, with review before a separate 100-sample run.

Risks/tests that invalidate: unrelated/pre-dispatch safe events satisfy recovery; fresh samples mask stale disposition; phase queries perturb the
window; owner PASS is lost on an oracle timeout; zero/partial rows or reporting failures skip recovery; a radio error skips the other radio;
debug diagnostics leak into release. Tests cover phase ordering/stale evidence/revision changes, five requested row-count paths and fault injection.
The actual Android discrepancy remains **UNSPECIFIED** until new evidence establishes it; the original own-package fix is not changed.

## Q2 physical failure follow-up — Q3 diagnostic checkpoint

- **Goal:** Isolate the blocked Settings destination and recovery attempt without collecting an app history or guessing a safe set.
- **Context:** [Q2 evidence](../test-plans/evidence/KR-003-Q2-SETTINGS-2026-09-06.md) records physical Home PASS, Settings FAIL, ten known-safe-to-ordinary
  transitions and four final Settings launch-call returns without a new window event. The old phase latch remains true from earlier safe access.
- **Constraints:** Existing SAFE requirement stays intact; no new runtime permission, node/content access, task clearing, production grace period,
  guessed vendor packages or new physical run during analysis.
- **Done when:** Diagnostics distinguish per-path and per-button outcomes; any further collection is reviewed before implementation;
  the lab-only bailout is verified; a justified repair passes fresh physical calibration. Q3 ran and met the diagnostic/bailout conditions; repair verification remains open.

Alternatives: a blanket OEM/system-package exemption is rejected because provenance alone does not make every destination safe. Extending timeout
is not justified by four returned launches plus 37 seconds of unchanged state after the last one. Reverting OWN_PACKAGE preservation would
reintroduce the established flicker bug. Raw package/task-history logging exceeds the lab privacy contract. A labelled, one-destination diagnostic
using existing telemetry is the smallest first step; only if still necessary consider the evidence note's case-local equality flags, not raw names.

Decision: **keep the current candidate ineligible for qualification; implement runner-only phase/attempt correlation and verified debug-CLEAR lab
bailout before another controlled reproduction.** Q3 now has four cursor/time-isolated phases and separate physical fields. A per-attempt result
cannot inherit an earlier button's safe latch. No Android enforcement policy, event collection or equality diagnostic changed. Existing Q2
`Oracle=CORROBORATED` remains valid only as historical phase-existence evidence, not physical success.

Security/privacy: no broader collection is needed for the already established ORDINARY_APP classification chain. Any proposed equality slot is
debug-only, short-lived, non-exporting for identities and isolated by explicit case; no stable hash or timeline. Exact OEM identity/OS-level task
inspection needs a separate narrowly specified review if it becomes indispensable. Release remains absent/no-op; no permissions changed.

Operations/reasons: record Settings root, named path usability, return-to-Settings and software evidence separately; preserve all failures and pre-bailout
state. The debug-only automatic/standalone CLEAR verifies release and unchanged latency samples; it is **not** consumer recovery evidence. After diagnosis/repair, repeat calibration-only and all newly failed
Settings regressions before the unchanged broader stability/qualification gates. Do not claim another APK or physical run exists.

Risks/invalidation: a case label cannot precisely timestamp a gesture unless the phase boundary is recorded; package equality is not task identity;
no-event launch failures may need a different approved oracle. Reject any design that automatically promotes a safe transition into broad Settings
PASS, makes arbitrary external apps permanently safe, or again traps the user. Exact OEM/task cause remains **UNSPECIFIED**.

### Q3 physical result

[Q3 evidence](../test-plans/evidence/KR-003-Q3-RECOVERY-2026-09-06.md) records expiry PASS, top-level Settings PASS, a labelled Digital Wellbeing
FAIL corroborated by ORDINARY_APP reattachment, and recovery FAIL. The first of two phase-local recovery dispatches was safe for only 682 ms before
ordinary enforcement returned; the second produced no safe event. Two click-handler activations invalidate the single-attempt software oracle but
do not erase the physical FAIL. Existing coarse telemetry answered the disposition question, so no equality diagnostic or raw identity is justified.

## Q4 bounded recovery-launch decision

Alternatives: expanding the safe allowlist is rejected without verified identity/surface safety; a time grace period is rejected because it can
expose ordinary use; `CLEAR_TASK`/`MULTIPLE_TASK` are unnecessarily broad; collecting task/package history is rejected. Keep ACTION_SETTINGS and
add only `FLAG_ACTIVITY_CLEAR_TOP` alongside `FLAG_ACTIVITY_NEW_TASK`. Android documents this pair as locating an existing activity in another
task and putting it in position to handle the intent, clearing activities above the target where applicable.
[Official task guidance](https://developer.android.com/guide/components/activities/tasks-and-back-stack#IntentFlags), reviewed 2026-09-06.

Decision/reasons: use this only as a bounded candidate repair because Q3 directly observed NEW_TASK restoring a safe Settings surface transiently
before the ordinary destination returned. It changes task navigation, not surface classification. Security/privacy and release collection remain
unchanged. Operational risk is loss of in-progress Settings navigation above the root when the user explicitly requests recovery. Physical Q4
must prove one click restores a continuously usable root without reattachment; failure rejects this repair. Other OEM/API and safety gates remain.

### Q4 physical result

[Q4 evidence](../test-plans/evidence/KR-003-Q4-RECOVERY-2026-09-06.md) records expiry/root PASS, expected Digital Wellbeing blocking and a
single recovery-button physical FAIL. The dispatch reached `KNOWN_SAFE_SYSTEM` after 148 ms and removed the overlay, but `ORDINARY_APP` returned
681 ms later and the overlay reattached 37 ms after that. This matches the owner's approximately one-second Settings flash. The post phase stayed
ordinary/restricted/attached until the verified sample-preserving lab CLEAR.

Decision consequence: reject `NEW_TASK | CLEAR_TOP` for this Mi 8 route. The fresh safe-transition oracle is transition corroboration only; it
cannot satisfy persistent recovery in the presence of a later ordinary transition or physical FAIL. Exact MIUI activity/task behaviour remains
**UNSPECIFIED**. Do not add an OEM allowlist, timing grace, raw identity collection or start qualification from this result.

## Q5 final flag-only task-reset decision

Q4 establishes that locating/clearing above the existing Settings target is insufficient. Android documents `NEW_TASK | CLEAR_TASK` as clearing
the associated task before launch and making the launched activity its new root. Select that pair with the unchanged `ACTION_SETTINGS` as one
final bounded flag-only candidate. `CLEAR_TOP` and `MULTIPLE_TASK` are absent. The full alternatives, operational trade-off and invalidation tests
are in [the Q5 contract](../test-plans/KR-003-RECOVERY-TASK-RESET.md).

Security/privacy: no policy, permission, event, raw identity, node/content, screenshot, task-history log or network change. Operationally, the
explicit recovery action can abandon in-progress Settings navigation, but does not deliberately clear persisted application data or system
settings. Physical success was established only for the exact focused Mi 8 route; broader behaviour remains **UNSPECIFIED**.

The phase reducer must now downgrade a latched safe transition to `RECOVERY_REGRESSED_TO_ORDINARY` when a later ordinary transition and overlay
reattachment occur. A pure verdict treats Digital Wellbeing blocking as the expected precondition, while requiring persistent physical and
software recovery plus a safe post-state. If Q5 fails, stop flag iteration and return the consumer recovery architecture to go/no-go review.
[Intent flag API](https://developer.android.com/reference/android/content/Intent#FLAG_ACTIVITY_CLEAR_TASK), reviewed 2026-09-06.

### Q5 physical result

[Q5 evidence](../test-plans/evidence/KR-003-Q5-RECOVERY-2026-09-06.md) records one expiry PASS, root Settings PASS, expected Digital Wellbeing
blocking, and a single recovery-button PASS. The task-reset dispatch reached `KNOWN_SAFE_SYSTEM` after 180 ms, removed the overlay and had no
later ordinary transition/reattachment through more than 30 seconds of phase/post sampling. Automatic CLEAR released only the lab restriction
and preserved four historical internal latency samples. Zero qualification rows began.

Decision consequence: the focused Q5 invalidation test passed on this exact Mi 8 and APK hash, so a separately immutable full qualification
runner may be prepared. Its 100 samples must be new and retain fresh calibration/safety, failure-stop, evidence-integrity and offline requirements.
Q5 does not prove the exact MIUI task mechanism, broad Settings safety, another configuration, production acceptance or Play approval.

## Q6 offline qualification runner

Q5 permits progression without changing enforcement code, but its single expiry and zero qualification rows cannot be pooled. Decision: package
the exact Q5-calibrated candidate and ordinary-fixture APK bytes with [Q6](../test-plans/KR-003-Q6-QUALIFICATION.md), a new runner-only protocol.
Q6 requires reversible offline setup, a fresh excluded calibration, the complete labelled recovery route and Home/re-entry/Clear checks before
and after exactly 100 new expiry observations. Each expiry retains the physical ten-second observation and separately paired internal metric.

Alternatives evaluated: reuse Q5 as calibration (rejected because the source contract requires fresh same-run preflight); run online first
(rejected because it would leave the offline AC-3 condition unresolved); repeat Home/Settings on all 100 samples (rejected because AC-3 does not
require it and the ten-cycle checkpoint already supplied repeated escape/recovery observations); replace visual results with telemetry (rejected
as circular); permit resume/pooling (rejected because configuration/process continuity and failure integrity would be weakened).

Security/privacy: Q6 adds no Android code, permission, event type, identity, node/content, screenshot, network privilege or release hook. It uses
only the existing sender-protected debug controls and zero-permission fixture. The Windows runner may disable Wi-Fi/mobile data only through the
explicit `-OfflineNetwork` invocation; original flags are journalled and restoration is independently verified. A sample-preserving lab CLEAR is
cleanup, never consumer recovery evidence.

Operational implications: one uninterrupted owner run is expected to take 40–60 minutes and needs 101 expiry responses plus two bounded safety
checklists. Any FAIL/INVALID/interruption stops and remains evidence; no cross-run resume or replacement exists. Exit success also requires both
safety checkpoints, exact 100-row/metric agreement, cleanup, radio restoration and no finalization error. A hard host/power loss remains outside
the runner's cleanup guarantee.

Reasons: this is the smallest run that simultaneously satisfies the established 100-observation contract, offline condition, Q5 recovery
precondition and evidence integrity without modifying the physically calibrated enforcement APK. Risks are operator fatigue, physical-screen
eligibility loss, OEM state drift and radio restoration failure. Invalidation tests: synthetic zero/partial/100-row finalization, first-failure
stop, phase-floor isolation, ten-second stable-safe gating, safety field corruption, aggregate mismatch, release leakage and exact APK hash drift.
Physical Q6 execution remains **Not run**; passing it would apply only to this Mi 8 configuration and would not close KR-003 or establish Play approval.

## Q7 owner-constrained active-oracle decision

**Owner operating constraint, 2026-09-06:** no more than three human physical checkpoint sessions. This does not make three checks equivalent to
100 visual observations. Q6 was not executed and is superseded by the explicit Q7 evidence model before any physical qualification began.

Alternatives evaluated:

1. Keep Q6 and ask for 100 P responses: rejected by the owner operating constraint.
2. Treat candidate attachment telemetry as PASS: rejected as circular and contradicted by the original Mi 8 flicker incident.
3. Use screenshots or UI-node inspection: rejected by the privacy/least-privilege constraint.
4. Use current-window dumps as the primary oracle: rejected as OEM-fragile and capable of exposing unrelated titles/packages.
5. Use a separate zero-permission ordinary fixture with real ADB input, interaction/focus counters and three physical calibration checkpoints: selected conditionally.

Decision: Q7 uses the disposable fixture as an active oracle. Each cycle first proves that one real input-layer tap reaches the unblocked fixture.
After expiry it sends 20 equivalent taps over at least ten seconds and requires zero counter increments and zero fixture focus gains. Fixture
process/coordinate continuity is checked. Candidate telemetry separately supplies revision, service, removal and monotonic latency corroboration,
but cannot independently produce PASS. The candidate APK stays byte-identical to Q5; the fixture and runner are new test artefacts.

The three human sessions are: (1) an excluded normal visible expiry agreeing with input denial; (2) a controlled lab-CLEAR negative state in which
the same injected input must visibly and technically reach the fixture; and (3) post-run visual agreement plus the guided Home/Settings/recovery/
re-entry route. Attempts 1–100 run unattended. Result naming must say `100 active-oracle cycles + three human checkpoints`, not `100 physical passes`.

Security/privacy implications: the fixture exposes only numeric counters, booleans, monotonic times and its own transient numeric probe coordinate
through the existing sender-protected debug receiver. It has no permissions or shared state with the candidate. No Accessibility node/content,
text, screenshot, window dump, raw package/component, task history, account, serial or app-history timeline is collected. Release receivers remain
absent and the permission/DEX audit remains mandatory.

Operational implications: the owner performs three sessions and the approximately 35–45 minute 100-cycle section is unattended. Any input leak,
focus regain, service/process replacement, stale revision, overlay removal, permission/configuration drift or broken positive control stops and
preserves evidence. No resume/pooling is allowed. Real Mi 8 ADB input/counter behaviour is not established by desktop tests; Q7 preflight must prove
it before sample 1.

Risks and invalidation tests: a transparent but touch-blocking overlay, rendering-only flash that does not change input focus, or unrelated visual
occlusion can evade the active oracle. These remain human-only residual risks sampled by the two visible expiry checkpoints and must not be claimed
as 100-way coverage. Synthetic tests reject tap leakage, focus regain, fixture/process/coordinate change, missing positive control, fewer than 20
blocked taps, missing/failed checkpoints and altered row/statistic counts. If physical preflight cannot prove both input delivery after CLEAR and
input denial while blocked, Q7 is invalid and the original 100-human contract conflicts with the owner constraint; stop for explicit go/no-go or
scope change.

## UiAutomation transport experiment after Q7 input denial

- **Goal:** Test a SIM-free software input transport while keeping the fixture as the independent outcome oracle.
- **Context:** [Mounted evidence and owner configuration](../test-plans/evidence/KR-003-MI8-INPUT-DENIAL-2026-09-06.md) establish shell INPUT_TAP exit 1 / SECURITY_EXCEPTION, normal debugging enabled and security debugging disabled behind a SIM requirement.
- **Constraints:** Separate self-targeted debug package; one touch; no candidate control, hierarchy/content access, new permissions or setting changes.
- **Done when:** [The tiny preflight](../test-plans/KR-003-UIAUTOMATION-TRANSPORT.md) records exact independent counter delivery or a typed rejection. Qualification adoption remains pending physical evidence.

Alternatives evaluated: instrumenting the candidate or fixture would couple the test to their lifecycle/UID and is rejected. A separate package
using cross-app UiAutomation is selected for this experiment. Monkey is reserved for evaluation only if the UiAutomation attempt fails. Guessed
SIM-gate bypass writes, unrelated developer options and destructive device changes are not justified by current evidence.

Decision/reasons: use public `getUiAutomation(FLAG_DONT_SUPPRESS_ACCESSIBILITY_SERVICES)`, zero event subscriptions and one `injectInputEvent`
DOWN/UP pair, with `finish` owning connection cleanup. The existing ordinary fixture remains unchanged and is queried independently by the host.
The instrumentation can return input acceptance but cannot set the fixture counter or manufacture an enforcement pass.
[Android API contract](https://developer.android.com/reference/android/app/Instrumentation#getUiAutomation(int)),
[UiAutomation flags](https://developer.android.com/reference/android/app/UiAutomation) reviewed 2026-09-06.

Security/privacy implications: no permission additions, candidate callbacks, node queries, screenshots, raw result storage or persistent identity.
Injector/manifest entry exist only in debug; merged manifests and release DEX are audited. Android 10 still uses an automation Accessibility
connection, which is an explicit infrastructure coupling even with suppression disabled and no event collection.

Operational implications: one owner-run command performs the transport probe without physical-response prompts. Success permits preparation of
a bounded service-continuity/positive/blocked calibration, not a direct Q7 run. No new device setting is requested. Rejection is preserved and
triggers the conditional Monkey investigation. Q7's existing contract and three-human-checkpoint limit remain intact.

Risks/tests that invalidate adoption: MIUI rejects UiAutomation, the fixture does not receive exactly one touch, the fixture is replaced/loses
focus, reply correlation fails, instrumentation does not finish, candidate service is suppressed/restarted or any production artefact gains test
capability. Synthetic parser/orchestration tests cannot prove runtime independence; blocked controls and service continuity remain **UNSPECIFIED**.

## Bounded Monkey fallback after measured UiAutomation denial

- **Goal:** Evaluate the owner's final software-only transport alternative without changing Q7's oracle gate.
- **Context:** [The owner run](../test-plans/evidence/KR-003-UIAUTOMATION-DENIAL-2026-09-06.md) establishes DOWN SecurityException and zero fixture delivery, with framework finish returned.
- **Constraints:** No candidate restriction, setting/permission change, full Monkey driver, new data collection or physical execution during preparation.
- **Done when:** [One-touch preflight](../test-plans/KR-003-MONKEY-TRANSPORT.md) preserves independent delivery or typed failure and verified temporary-helper cleanup.

Alternatives evaluated: a full scripted Monkey `Tap` is deterministic in coordinate selection but its driver installs a global activity controller
and resets rotation, so it is rejected for this isolated experiment. Direct invocation of its touch-event class is the smaller experiment.
Repeating denied UiAutomation, speculative SIM-gate writes and unrelated developer options have no evidentiary justification.
[Android 10 driver](https://github.com/aosp-mirror/platform_development/blob/android10-release/cmds/monkey/src/com/android/commands/monkey/Monkey.java).

Decision/reasons: a debug-only helper, loaded by a short-lived authorized shell process, invokes only `MonkeyTouchEvent` DOWN/UP with verbosity zero.
Public tool methods are resolved reflectively without access overrides. The fixture's separately queried counter/focus is the outcome oracle;
the candidate cannot report PASS. The AOSP implementation calls the same OS input manager, so this is not an elevation or a promised MIUI bypass.
[Motion implementation](https://github.com/aosp-mirror/platform_development/blob/android10-release/cmds/monkey/src/com/android/commands/monkey/MonkeyMotionEvent.java), reviewed 2026-09-06.

Security/privacy implications: no Accessibility connection, node/content inspection, permissions or logs beyond fixed enum/numeric records. The helper
is a shell-UID tool, distinct from both app UIDs, with no shared app state/callbacks. Release code is absent. A typed single-output exception in the
static validator is restricted to the exact debug file/sink; mutation tests verify new raw logging still fails. This is unsupported tool-internal
integration, not production API use. MIUI's exact implementation and runtime side effects remain **UNSPECIFIED**.

Operational implications: install the unchanged disposable fixture, upload one temporary helper APK, inject once under a native timeout, remove and
verify absence of that exact temporary file. No candidate commands or radio/setting changes. Cleanup failure is independently recorded and prevents
PASS. The old bundle and evidence remain immutable. A successful touch only permits subsequent blocked-control/service-continuity calibration.

Risks/tests that invalidate the decision: unavailable classes/methods, permission denial, timeout, stale reply, wrong coordinate, zero/double taps,
fixture replacement/focus loss, helper cleanup failure, production leakage, or service/configuration interference during any later calibration.
Synthetic tests exercise these observable failures but do not establish physical support. If this route fails, report the safe tested software input
paths unavailable on this exact configuration and the owner-constraint/qualification conflict; stop for a device/configuration/product decision.
No change to 100-cycle evidence semantics, maximum three human checkpoints or visual-only limitations is approved by this experiment.

### Measured outcome and stop condition — 2026-09-07

[Monkey evidence](../test-plans/evidence/KR-003-MONKEY-DENIAL-2026-09-07.md) establishes DOWN SECURITY_EXCEPTION, counter 0→0 and verified cleanup.
All three tested input routes are denied on this reported configuration. This invalidates adoption of these transports here, not prior bounded
enforcement observations, and does not prove every conceivable transport impossible.

Decision: apply the existing stop condition. Q7 cannot proceed; its unfulfilled oracle prerequisite and the maximum-three-human constraint
currently conflict. Owner choice of another authorized physical device, supported explicitly approved configuration investigation, or pause/product
scope review is **UNSPECIFIED**. Another device's results cannot be attributed to this Mi 8; any settings change creates a separately recorded
configuration. Fresh input delivery, blocked controls and service continuity are required before reconsideration. No new code, security bypass,
per-cycle manual replacement or gate reduction is justified. Security/privacy and operational constraints above remain unchanged.
