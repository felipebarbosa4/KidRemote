# KR-003 qualification operator tooling

- **Goal:** One owner-run Windows command, reproducible evidence, minimal repetitive interaction.
- **Context:** [Q4 repair calibration](../../docs/test-plans/KR-003-RECOVERY-REPAIR.md) follows the phase-local Q3 physical Settings/recovery failure.
- **Constraints:** No Windows ADB execution from WSL; debug disposable APKs only; no automatic physical PASS, host changes, destructive tests or KR-004.
- **Done when:** The diagnostic-only integrity-checked bundle retains one labelled recovery case and verifies the lab-only bailout.

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
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\platform-tools\kr003-qualification-bundles\NEW_UNIQUE_COMMIT_DIRECTORY\Start-KR003.ps1" -RecoveryDiagnostic
```

`-ExecutionPolicy Bypass` applies only to that PowerShell process; no permanent policy change is made. Q4 rejects `-OfflineNetwork` and
`-CalibrationOnly`: network state is not part of this diagnostic and no qualification path is available from its immutable bundle.
Keep only the intended authorized Mi 8 connected: `get-state` fails on ambiguous devices, and model/codename/API are checked before installation.
The runner installs in place and hashes pulled installed APKs; there is no uninstall fallback. Accept an OS installer prompt if it appears.
Permissions must already be enabled through the disclosed setup flow. Refusal/MIUI denial stops; the runner never grants permissions or escalates.

Q2 and Q3 physically failed Settings/recovery. Do not rerun them or start qualification. The next immutable bundle implements only the
[Q4 bounded recovery-launch calibration](../../docs/test-plans/KR-003-RECOVERY-REPAIR.md). Run it with `-RecoveryDiagnostic`; the bundle rejects other modes,
never starts the 100 rows and does not reset latency samples or change network state. Review its evidence before accepting or rejecting the repair.
Do not change the device/user/settings or switch to personal apps during the run. The fixture is a separate zero-permission disposable ordinary app.

## What the operator does

1. Keep the Mi 8 unlocked and visible. Watch one fresh expiry remain continuous for ten seconds, then report P/F/I.
2. `SETTINGS_ROOT`: tap the overlay Settings button once; report whether top-level Settings is usable.
3. `DIGITAL_WELLBEING_ATTEMPT`: tap only Digital Wellbeing & parental controls once; report whether that destination is usable.
4. `RECOVERY_BUTTON_ATTEMPT`: if the restriction overlay is visible, tap its Settings button exactly once, do not tap again, and watch whether usable top-level Settings remains for ten seconds.
5. The runner records `POST_RECOVERY_STATE`, automatically clears only the lab restriction, verifies all latency samples remain and exits.

Budget **4–7 minutes** including in-place install and responses (estimate, not measured). Do not press Home, explore other Settings destinations,
rerun a prompt or turn radios/permissions on or off. This run cannot start a qualification sample.

At each diagnostic prompt P = the named surface/result was usable, F = blocked/failed, I = uncertain/missed, and Q = stop into cleanup.
Do not press P for a screen you did not watch. Digital/recovery F is journalled and does not get replaced by a retry.

## Evidence and recovery

Each run creates a new `C:\platform-tools\kr003-qualification\run-*` directory with original/installed APK hashes, manifest, prior metrics,
one calibration expiry row, per-attempt JSON/CSV, fixture telemetry, typed traces, phase diagnostic, bailout record and summary. The agent reads it from `/mnt/c`.
No copying/log pasting, node/text/screenshot collection or broad dumpsys capture is needed.

The focused diagnostic captures the final state, then automatically clears only the lab timer and verifies latency samples are unchanged.
Its bundle also includes `Clear-KR003-Lab.ps1` for a forcibly interrupted/trapped terminal. Neither bailout is consumer recovery evidence.
Q exits through automatic CLEAR. Avoid closing/killing the terminal: a hard interruption cannot run `finally`; use the bundled bailout script from
a second PowerShell window if needed. No data clear, uninstall, force-stop, permission, network, reboot or safe-mode command runs.
Reporting/cleanup cannot replace physical results. Exit code 0 means **diagnostic evidence and bailout completed only**, never physical/product PASS.
Code 2 means inspect the summary and `diagnostic-bailout.json`.
Never close KR-003 based on that exit code: [remaining gates](../../docs/test-plans/KR-003-REMAINING.md) still apply.

```sh
node tools/kr003/ingest.mjs diagnostic /mnt/c/platform-tools/kr003-qualification/ACTUAL_RUN_DIRECTORY
```

The ingester checks protocol/mode, ordered non-overlapping phase floors, allowed physical results, separate coarse oracles and bailout safety fields;
it does not generate observer results. Retain failures and exact originals. Generated APKs and raw output directories are not automatically committed.

## Local test commands

```sh
node --test tools/kr003/*.test.mjs
pwsh -NoProfile -File tools/kr003/Qualification.Tests.ps1
pwsh -NoProfile -File tools/kr003/Runner.Tests.ps1
node tools/validate.mjs
node tools/kr003/audit-build.mjs
git diff --check
```

PowerShell tests execute synthetic state/observer inputs, including 100 scripted successful rows, failure rejection and reversible radio command
selection. Finalization tests execute the actual runner functions with device calls stubbed, covering calibration/zero rows, interruption, sample 1,
partial sets, 100 rows, writer failures, independent radio restoration, phase-local recovery, partial journalling and sample-preserving bailout.
Those are **not physical trials**.
CI also runs finalization tests using Windows PowerShell; this validates host-runtime compatibility, not Windows ADB or MIUI behaviour.
