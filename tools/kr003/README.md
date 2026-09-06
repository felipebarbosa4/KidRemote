# KR-003 qualification operator tooling

- **Goal:** One owner-run Windows command, reproducible evidence, minimal repetitive interaction.
- **Context:** [Contract KR003-Q1](../../docs/test-plans/KR-003-QUALIFICATION.md) follows the completed ten-cycle Mi 8 checkpoint.
- **Constraints:** No Windows ADB execution from WSL; debug disposable APKs only; no automatic physical PASS, host changes, destructive tests or KR-004.
- **Done when:** The integrity-checked bundle executes calibration then 100 independent paired observations or stops with intact failure evidence.

## Build and prepare (agent / WSL)

Use the existing JDK 17 and Android SDK environment. Run repository validation, Node tests and PowerShell synthetic tests. Commit first, then:

```sh
node tools/kr003/package.mjs /mnt/c/platform-tools/kr003-qualification-bundles/NEW_UNIQUE_COMMIT_DIRECTORY
```

The parent directory must exist. The destination must be new; nothing is overwritten. Packaging rebuilds/tests/lints both Android variants,
audits actual merged permissions/release DEX and produces candidate/fixture APKs, runner/module, protocol and `bundle.json` with SHA-256 identities.
Source commit is the clean build commit, not a later documentation-only handoff commit. No physical run occurs during packaging.

## Execute (owner / PowerShell)

Use the exact populated command in the latest handoff, of this form:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\platform-tools\kr003-qualification-bundles\NEW_UNIQUE_COMMIT_DIRECTORY\Start-KR003.ps1" -OfflineNetwork
```

`-ExecutionPolicy Bypass` applies only to that PowerShell process; no permanent policy change is made. `-OfflineNetwork` opts into reversible
Wi-Fi/mobile-data changes for this authorized lab run, not a WSL/host change. Omit it only for an intentionally online-only investigation.
Keep only the intended authorized Mi 8 connected: `get-state` fails on ambiguous devices, and model/codename/API are checked before installation.
The runner installs in place and hashes pulled installed APKs; there is no uninstall fallback. Accept an OS installer prompt if it appears.
Permissions must already be enabled through the disclosed setup flow. Refusal/MIUI denial stops; the runner never grants permissions or escalates.

The new receiver's compatibility with MIUI is not yet physically verified. Preflight and calibration catch unsupported behaviour before 100 trials.
Do not change the device/user/settings or switch to personal apps during the run. The fixture is a separate zero-permission disposable ordinary app.

## What the operator does

1. Keep the Mi 8 unlocked and visible. Confirm once that disabled Wi-Fi/mobile data leaves no other Internet connection.
2. Watch one calibration expiry and at least ten continuous blocked seconds; press **P** only after the prompt. A missing observation is **I**, not P.
3. During the calibration checklist, physically press Home, verify it remains blocked, tap **Open device settings**, and verify Settings is usable.
   One P confirms those two observed outcomes. The runner then opens the fixture: confirm restricted re-entry with P. After automatic Clear, tap
   **Test ordinary use** once; the fixture records that physical touch itself.
4. Watch each of 100 new expiries and ten seconds of persistent restriction; one **P** per successful observation. No repeated timer/navigation taps.
5. Repeat the recovery checklist after sample 100. No Home/Settings sequence is required in the other 99 samples.

At any time F = visible failure, I = invalid/missed observation, Q = stop. At prompts F/I opens a single-digit reason menu. Early P keys are discarded.
Do not press P for a screen you did not watch. Every failure/invalid/interrupted attempt is preserved; the runner stops, never substitutes a retry.
The minimum countdown/hold duration is about 34 minutes (101 ×20 seconds), plus ADB and responses: budget **45–60 minutes**, an estimate until measured.

## Evidence and recovery

Each run creates a new `C:\platform-tools\kr003-qualification\run-*` directory with original/installed APK hashes, manifest, prior metrics,
calibration, per-attempt JSON/CSV, fixture telemetry, typed traces, final metrics, safety records and summary. The agent reads it from `/mnt/c`.
No copying/log pasting, node/text/screenshot collection or broad dumpsys capture is needed.

Failures preserve the current restriction for investigation; the designated Settings button remains the recovery route. Q exits safely and attempts
radio restoration. Avoid closing/killing the terminal: a hard interruption cannot run `finally`. `network-original.json` and `network-touched.json`
preserve the exact radio flags for owner-assisted recovery if restoration fails. No data clear, uninstall, force-stop, reboot or safe-mode command runs.
Exit code 0 means this configuration's offline qualification succeeded; code 2 means inspect the summary (including online-only, invalid or failure).
Never close KR-003 based on that exit code: [remaining gates](../../docs/test-plans/KR-003-REMAINING.md) still apply.

```sh
node tools/kr003/ingest.mjs qualification /mnt/c/platform-tools/kr003-qualification/ACTUAL_RUN_DIRECTORY
```

The ingester independently checks attempt/revision uniqueness, physical/software pairing, hold duration and statistics; it does not generate observer
results. Retain failures and exact originals. Generated APKs and raw output directories are not automatically committed or uploaded.

## Local test commands

```sh
node --test tools/kr003/*.test.mjs
pwsh -NoProfile -File tools/kr003/Qualification.Tests.ps1
node tools/validate.mjs
node tools/kr003/audit-build.mjs
git diff --check
```

PowerShell tests execute synthetic state/observer inputs, including 100 scripted successful rows, failure rejection and reversible radio command
selection. Those are **not physical trials**. Linux PowerShell parser/tests are not Windows/MIUI execution evidence. CI runs the same checks.
