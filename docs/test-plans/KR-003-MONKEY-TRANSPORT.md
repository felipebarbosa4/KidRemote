# KR-003 Monkey touch-class transport preflight

Status, 2026-09-07: [owner execution returned DOWN SECURITY_EXCEPTION, zero taps and verified cleanup](evidence/KR-003-MONKEY-DENIAL-2026-09-07.md).
The stop condition below is active for the unchanged Mi 8. Do not rerun it or change that configuration. OD-31 now authorizes a separate generic
transport-first path for the expected next device; its exact facts and result remain **UNSPECIFIED**.

- **Goal:** Test the final bounded software input alternative on the unchanged SIM-less Mi 8.
- **Context:** Shell input and separate UiAutomation both returned SecurityException; [the latter run](evidence/KR-003-UIAUTOMATION-DENIAL-2026-09-06.md) delivered zero fixture taps.
- **Constraints:** One disposable-fixture touch, no candidate commands, settings/permissions/radios changes, nodes, content, screenshots, raw identities or package history. No Q7 execution.
- **Done when:** A correlated typed result and independent fixture counter prove exactly one delivery, or preserve an unsupported/denied/failed transport with cleanup evidence.

## Source-reviewed mechanism

Do **not** run full `monkey`, random or scripted. Android 10's driver installs a global activity controller and invokes a rotation
reset in cleanup; these can interfere with the behaviour under test. Its crash-handling paths also collect unnecessary diagnostic data.
[Official Monkey guide](https://developer.android.com/studio/test/other-testing-tools/monkey),
[Android 10 Monkey driver](https://github.com/aosp-mirror/platform_development/blob/android10-release/cmds/monkey/src/com/android/commands/monkey/Monkey.java),
[rotation event](https://github.com/aosp-mirror/platform_development/blob/android10-release/cmds/monkey/src/com/android/commands/monkey/MonkeyRotationEvent.java), reviewed 2026-09-06.

Instead a debug-only helper calls the installed tool's `MonkeyTouchEvent` public constructor/methods via reflection, in a short-lived shell
`app_process`. Only one DOWN/UP pair is constructed, at the coordinate supplied by the existing fixture receiver. No private-access override,
privilege adoption, full driver, activity controller or rotation API is invoked. Android 10's touch implementation forwards to the OS input manager;
the two manager arguments are unused and verbosity zero avoids event output. Success return code is 1. These are **tool internals, not product SDK APIs**.
[Touch event](https://github.com/aosp-mirror/platform_development/blob/android10-release/cmds/monkey/src/com/android/commands/monkey/MonkeyTouchEvent.java),
[motion implementation](https://github.com/aosp-mirror/platform_development/blob/android10-release/cmds/monkey/src/com/android/commands/monkey/MonkeyMotionEvent.java),
[result constants](https://github.com/aosp-mirror/platform_development/blob/android10-release/cmds/monkey/src/com/android/commands/monkey/MonkeyEvent.java), reviewed 2026-09-06.

The existing input-probe debug APK supplies the helper class, but is **not installed or instrumented** by this runner. It is uploaded to one
randomly named `/data/local/tmp/kr003-monkey-<case>.apk`, loaded alongside `/system/framework/monkey.jar`, and deleted by exact path after execution.
The short-lived shell process has a UID distinct from candidate/fixture, no shared application state and no callback to either app.
It has the existing shell privileges, not an input-permission bypass. MIUI may reject the same input-manager operation; compatibility and success
remain **UNSPECIFIED** until this physical preflight. Missing classes/methods are UNSUPPORTED, not evidence of input denial.
[AOSP tool launcher](https://github.com/aosp-mirror/platform_development/blob/android10-release/cmds/monkey/monkey),
[app_process entry](https://github.com/aosp-mirror/platform_frameworks_base/blob/android10-release/cmds/app_process/app_main.cpp).

The helper is wrapped in Android Toybox `timeout -k 2 15`: termination after 15 seconds and kill two seconds later if still running.
The host also has a 30-second operation limit. Availability/MIUI compatibility is checked by the operation result; failures stop.
[Android 10 timeout implementation](https://android.googlesource.com/platform/external/toybox/+/android-10.0.0_r1/toys/other/timeout.c).
The helper attempts UP after a failed DOWN and preserves the first error. A timeout after accepted DOWN leaves pointer completion **UNSPECIFIED**;
do not automatically retry. This bounded uncertainty is confined to an unlocked disposable fixture, never an armed restriction.

## Runner, independent oracle and cleanup

`tools/kr003/Test-KR003-MonkeyTransport.ps1` verifies bundle hashes, installs the unchanged fixture with `install -r`, opens it, requires
focused/resumed/probe-ready state, injects once and queries the fixture again. The helper accepts only numeric x/y/request and emits only
fixed stage/outcome/boolean fields with that transient request. Raw stdout/stderr are discarded after parsing; operation evidence is enum/exit/coarse class.

PASS means accepted DOWN and UP **and** exactly one fixture counter increment, same process instance and coordinate, retained readiness/focus/resume,
plus verified removal of the runner's own temporary helper APK. The helper cannot increment that counter directly. Zero or double delivery, loss
of focus, replacement, stale/malformed reply, rejection or unverified cleanup is FAIL/INVALID. No internal acceptance result alone is a pass.
Keep hands off: a manual tap contaminates the independent counter. Existing restriction must already be clear; this runner never changes it.

The only deletion is the exact temporary APK created by this run; no app data, installed package, evidence, permission or directory is removed.
Cleanup is attempted independently of the primary result. A cleanup failure cannot mask an earlier injection failure; it invalidates an otherwise
successful preflight. Its operation record remains available. Evidence under `C:\platform-tools\kr003-monkey-transport` includes `summary.json`,
`operations.json`, and where reached `probe.json`, `fixture-before.json`, `fixture-after.json`. `HelperCleanup` must be REMOVED_AND_VERIFIED for PASS.
`node tools/kr003/ingest.mjs monkey <directory>` validates these independently. Zero Q7 samples and no observer checkpoint are produced.

## Isolation and decision boundary

Candidate/fixture APK bytes and Q7 acceptance criteria are unchanged. The helper exists only in the debug source set, with no permission additions.
Static validation permits exactly one fixed typed stdout sink in this file, scans all remaining code normally, and rejects extra logging, nodes,
reflection access overrides and controller/rotation APIs. Release DEX must contain neither the helper nor its output marker. Linux/native Windows
synthetic orchestration and Node ingestion/rejection tests cannot prove real MIUI delivery or runtime non-interference.

If PASS: next prepare a bounded positive/blocked/service-continuity calibration before proposing Q7 transport adoption. The three-human-checkpoint
model remains conditional, not proven by this touch. Shared OS input/window infrastructure and visual-only flashes remain oracle limitations.
If denied/unsupported: the safe tested software-only paths are unavailable on this configuration; stop for an explicit configuration/device/product
decision. Do not claim every imaginable transport is impossible, lower the oracle gate, use unrelated settings, demand a SIM, or try security bypasses.

Operator: one packaged PowerShell command, connected unlocked fixture-ready phone, hands off, approximately 10–25 seconds normally. No manual result
prompt. WSL reads evidence afterward. No device execution is performed during repository preparation.
