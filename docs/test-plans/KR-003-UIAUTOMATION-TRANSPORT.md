# KR-003 UiAutomation transport preflight

- **Goal:** Determine whether one cross-application touchscreen input can reach the independent ordinary fixture on the SIM-less Mi 8.
- **Context:** Shell input fails with exit 1 / SECURITY_EXCEPTION; the owner observed the input-related MIUI security switch disabled and SIM-gated.
- **Constraints:** One disposable self-targeted debug instrumentation, one coordinate touch, no candidate ARM/CLEAR, no settings/radio/permission changes, no UI nodes/content/screenshots or package history.
- **Done when:** The separately queried fixture counter increments exactly once, or a sanitized transport/cleanup failure is preserved. Zero Q7 samples.

## Mechanism and independence

The existing fixture remains byte-identical to Q7. A new package `dev.kidremote.spike.inputprobe` declares only a debug instrumentation targeting
itself. Android starts instrumentation in that package's process/UID, not in the fixture or candidate. No shared UID, permissions, dependencies,
fixture callbacks, candidate callbacks or privileged shell-identity adoption are added. The host obtains the coordinate from the fixture's existing
sender-protected receiver; the probe receives only numeric x/y and a transient request number. It injects one touchscreen DOWN/UP pair through
`Instrumentation.getUiAutomation(flags)` / `UiAutomation.injectInputEvent(event, true)`, recycles the events, calls public `finish`, and returns only typed
stage/outcome/accepted/cleanup fields. The host independently re-queries the fixture's counter, focus, instance and coordinate.

The injection return value cannot establish PASS. PASS requires both accepted input events, a completed instrumentation result, unchanged fixture
instance/coordinate, focused/resumed fixture and exactly one increment. Zero increment, multiple increments, stale request, missing/malformed reply,
rejection, loss of focus or cleanup failure stop with FAIL/INVALID. A simultaneous manual tap would contaminate this tiny test: keep hands off.

Official Android documents cross-app injection through UiAutomation, while ordinary Instrumentation input is restricted to its target.
[Instrumentation](https://developer.android.com/reference/android/app/Instrumentation#getUiAutomation(int)) (reviewed 2026-09-06).
`finish` disconnects UiAutomation before publishing its result in the
[official Android 10 implementation](https://github.com/aosp-mirror/platform_frameworks_base/blob/android10-release/core/java/android/app/Instrumentation.java).
The probe uses this public lifecycle API; the host requires its matching terminal result. Private MIUI lifecycle implementation remains **UNSPECIFIED**.

## Critical Accessibility coupling

UiAutomation normally suppresses other Accessibility services. This probe explicitly uses `FLAG_DONT_SUPPRESS_ACCESSIBILITY_SERVICES` (API 24+).
The alternative `FLAG_DONT_USE_ACCESSIBILITY` requires API 31 and is unavailable on this API 29 device: its automation connection still exists,
but eventTypes and flags are set to zero immediately and no event listener, node/window query, text access or screenshot API is used.
[UiAutomation flags and injection](https://developer.android.com/reference/android/app/UiAutomation) (reviewed 2026-09-06).

This is independent of the candidate's enforcement decision, but shares Android's input/window/Accessibility infrastructure. A successful unblocked
touch establishes transport only. Before adopting it for Q7, measure candidate service/heartbeat continuity throughout connection, injection and
disconnection, run positive and blocked controls and reject any service replacement/configuration change. Do not silently substitute it in Q7.
The three-human-checkpoint model remains conditional on those controls; visual-only flashes remain outside the automated oracle's proof.

## Runner and evidence

`tools/kr003/Test-KR003-UiAutomationTransport.ps1` verifies an immutable bundle, installs the existing fixture and debug probe using `install -r`,
foregrounds the fixture, requires its focus/resumed/probe-ready state, runs one instrumented touch and checks the counter. It does not launch
the probe's own activity (none exists), instrument the candidate, arm a restriction or change the tested developer settings. Existing lab restriction
must already be clear; otherwise preflight fails readiness without touching the screen.

Output under `C:\platform-tools\kr003-uiautomation-transport`:

- `operations.json`: fixed operation enum, exit code, NONE / SECURITY_EXCEPTION / PERMISSION_DENIAL / OTHER only.
- `probe.json`: validated transient request, fixed stage/outcome, DOWN/UP acceptance and disconnect result.
- `fixture-before.json`, `fixture-after.json`: existing sanitized fixture schema with focus/counter/process-lifetime/coordinate checks, no package identity.
- `summary.json`: source/APK hashes, UTC interval, fixture before/after counters, result and zero Q7 samples.

Raw native stdout/stderr is parsed in memory and discarded. No raw package/component output, identifiers, package history or personal data is saved.
The static validator scans the new module; release has no instrumentation entry or injector code. Existing candidate/fixture release checks stay strict.

Expected operator time: keep the connected phone unlocked and hands off for about 10–20 seconds. No observation prompt or qualification checkpoint.
Execution is owner-operated PowerShell; WSL reads the generated directory directly afterward.

## Next-step decision

Owner execution is now ingested: [DOWN injection was denied with SecurityException; framework finish returned; fixture counter stayed zero](evidence/KR-003-UIAUTOMATION-DENIAL-2026-09-06.md).
Physical input support failed on this tested configuration. Required MIUI settings for this mechanism and candidate-service non-interference remain **UNSPECIFIED**.
The following conditional decision is retained; the next experiment is [Monkey touch-class transport](KR-003-MONKEY-TRANSPORT.md).
If this test passes, prepare one bounded positive/blocked/non-interference calibration before changing Q7's transport contract. If it fails,
evaluate a deterministic, fixture-bounded Monkey touch next; do not launch a random Monkey sequence. If both routes fail on this unchanged
configuration, record software input automation as unavailable through the tested mechanisms and request a go/no-go/configuration decision.

No verified official SIM-free method to enable this exact MIUI security toggle was found. Its private implementation is **UNSPECIFIED**.
Do not substitute unrelated developer options, root, bootloader changes, security-app removal or guessed persistent settings writes.
