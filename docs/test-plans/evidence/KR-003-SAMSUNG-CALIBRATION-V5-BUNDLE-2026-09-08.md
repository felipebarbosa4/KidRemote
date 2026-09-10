# KR-003 Samsung calibration runner-v5 bundle — 2026-09-08

- **Goal:** Publish one immutable calibration-only bundle that corrects runner-v4's deterministic post-ARM host variable alias and rejects malformed ARM reply shapes without changing the candidate or evidence gates.
- **Context:** Four source-`af723c5` attempts independently returned `INVALID:HOST_EXCEPTION` at `ARM` / `PROPERTY_NOT_FOUND_EXCEPTION` after ARM reply capture and before revision assignment; cleanup verified each time.
- **Constraints:** Exact unchanged Q5 candidate and independent fixture; runner-only change; no raw exception/command output, stack, serial, account/content/history, screenshot, permission mutation, Samsung workaround, enforcement/oracle change, qualification loop, production code or KR-004 work.
- **Done when:** Clean source and every payload hash are pinned; exact-source CI passes PowerShell 7 and native Windows PowerShell 5.1; the generated bundle matches source, passes the static safety scan and executes its redirected-input pre-device stop under Windows PowerShell 5.1; one future command is recorded; physical execution remains Not run.

## Immutable handoff

| Item | Value |
| --- | --- |
| Source commit | `4690d3951d0952fefe43eab9de0799599c6ea903` |
| Protocol / runner | `KR003-GENERIC-ACTIVE-ORACLE-CALIBRATION` / `5` |
| Windows directory | `C:\platform-tools\kr003-oracle-calibration-bundles\4690d39` |
| `bundle.json` SHA-256 | `8599225eb453ceaa391f9aa2aea30cc6f04e1a2e450b98a39ec7a03c6ae216fd` |
| Candidate SHA-256 | `5b27c891fe155ee4d26e4da68f8323f178f7116e73d8097ce07199e5800e318b` |
| Fixture SHA-256 | `223219c17a31439b52698e769bdf03ead0998bbbe8bbb5c1b0ff5be3cfaf21dc` |
| Calibration / qualification maximum | one excluded calibration / `0` qualification samples |
| Physical execution | **Not run** |

| Payload | SHA-256 |
| --- | --- |
| `Test-KR003-OracleCalibration.ps1` | `5f9a28650fe519062cd78493fea76f8cd02e58fdf47b040c9f161484bc882e63` |
| `CalibrationHost.psm1` | `bd0b39e4f191dcaa6221a731b56c559d788d710d646f49016f809106ac6c749e` |
| `DevicePreflight.psm1` | `e0d77b65b7d5ea3e8f26245247ba33fadcf985b11af43aa0b2d032375f5449d3` |
| `OracleTransport.psm1` | `b3a6d4a53d813e03e937c3f762343e88743045f29076f234255070d37f554e3f` |
| `Qualification.psm1` | `7c099bac9c0ac710a94d54d5f664435c70c13418aa319a87d396e1e7c6f62ffa` |
| `protocol.md` | `dc4575165cf9e17055fe46bf97e09d578c8cc031f3705abba7ba0c38483d1186` |
| `candidate.apk` | `5b27c891fe155ee4d26e4da68f8323f178f7116e73d8097ce07199e5800e318b` |
| `ordinary-fixture.apk` | `223219c17a31439b52698e769bdf03ead0998bbbe8bbb5c1b0ff5be3cfaf21dc` |

All eight manifest payload hashes were independently re-read. All five PowerShell payloads and `protocol.md` match source commit `4690d39`
byte-for-byte. The candidate and fixture hashes are unchanged from runner-v4 and the preceding physical records.

## Bounded correction

The entrypoint no longer defines the unused `$script:Armed` flag. The ARM reply is held in `$armReply`, and
`Get-KRCalibrationArmRevision` requires a scalar object containing `revision`, `armed` and `remaining`; a missing/null/non-numeric revision or
array-shaped reply stops with a typed `INVALID:ARM_REPLY_*` result. The existing `Convert-KRReply` full-schema/type validation and fresh-arm
checks remain. Permission verification, ARM behavior, ten-second hold, attachment/fixture oracle, owner prompt, cleanup, primary-result
preservation and all fail-closed gates are unchanged.

## Verification

- Four mounted runner-v4 directories passed strict independent ingestion; each remains zero-sample `INVALID:HOST_EXCEPTION`.
- 465 assertions passed across nine local native Windows PowerShell `5.1.26100.9168` suites. New coverage reproduces the exact same-scope
  `PropertyNotFoundStrict`, attributes it to ARM, preserves the primary result through verified cleanup/finalization, extracts the scalar physical
  reply revision, and rejects missing, null, non-numeric, one-element-array and multi-element-array reply shapes.
- 20 Node evidence/security tests passed, including the typed v4 ARM/zero-sample ingestion shape.
- JVM `24/24`, all six debug/release merged-permission/receiver/release-DEX audits, Gradle unit/lint/build, repository validation and
  `git diff --check` passed.
- Exact-source [CI run 34305581473](https://github.com/felipebarbosa4/KidRemote/actions/runs/34305581473) passed all three jobs. The actual
  bundle-shaped entrypoint regression ran under PowerShell `7.6.5` and native Windows PowerShell `5.1.26100.33296` without a device command.
- The final mounted bundle passed the reserved-variable scan across all five PowerShell files and the actual redirected-input entrypoint test under
  native Windows PowerShell `5.1.26100.9168`; it stopped before output creation, bundle access or ADB.

These are host/build results, not physical Samsung enforcement, calibration PASS, qualification evidence or Play approval.

## Exact future one-run command

With only the exact authorized Samsung SM-X400 connected, unlocked and interactive, and only when the owner elects to resume physical calibration:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\platform-tools\kr003-oracle-calibration-bundles\4690d39\Test-KR003-OracleCalibration.ps1" -TransportEvidence "C:\platform-tools\kr003-device-preflight\device-20260908-092640-d3b5053b"
```

Do not change or auto-grant permissions. Keep Usage Access and the disposable Accessibility service enabled. During the single physical agreement
prompt, observe the full blocked hold and press `P` only for continuous visible restriction with no ordinary use/flicker, `F` for visible failure,
or `I` if missed/uncertain. Preserve the resulting directory and stop. Do not begin 100 samples or KR-004.
