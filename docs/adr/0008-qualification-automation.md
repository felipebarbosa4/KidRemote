# ADR-0008 — Debug qualification controls and observation oracle

Status: Accepted for the KR-003 disposable lab, 2026-09-06. Physical operation of the new controls remains unverified until calibration.

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
