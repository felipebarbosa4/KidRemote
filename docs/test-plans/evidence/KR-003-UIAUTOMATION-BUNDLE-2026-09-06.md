# KR-003 UiAutomation single-touch bundle

- **Goal:** Hand off exactly one independent input transport test on the Mi 8 with the current SIM-less configuration.
- **Context:** Shell input denial and the disabled SIM-gated switch are preserved in [configuration evidence](KR-003-MI8-INPUT-DENIAL-2026-09-06.md).
- **Constraints:** Owner-operated Windows ADB, no candidate arming, no Q7 execution, no setting change, no private output or qualification claim.
- **Done when:** A clean source commit, immutable hashes, passing build/security/runner checks and one exact operator command are recorded.

Source commit: `8b16c1b53e5c76c5303492d49f1ddba63a3bfbbd`.
Protocol: `KR003-UIAUTOMATION-TRANSPORT-PREFLIGHT`, runner version 1.
Directory: `C:\platform-tools\kr003-uiautomation-bundles\8b16c1b`.
Physical execution: **Not run**.

| File | Bytes | SHA-256 |
| --- | ---: | --- |
| `Test-KR003-UiAutomationTransport.ps1` | 9,351 | `ada30376495b33cafa7454505279d1aa05132f0ebdb2a8bfb8dc5d774ca6dde4` |
| `OracleTransport.psm1` | 2,559 | `01f9e6ad2de72dfea71f9a77b73cf15dc6701508cf647e63ac7344a1c9506fe5` |
| `Qualification.psm1` | 26,297 | `524cbf5f528e8ad88d0667a2aef1bd1f605331bc289cbdcb6e4f421bfede63b7` |
| `protocol.md` | 6,341 | `034c58d220dc42c979475afd32fdc2001fdadf0c1954dd4a3290a75f1c4eb6e7` |
| `input-probe.apk` | 2,542,746 | `1c859cc709cc8f2ef32333397be9d584405474ae93a77436c8f8e40e12f0fd43` |
| `ordinary-fixture.apk` | 2,556,059 | `223219c17a31439b52698e769bdf03ead0998bbbe8bbb5c1b0ff5be3cfaf21dc` |

`bundle.json` SHA-256: `eb736a469c0b7d1a02a733224cc516d3ac565caad35094b666ece98e36db9148`.
Every mounted payload was independently re-hashed after packaging. The fixture is unchanged from Q7; the unchanged candidate APK
`5b27c891fe155ee4d26e4da68f8323f178f7116e73d8097ce07199e5800e318b` is not installed or controlled by this bundle.

## Operator command

Keep the authorized Mi 8 connected, unlocked and hands off. Its disposable lab restriction must already be clear. Run once:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\platform-tools\kr003-uiautomation-bundles\8b16c1b\Test-KR003-UiAutomationTransport.ps1"
```

Allow about 10–20 seconds. The fixture opens, the probe injects one coordinate touch and the fixture counter is checked. No physical-response prompt
or checkpoint is required. Do not change the SIM-gated switch or another developer option for this test. Generated files are read directly from
`C:\platform-tools\kr003-uiautomation-transport` afterward; no manual log copying.

Success means only `PASSED_TRANSPORT_PREFLIGHT:FIXTURE_COUNTER_INCREMENTED_ONCE` with an accepted DOWN/UP, completed instrumentation result,
stable fixture process/coordinate, focus/resume and exactly one independent counter increment. A rejected injection, stale/malformed/missing finish
reply, focus/process change or wrong count stops immediately. Every outcome contributes zero Q7 samples.

## Validation and remaining gate

Local: 24/24 existing JVM tests; all three modules debug/release lint and assembly; merged-manifest/release-DEX isolation; 14/14 Node tests;
82 qualification, 104 finalization, 18 shell-transport and 61 UiAutomation PowerShell assertions; repository validation and whitespace checks passed.
PowerShell 7.6.5 was run from a temporary portable archive verified against the official release SHA-256, without host configuration changes.

CI for source `8b16c1b`: [run 34078820754](https://github.com/felipebarbosa4/KidRemote/actions/runs/34078820754) passed all three jobs, including native
Windows PowerShell 5.1 synthetic tests and all Android debug/release checks.
Synthetic results do not establish Mi 8 UiAutomation support or Accessibility-service non-interference. If transport passes, prepare a bounded
positive/blocked/service-continuity calibration before adopting a new Q7 transport. Monkey remains conditional on this probe failing.
The three-human-checkpoint constraint and all remaining KR-003 gates remain in force.
