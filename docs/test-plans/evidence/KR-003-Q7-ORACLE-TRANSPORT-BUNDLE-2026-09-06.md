# KR-003 Q7 oracle-transport bundle — 2026-09-06

- **Goal:** Hand off the smallest physical diagnostic that classifies Q7's rejected input operation without rerunning Q7.
- **Context:** Three preserved Q7 attempts stopped before ARM/sample 1 at the fixture's single unblocked `adb shell input tap`.
- **Constraints:** Exact immutable payload; fixture only; no candidate restriction, radio/settings/permission mutation, raw ADB output, qualification sample or KR-004 work.
- **Done when:** Exact source and payload hashes are verified, CI passes, and the owner has one command that produces a sanitized transport result.

## Immutable handoff

| Item | Value |
| --- | --- |
| Source commit | `95937b95d585b93f9878f55503f224c61c590a26` |
| Protocol | `KR003-Q7-ORACLE-TRANSPORT-PREFLIGHT` |
| Runner version | `1` |
| Windows directory | `C:\platform-tools\kr003-oracle-transport-bundles\95937b9` |
| `bundle.json` SHA-256 | `d65e22bf1922e8b9c04e2195d53a97c34b662eb8d2d75f3a13adce8f508fbb24` |
| Physical execution | **Not run** |

Verified payload:

| File | Bytes | SHA-256 |
| --- | ---: | --- |
| `Test-KR003-OracleTransport.ps1` | 8,252 | `14ff9d1b0f92e77d64fff506b44479fa23ab8c0d5de14aa9b45165629dbcb7ea` |
| `OracleTransport.psm1` | 1,402 | `8b0b6f0c4f1bb3e39fb38574c7e0a0cce25ce92eb0b5ac3402e48b72f128657d` |
| `Qualification.psm1` | 26,297 | `524cbf5f528e8ad88d0667a2aef1bd1f605331bc289cbdcb6e4f421bfede63b7` |
| `protocol.md` | 3,358 | `a760da7f8f2f04699d8c96561bdadc8fdeb00ce4ec665428d73180aec9ddf997` |
| `ordinary-fixture.apk` | 2,556,059 | `223219c17a31439b52698e769bdf03ead0998bbbe8bbb5c1b0ff5be3cfaf21dc` |

The bundle was produced from a clean exact source commit and then independently re-hashed in mounted Windows storage. It is separate from the
three failed Q7 run directories and does not modify them.

## Owner command

Keep the phone unlocked. Do not change any MIUI developer/security setting before this diagnostic. Run once in PowerShell:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\platform-tools\kr003-oracle-transport-bundles\95937b9\Test-KR003-OracleTransport.ps1"
```

The fixture should open briefly. No tap or response is required from the owner. The runner queries the sender-protected fixture state, attempts
exactly one tap at the fixture-provided test coordinate, checks for exactly one counter increment and stops in seconds. It does not arm KidRemote,
change radios, alter permissions/settings, clear app data or create a Q7 sample.

Possible results:

- `PASSED_TRANSPORT_PREFLIGHT:FIXTURE_COUNTER_INCREMENTED_ONCE`: input transport works; investigate why the earlier Q7 environment differed before rerunning Q7.
- `INVALID:ADB_OPERATION_REJECTED`: use the recorded `INPUT_TAP` exit code and coarse stderr class to determine whether the MIUI security switch is actually required.
- `FAILED:INPUT_NOT_DELIVERED`: ADB accepted the command but the independent fixture did not receive it; investigate coordinate/focus/input delivery without weakening Q7.

The generated evidence contains only fixed operation enums, exit codes, coarse stderr classes, numeric fixture counters and protocol/build hashes.
Raw stdout/stderr, package history, content, UI text, screenshots, accounts, serials and device identifiers are not persisted.

## Evidence boundary

This is an oracle-transport diagnostic, not an expiry, enforcement, latency or qualification pass. The MIUI `USB debugging (Security settings)`
requirement remains **UNSPECIFIED** until this result establishes the rejection class and the owner verifies the switch's current state if needed.
Q7 remains halted before sample 1; KR-003 remains open and KR-004 remains untouched.
