# KR-003 physical-evidence operator tooling

- **Goal:** Reproducible transport, oracle-calibration and configuration-specific qualification evidence with explicit stops between gates.
- **Context:** Q5 passed the Mi 8 candidate recovery route; Q7 is blocked on that configuration. OD-31 authorizes generic transport-first preparation for the next device.
- **Constraints:** No Windows ADB execution from WSL; disposable debug APKs only; no automatic physical PASS, host repair, destructive test, production implementation or KR-004.
- **Done when:** Clean-source bundles keep configuration discovery, fixture-only transport, bounded calibration and any later 100-cycle qualification separate and machine-verifiable.

## Generic next-device flow

Package the fixture-only onboarding bundle from a clean committed source:

```sh
node tools/kr003/package-device-preflight.mjs /mnt/c/platform-tools/kr003-device-preflight-bundles/NEW_UNIQUE_COMMIT_DIRECTORY
```

Owner command after connecting and authorizing exactly one unlocked device:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\platform-tools\kr003-device-preflight-bundles\NEW_UNIQUE_COMMIT_DIRECTORY\Test-KR003-DeviceTransport.ps1"
```

This command records the limited sanitized metadata, verifies local/bundle/installed fixture hashes, installs only the ordinary fixture, performs
one counter-correlated shell tap and stops. It contains no candidate APK or timer path. Ingest with:

```sh
node tools/kr003/ingest.mjs device /mnt/c/platform-tools/kr003-device-preflight/ACTUAL_DEVICE_DIRECTORY
```

Only after a preserved transport PASS, package/run the bounded calibration bundle. Runner v4 preserves typed host-stage, exception-class,
primary-result, cleanup and finalization status without raw exception output. The owner passes the prior evidence directory; the runner
installs the exact disposable candidate, waits for manual permission setup, performs one positive control, one blocked control, service-continuity
checks and one physical agreement prompt, cleans up and stops with zero qualification rows:

Runner v2 scopes secure settings to the current Android user, compares normalized short/full component identities, and writes only typed
permission-source/parse/health diagnostics. It never stores raw AppOps, settings or dumpsys output. `UNKNOWN` still rejects, and the runner rechecks
permission/service health before ARM and after the blocked hold.

```sh
node tools/kr003/package-oracle-calibration.mjs /mnt/c/platform-tools/kr003-oracle-calibration-bundles/NEW_UNIQUE_COMMIT_DIRECTORY
```

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\platform-tools\kr003-oracle-calibration-bundles\NEW_UNIQUE_COMMIT_DIRECTORY\Test-KR003-OracleCalibration.ps1" -TransportEvidence "C:\platform-tools\kr003-device-preflight\ACTUAL_DEVICE_DIRECTORY"
```

Ingest with `node tools/kr003/ingest.mjs calibration ACTUAL_CALIBRATION_DIRECTORY`. A calibration PASS permits review/preparation of a new
configuration-specific qualification bundle. It does not run or authorize 100 samples.

## Historical Mi 8 Q7 build and package

Use the existing JDK 17 and Android SDK. Run repository, Node, PowerShell and Android checks, commit a clean source revision, then create a new directory:

```sh
node tools/kr003/package.mjs /mnt/c/platform-tools/kr003-qualification-bundles/NEW_UNIQUE_COMMIT_DIRECTORY
```

Packaging refuses a dirty tree or existing destination, rebuilds/tests/lints debug and release, audits merged permissions/release DEX, and hashes every payload. It refuses candidate drift from the Q5-calibrated APK and fixture drift from the reviewed Q7 oracle build. `candidateCalibratedBy` identifies Q5; the new fixture must pass Q7 preflight on-device. No physical run occurs during packaging.

When the historical Q7 Mi 8 input transport was under investigation, `Test-KR003-OracleTransport.ps1` ran only the disposable fixture receiver and one ADB tap.
`package-transport.mjs` creates a separate immutable diagnostic bundle; it does not arm the candidate or alter radios, permissions or configuration.

## Execute (owner / PowerShell)

