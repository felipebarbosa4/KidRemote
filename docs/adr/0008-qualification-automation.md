# ADR-0008 — Debug qualification controls and observation oracle

Status: Accepted for the KR-003 disposable lab, 2026-09-06. Q1 controls operated on Mi 8; the recovery oracle disagreed with physical observation.
Q2 physically failed Settings/recovery. Q3 reproduced the destination/recovery failure with phase-local evidence and verified its lab bailout.
Engineering safety/qualification remain blocked.

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
