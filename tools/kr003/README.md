# KR-003 qualification operator tooling

- **Goal:** One owner-run Windows command, reproducible evidence, 100 unattended active-oracle cycles and at most three human checkpoint sessions.
- **Context:** Q5 passed the candidate recovery route; unexecuted Q6 was superseded by the owner-constrained [Q7 contract](../../docs/test-plans/KR-003-Q7-AUTOMATED-QUALIFICATION.md).
- **Constraints:** No Windows ADB execution from WSL; disposable debug APKs only; no automatic physical PASS, host repair, destructive test, production implementation or KR-004.
- **Done when:** An integrity-checked Q7 bundle records oracle calibration, three human checkpoints, 100 paired active-oracle cycles, cleanup/restoration and a machine-verifiable summary.

## Build and package (agent / WSL)

Use the existing JDK 17 and Android SDK. Run repository, Node, PowerShell and Android checks, commit a clean source revision, then create a new directory:

```sh
node tools/kr003/package.mjs /mnt/c/platform-tools/kr003-qualification-bundles/NEW_UNIQUE_COMMIT_DIRECTORY
```

Packaging refuses a dirty tree or existing destination, rebuilds/tests/lints debug and release, audits merged permissions/release DEX, and hashes every payload. It refuses candidate drift from the Q5-calibrated APK and fixture drift from the reviewed Q7 oracle build. `candidateCalibratedBy` identifies Q5; the new fixture must pass Q7 preflight on-device. No physical run occurs during packaging.

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
cd spikes/android-enforcement && ./gradlew --no-daemon testDebugUnitTest lintDebug assembleDebug lintRelease assembleRelease
node tools/kr003/audit-build.mjs
node tools/validate.mjs
git diff --check
```

PowerShell tests use synthetic state and observer stubs only. CI's native Windows PowerShell job validates host-runtime compatibility, not ADB, MIUI or physical enforcement.