Use the exact populated command in the latest bundle handoff:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\platform-tools\kr003-qualification-bundles\NEW_UNIQUE_COMMIT_DIRECTORY\Start-KR003.ps1" -OfflineNetwork
```

`-ExecutionPolicy Bypass` applies only to that process. Q7 requires `-OfflineNetwork` and rejects diagnostic/calibration-only modes. It journals original radio flags, disables enabled Wi-Fi/mobile data, obtains an explicit operator confirmation, and restores/read-backs each changed flag during independently guarded finalization. Keep only the authorized Mi 8 connected. The runner installs in place and pulls/hashes installed APKs; it never uninstalls, clears app data, grants permissions, reboots or repairs host/WSL state.

The full [Q7 contract](../../docs/test-plans/KR-003-Q7-AUTOMATED-QUALIFICATION.md) is bundled. The 100-cycle section runs unattended for approximately 35–45 minutes; the screen must remain unlocked/interactive. Any automated failure stops and remains in the evidence—there is no replacement, resume or pooling.

Q7 first asks for one normal visible expiry checkpoint, then one controlled unblocked negative checkpoint. The 100-cycle section has no P prompts:
each cycle proves input reaches the fixture before arm, then injects 20 equivalent taps during restriction and requires zero delivery/focus regain.
The third human session follows sample 100 and runs the guided Home/Settings/Digital Wellbeing/recovery/re-entry route. These remain separate evidence.

## Evidence and bailout

Every execution creates a new `C:\platform-tools\kr003-qualification\run-*` directory. It contains bundle/device/APK identity, prior/final metrics, calibration, attempt JSON/CSV, human checkpoints, sanitized telemetry/trace, fixture counters, final safety/recovery, radio journals, sample-preserving bailout evidence and summaries. The agent reads it directly from `/mnt/c`; do not copy logs manually.

Normal finalization automatically invokes debug CLEAR and verifies the complete timing sample array is unchanged. If the terminal is forcibly interrupted or the phone remains trapped, run the bundle's separate bailout from a second PowerShell window:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\platform-tools\kr003-qualification-bundles\NEW_UNIQUE_COMMIT_DIRECTORY\Clear-KR003-Lab.ps1"
```

That command only queries and clears the disposable lab timer; it does not change data, installation, permissions or network and is not consumer recovery evidence. A hard host/power kill cannot guarantee `finally` or radio restoration, so preserve `network-original.json` for owner review.

After a run, ingest without modifying originals:

```sh
node tools/kr003/ingest.mjs qualification /mnt/c/platform-tools/kr003-qualification/ACTUAL_RUN_DIRECTORY
```

Exit zero means only `PASSED_AUTOMATED_ORACLE_WITH_THREE_PHYSICAL_CHECKPOINTS_THIS_CONFIGURATION_ONLY` for this exact offline Mi 8/build with verified bailout/restoration and clean finalization. It is not 100 human-visible passes and does not close KR-003, establish other devices, complete remaining matrix rows or prove Play acceptance.

## Local checks

```sh
node --test tools/kr003/*.test.mjs
pwsh -NoProfile -File tools/kr003/Qualification.Tests.ps1
pwsh -NoProfile -File tools/kr003/Runner.Tests.ps1
pwsh -NoProfile -File tools/kr003/OracleTransport.Tests.ps1
pwsh -NoProfile -File tools/kr003/UiAutomationTransport.Tests.ps1
pwsh -NoProfile -File tools/kr003/MonkeyTransport.Tests.ps1
pwsh -NoProfile -File tools/kr003/DevicePreflight.Tests.ps1
pwsh -NoProfile -File tools/kr003/OracleCalibration.Tests.ps1
pwsh -NoProfile -File tools/kr003/PowerShellSafety.Tests.ps1
pwsh -NoProfile -File tools/kr003/OracleCalibrationEntrypoint.Tests.ps1
cd spikes/android-enforcement && ./gradlew --no-daemon testDebugUnitTest lintDebug assembleDebug lintRelease assembleRelease
node tools/kr003/audit-build.mjs
node tools/validate.mjs
git diff --check
```

PowerShell tests use synthetic state and observer stubs only. CI's native Windows PowerShell job validates host-runtime compatibility, not ADB, MIUI or physical enforcement.

## Preserved Mi 8 transport result

The Mi 8 rejects shell input with exit 1 / SECURITY_EXCEPTION; the owner observed the input-related security switch disabled and SIM-gated.
See [preserved configuration evidence](../../docs/test-plans/evidence/KR-003-MI8-INPUT-DENIAL-2026-09-06.md).
UiAutomation and bounded Monkey were also denied; Q7 stays halted on the unchanged Mi 8. Do not rerun those historical transports or change the
Mi 8 configuration. The generic next-device flow above is separate and makes no Samsung/input-support claim before execution.
