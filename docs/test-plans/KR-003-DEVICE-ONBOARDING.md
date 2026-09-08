# KR-003 generic authorized-device onboarding

- **Goal:** Identify one authorized Android configuration and test only the shell-input transport needed by the independent fixture oracle.
- **Context:** The existing Mi 8 result is configuration-specific. A prospective Samsung tablet is expected, but its exact device facts and shell-input capability are **UNSPECIFIED** until this protocol runs.
- **Constraints:** One authorized, unlocked device; fixture only; no candidate installation, timer, Accessibility setup, network/configuration mutation, screenshot, UI node/text/content, serial/account/app-history capture or destructive action.
- **Done when:** A sanitized configuration record and exact hash evidence exist, one fixture tap produces exactly one counter increment or a typed FAIL/INVALID result is preserved, and the procedure stops.

## Evidence stages

These stages are independent and must not be collapsed:

1. **Configuration discovery:** record manufacturer/model, Android version, API level, security patch/build ID, the readable generic battery-management flags, and required candidate permission state. A candidate that is not installed records its permission state as `NOT_APPLICABLE_CANDIDATE_NOT_INSTALLED`.
2. **Transport capability:** install only the independent ordinary fixture, foreground it, read its probe coordinate/counter, issue exactly one `adb shell input tap`, require one counter increment and stop.
3. **Oracle calibration:** only after transport PASS, use the separate bounded calibration protocol. Transport PASS alone says nothing about candidate blocking.
4. **100-cycle qualification:** only after calibration PASS and a configuration-specific bundle/review. Results belong to that exact metadata/power/permission configuration.
5. **Human residual risks:** visible coverage, readability, rendering-only flicker and safe-surface usability remain physical observations; counters and candidate telemetry cannot prove them.

## Collected fields

The runner persists only:

- manufacturer and model;
- Android release and API level;
- security patch and build ID;
- battery saver, adaptive-battery and app-standby flags when the platform returns an unambiguous boolean, otherwise `UNSPECIFIED`;
- OEM battery-management setting as `UNSPECIFIED` until an operator records the exact relevant setting for the later candidate configuration;
- candidate Usage Access and Accessibility-service state, or the explicit not-installed state;
- source commit, local/bundled/installed fixture SHA-256 values, typed operation outcomes and fixture counter values.

The runner never persists ADB serial output, build fingerprint, Android ID, accounts, package inventory, enabled-service lists, raw command output, UI content or application history. Build ID is an OS build label, not a device serial. Exact Samsung/OEM power-setting labels cannot be inferred from generic Android flags and remain **UNSPECIFIED** until separately observed.

Android's hardware-device guide uses `adb devices` to verify a connection and describes the on-device USB-debugging authorization flow. The runner instead reduces the result to an authorized/unavailable enum so the device identifier is not retained. Android documents Doze, App Standby and user-controlled battery optimization separately; generic flags do not establish an OEM background policy. See [hardware device setup](https://developer.android.com/studio/run/device) and [Doze/App Standby](https://developer.android.com/training/monitoring-device-state/doze-standby), reviewed 2026-09-08.

## Owner command

Connect exactly one authorized, unlocked device. Accept the device's ADB authorization prompt if shown, then run the immutable bundle command:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\platform-tools\kr003-device-preflight-bundles\SOURCE_COMMIT\Test-KR003-DeviceTransport.ps1"
```

The command validates its own bundle, reduces ADB authorization to a typed state, captures the approved metadata, installs and verifies only `ordinary-fixture.apk`, foregrounds it, obtains its own probe coordinate/counter, attempts one shell tap, verifies the installed APK hash and counter, then stops. It does not install or invoke the enforcement candidate.

Expected duration after ADB authorization: about one minute. Preserve the printed evidence directory; do not rerun a failed/invalid configuration before review.

## Result contract

- **PASS — `PASSED_TRANSPORT_PREFLIGHT:FIXTURE_COUNTER_INCREMENTED_ONCE`:** the same fixture instance/coordinate remained focused and its counter changed by exactly one. This establishes shell-input transport only.
- **FAIL — `FAILED:INPUT_NOT_DELIVERED`:** ADB accepted the tap operation, but the independent counter did not increment exactly once. Stop before candidate installation.
- **INVALID:** authorization/device state, hash, fixture readiness, command acceptance, metadata integrity or evidence finalization was not established. Stop and preserve the evidence.

No result is an enforcement, latency, safety, other-device or Play-policy result. A Samsung result applies only to the recorded Samsung configuration. It cannot be attributed to the Mi 8, Pixel, another Samsung build or another OEM.
