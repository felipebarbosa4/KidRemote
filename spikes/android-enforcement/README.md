# Android consumer-enforcement feasibility spike

- **Goal:** Prove or reject the least-privilege consumer Accessibility candidate in ADR-0002 before production enforcement work.
- **Context:** KR-003 is the highest-risk Architecture & Feasibility issue; product/state decisions are approved, but device behaviour and Play acceptance are not.
- **Constraints:** Disposable native harness only; no backend, production package ID, child data, stealth, node/text/content access, gestures, screenshots, broad package query, exact alarm, foreground-service workaround or claim of Play approval.
- **Done when:** The issue's physical/OEM/policy matrix has actual evidence, 100 expiry observations per candidate meet p95 ≤2 seconds, safe recovery is demonstrated and the owner accepts a tested support boundary or changes scope.

## Status and boundary

This directory is intentionally separate from `apps/child-android`. It is an installable test harness, not the MVP child agent.
The package ID `dev.kidremote.spike.enforcement`, 10-second allowance and framework-only UI are disposable.
No result from a desktop build proves Android enforcement, reboot recovery, OEM support or Google Play acceptance.

The candidate uses:

- `PowerManager.isInteractive` plus `KeyguardManager.isKeyguardLocked` to gate a monotonic lab countdown;
- `SystemClock.elapsedRealtime()` for within-boot intervals;
- aggregate `UsageEvents` screen/keyguard signals as a diagnostic probe only;
- device-protected `SharedPreferences` as disposable spike persistence, not the production Room decision;
- a system-bound `AccessibilityService` subscribed only to window-state changes;
- `TYPE_ACCESSIBILITY_OVERLAY` over a known ordinary-app surface after expiry;
- a fail-open result for missing package identity and a small candidate allowlist for own/system/settings/dialler surfaces.

The allowlist is a test hypothesis, not a supported-device guarantee. Its OEM/package coverage and emergency/recovery safety must be measured.
Only a transient package identity is classified in memory; package history is not retained, logged or uploaded.

## Toolchain contract

Verified 2026-09-05:

| Tool | Spike selection | Reason |
| --- | --- | --- |
| Android Gradle Plugin | 9.4.0 | Current stable AGP; official compatibility table |
| Gradle | 9.6.0 | AGP 9.4 default/minimum; wrapper distribution checksum pinned |
| JDK toolchain | 17 | AGP 9.4 requirement and explicit Android build recommendation |
| compile / target SDK | 36 | Current stable Android 16 platform and current Play submission floor |
| minimum SDK | 28 | Architecture candidate for the event set; support remains **UNSPECIFIED** pending tests |
| Build Tools | 36.0.0 | AGP 9.4 default; supplied by an authorized Android SDK installation |

AGP 9.4 built-in Kotlin is used; the obsolete `org.jetbrains.kotlin.android` plugin is deliberately absent.
The wrapper JAR SHA-256 is `497c8c2a7e5031f6aa847f88104aa80a93532ec32ee17bdb8d1d2f67a194a9c7` and the Gradle ZIP SHA-256 is
`bbaeb2fef8710818cf0e261201dab964c572f92b942812df0c3620d62a529a01`.

## Build and static checks

Prerequisites are JDK 17 plus an Android SDK installation whose licence was accepted by an authorized person and which contains
`platforms;android-36` and `build-tools;36.0.0`. Do not commit `local.properties` or an SDK.

```sh
cd spikes/android-enforcement
./gradlew --no-daemon testDebugUnitTest lintDebug assembleDebug lintRelease assembleRelease
```

Repository-level least-privilege/static checks:

```sh
node tools/validate.mjs
node tools/kr003/audit-build.mjs
git diff --check
```

The GitHub workflow checks the runner already has the required SDK packages; it does not silently accept licences or install preview SDKs.
The first compile/unit/lint/APK/merged-manifest run is recorded in
[KR-003 evidence](../../docs/test-plans/evidence/KR-003-2026-09-05.md); it is not Android runtime evidence.

## Authorized lab-device use

Never install this spike on a child's or other personal device. Use an explicitly authorized, recoverable lab device with no personal content.
Follow [the KR-003 physical protocol](../../docs/test-plans/KR-003-PHYSICAL.md) and record results in
[`docs/test-plans/evidence`](../../docs/test-plans/evidence/README.md).

Basic smoke path:

1. Install the debug APK on the recorded lab configuration.
2. Read the standalone disclosures; verify refusal leaves both privileges disabled.
3. Enable Usage Access and the labelled Accessibility service manually in Android Settings.
4. Arm the 10-second timer and switch to a disposable ordinary test app.
5. Observe whether the block appears, then use system/emergency/recovery routes and revoke each privilege.
6. Reset timing samples only before a documented candidate run; do not mix OS/OEM/configuration samples.

The on-device p50/p95/max counter measures theoretical monotonic expiry to successful overlay attachment. It records only non-negative
latencies and a bounded maximum of 500 numbers. It does not prove the overlay was perceptible, safe or resistant; the observer records those separately.

## Automated owner-operated qualification

The [qualification runner guide](../../tools/kr003/README.md), [contract](../../docs/test-plans/KR-003-QUALIFICATION.md) and
[ADR-0008](../../docs/adr/0008-qualification-automation.md) define the new debug-only control/metric export and zero-permission ordinary fixture.
Neither the debug receivers nor trace/probe implementation ships in release. No production enforcement decision was changed for automation.
Q7's fixture provides an independent active input/focus oracle: every cycle proves input delivery after CLEAR, then requires 20 equivalent ADB
taps to be denied while restricted. This can produce an automated-oracle result but never a human-visible claim. Three physical checkpoint sessions
calibrate/spot-check the oracle. The Mi 8's successful ten-cycle evidence applies to the previously recorded candidate; the new fixture requires
on-device Q7 preflight before 100 unattended cycles.

## Current official sources

- [AGP 9.4 compatibility](https://developer.android.com/build/releases/agp-9-4-0-release-notes)
- [Built-in Kotlin migration](https://developer.android.com/build/migrate-to-built-in-kotlin)
- [Android Java toolchains](https://developer.android.com/build/jdks)
- [UsageStatsManager](https://developer.android.com/reference/android/app/usage/UsageStatsManager)
- [UsageEvents.Event](https://developer.android.com/reference/android/app/usage/UsageEvents.Event)
- [SystemClock](https://developer.android.com/reference/android/os/SystemClock)
- [Accessibility service guide](https://developer.android.com/guide/topics/ui/accessibility/service)
- [AccessibilityService API](https://developer.android.com/reference/android/accessibilityservice/AccessibilityService)
- [Play Accessibility declaration](https://support.google.com/googleplay/android-developer/answer/10964491)
- [Play sensitive API policy](https://support.google.com/googleplay/android-developer/answer/16558241)

Sources and versions were rechecked 2026-09-05. Policy and toolchain must be rechecked before release.
