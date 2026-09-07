# KR-003 bounded Monkey transport bundle

- **Goal:** Hand off one fixture-only transport test after the measured UiAutomation denial.
- **Context:** [Original failure evidence](KR-003-UIAUTOMATION-DENIAL-2026-09-06.md) is preserved; Q7 is halted before sample 1.
- **Constraints:** No full Monkey driver, candidate control, settings/radio/permission changes, sensitive collection, SIM requirement or physical execution during preparation.
- **Done when:** Clean source, exact hashes, validation and one owner-operated command are recorded.

Source: `a10fd34043c0dac20c69a0558104e294a7dba243`.
Directory: `C:\platform-tools\kr003-monkey-bundles\a10fd34`.
Protocol: `KR003-MONKEY-TRANSPORT-PREFLIGHT`, runner version 1.
Physical execution: **Not run**. MIUI transport support and later candidate-service non-interference: **UNSPECIFIED**.

| File | SHA-256 |
| --- | --- |
| Test-KR003-MonkeyTransport.ps1 | `9f335eecffa9311563accb49b365d308ac70b4b9bdd7f7484e1867265e965c3a` |
| OracleTransport.psm1 | `b3a6d4a53d813e03e937c3f762343e88743045f29076f234255070d37f554e3f` |
| Qualification.psm1 | `524cbf5f528e8ad88d0667a2aef1bd1f605331bc289cbdcb6e4f421bfede63b7` |
| protocol.md | `ed25325ce858308e82f22b14d16b99d1e6c3b632748242b47b5b35e029173d48` |
| input-probe.apk | `a272ea3539af9b1872c79c97565e3174a52aae35ea16c448fe50e1b00831f6b7` |
| ordinary-fixture.apk | `223219c17a31439b52698e769bdf03ead0998bbbe8bbb5c1b0ff5be3cfaf21dc` |
| bundle.json | `cbd1f0996785f8444c6f150f9d030825db8c120f8e5106f0b6d3066ead7b9512` |

Every mounted payload was independently re-hashed. Candidate APK remains
`5b27c891fe155ee4d26e4da68f8323f178f7116e73d8097ce07199e5800e318b`; it is not installed, launched or controlled by this bundle.
Fixture APK is unchanged. Old bundles and raw evidence were not modified.

Local checks passed: 24 JVM tests; all 16 Node ingestion/security tests; 82 qualification, 18 original transport, 61 UiAutomation, 86 Monkey and
104 finalization PowerShell synthetic assertions; debug/release lint and assembly; all three modules' merged-manifest/release-DEX isolation;
repository validation and whitespace checks. These tests used no physical device.

[CI run 34080865388](https://github.com/felipebarbosa4/KidRemote/actions/runs/34080865388) passed on exact source
`a10fd34043c0dac20c69a0558104e294a7dba243`: repository/Node/Linux PowerShell, native Windows PowerShell, and Android debug/release jobs.

## Exact operator command

Phone connected/unlocked, existing lab restriction already clear, no changes to developer settings. Keep hands off the fixture.

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\platform-tools\kr003-monkey-bundles\a10fd34\Test-KR003-MonkeyTransport.ps1"
```

Normally approximately 10–25 seconds, no physical observation prompt, no calibration or Q7 sample. It opens the unchanged disposable fixture,
attempts one coordinate touch through the installed Monkey touch class in a separate shell process, checks exactly one counter increment and
stops. The uploaded temporary helper APK is removed by exact path and its absence verified; installed apps, evidence and app data are not deleted.
No radio/permission changes require restoration. See [protocol and source-reviewed limitations](../KR-003-MONKEY-TRANSPORT.md).

Evidence appears under `C:\platform-tools\kr003-monkey-transport`; the agent reads it directly through `/mnt/c`. No manual log copying.
PASS proves only unblocked input transport. FAIL/INVALID stops this branch; it must not trigger a Q7 retry, random Monkey sequence, guessed SIM-gate
bypass or gate reduction. Only a subsequent successful blocked-control/service-continuity calibration could justify changing Q7's transport.

KR-003 remains Open/In Progress; PR #16 draft/Open; KR-004 untouched. Broader physical, lifecycle, safety and Play-policy gates remain unsatisfied.
