# KR-003 qualification operator tooling

- **Goal:** One owner-run Windows command, reproducible evidence, and the minimum human input compatible with 100 genuine physical observations.
- **Context:** [Q5](../../docs/test-plans/evidence/KR-003-Q5-RECOVERY-2026-09-06.md) passed the final focused recovery route on one exact Mi 8/APK pair; Q6 runs the fresh offline qualification.
- **Constraints:** No Windows ADB execution from WSL; disposable debug APKs only; no automatic physical PASS, host repair, destructive test, production implementation or KR-004.
- **Done when:** An integrity-checked Q6 bundle records calibration, two safety checkpoints, 100 paired expiry observations, cleanup/restoration and a machine-verifiable summary.

## Build and package (agent / WSL)

Use the existing JDK 17 and Android SDK. Run repository, Node, PowerShell and Android checks, commit a clean source revision, then create a new directory:

```sh
node tools/kr003/package.mjs /mnt/c/platform-tools/kr003-qualification-bundles/NEW_UNIQUE_COMMIT_DIRECTORY
```

Packaging refuses a dirty tree or existing destination, rebuilds/tests/lints debug and release, audits merged permissions/release DEX, and hashes every payload. It also refuses candidate or fixture APK bytes that differ from the pair physically calibrated in Q5. Source commit identifies runner/protocol changes; `calibratedBy` identifies the prior physical APK calibration. No physical run occurs during packaging.

## Execute (owner / PowerShell)

Use the exact populated command in the latest bundle handoff:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\platform-tools\kr003-qualification-bundles\NEW_UNIQUE_COMMIT_DIRECTORY\Start-KR003.ps1" -OfflineNetwork
```

`-ExecutionPolicy Bypass` applies only to that process. Q6 requires `-OfflineNetwork` and rejects diagnostic/calibration-only modes. It journals original radio flags, disables enabled Wi-Fi/mobile data, obtains an explicit operator confirmation, and restores/read-backs each changed flag during independently guarded finalization. Keep only the authorized Mi 8 connected. The runner installs in place and pulls/hashes installed APKs; it never uninstalls, clears app data, grants permissions, reboots or repairs host/WSL state.

The full [Q6 contract](../../docs/test-plans/KR-003-Q6-QUALIFICATION.md) is bundled. Expected duration is 40–60 minutes. Keep the screen unlocked/interactive and watch every expiry. Enter P only after a visibly continuous ten-second restriction; F for flicker, disappearance, escape or unusable recovery; I if observation or eligibility was missed; Q to stop. Any non-P expiry stops and remains in the evidence—there is no replacement, resume or pooling.

Calibration and final safety each require a physical Home attempt, the calibrated Settings root → Digital Wellbeing blocked → one-button Settings recovery route, ordinary-app re-entry, and one real fixture tap after lab CLEAR. These observations remain separate and contribute zero expiry samples. The runner rejects recovery P until a fresh safe transition remains stable for ten seconds.

## Evidence and bailout

Every execution creates a new `C:\platform-tools\kr003-qualification\run-*` directory. It contains bundle/device/APK identity, prior/final metrics, calibration, attempt JSON/CSV, sanitized telemetry/trace, fixture counters, two safety and recovery journals, radio journals, sample-preserving bailout evidence and summaries. The agent reads it directly from `/mnt/c`; do not copy logs manually.

Normal finalization automatically invokes debug CLEAR and verifies the complete timing sample array is unchanged. If the terminal is forcibly interrupted or the phone remains trapped, run the bundle's separate bailout from a second PowerShell window:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\platform-tools\kr003-qualification-bundles\NEW_UNIQUE_COMMIT_DIRECTORY\Clear-KR003-Lab.ps1"
```

That command only queries and clears the disposable lab timer; it does not change data, installation, permissions or network and is not consumer recovery evidence. A hard host/power kill cannot guarantee `finally` or radio restoration, so preserve `network-original.json` for owner review.

After a run, ingest without modifying originals:

```sh
node tools/kr003/ingest.mjs qualification /mnt/c/platform-tools/kr003-qualification/ACTUAL_RUN_DIRECTORY
```

Exit zero means only `PASSED_THIS_CONFIGURATION_ONLY` for this exact offline Mi 8/APK with both safety checkpoints, verified bailout/restoration and clean finalization. It does not close KR-003, establish other devices, complete remaining matrix rows or prove Play acceptance.

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
