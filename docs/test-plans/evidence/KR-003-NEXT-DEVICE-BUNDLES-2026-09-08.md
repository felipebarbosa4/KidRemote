# KR-003 generic next-device bundles — 2026-09-08

- **Goal:** Publish a transport-first handoff for one newly authorized Android configuration, followed only on transport PASS by a bounded active-oracle calibration.
- **Context:** Shell input, UiAutomation and bounded Monkey input are all denied on the preserved Mi 8 configuration. This file preserves the source-`5a46f75` handoff later executed on the Samsung SM-X400; transport passed and three v1 calibrations stopped INVALID.
- **Constraints:** Repository packaging only; no device command or physical claim; no Mi 8 change; no cross-configuration evidence transfer; no candidate in the first bundle; no timer, Accessibility setup, network change, destructive action, qualification sample or KR-004 work.
- **Done when:** Both clean-source bundles are independently hash-verified, exact owner commands and stop criteria are recorded, and exact-source automated checks pass.

The initial `bbdaefc` bundles were never run and are preserved in their original directories. A synthetic no-delivery check then found a
`FAIL`/`FAILED` ingestion mismatch. Source `5a46f75` fixes and tests that evidence path; the new directories and hashes below supersede the initial
handoff. Do not use the `bbdaefc` directories.

## Immutable transport handoff

| Item | Value |
| --- | --- |
| Source commit | `5a46f75e3dad68ccbf520bce327a6d1f1c03c77c` |
| Protocol | `KR003-GENERIC-DEVICE-TRANSPORT-PREFLIGHT` |
| Runner version | `1` |
| Windows directory | `C:\platform-tools\kr003-device-preflight-bundles\5a46f75` |
| `bundle.json` SHA-256 | `c2deacd58738e9969a1cc6712cf122af892437711f589907574c484185dd5721` |
| Fixture SHA-256 | `223219c17a31439b52698e769bdf03ead0998bbbe8bbb5c1b0ff5be3cfaf21dc` |
| Candidate included | `false` |
| Physical execution | **PASS** — `device-20260908-092640-d3b5053b` |

Verified payload:

| File | Bytes | SHA-256 |
| --- | ---: | --- |
| `Test-KR003-DeviceTransport.ps1` | 11,802 | `9fa3d5aa0052efbabbf958319efa768840ef7548400a457fc3b6166bdbb40f75` |
| `DevicePreflight.psm1` | 6,362 | `71d95e5040dece772e6d82dfd65c4b0debc06ada247d631546b255cbb3325efe` |
| `OracleTransport.psm1` | 3,364 | `b3a6d4a53d813e03e937c3f762343e88743045f29076f234255070d37f554e3f` |
| `Qualification.psm1` | 26,297 | `524cbf5f528e8ad88d0667a2aef1bd1f605331bc289cbdcb6e4f421bfede63b7` |
| `protocol.md` | 5,248 | `dc931a91cf075b6fa0353ec6464c8590bcf1c262125d75fe8042ca122ecfb798` |
| `ordinary-fixture.apk` | 2,556,059 | `223219c17a31439b52698e769bdf03ead0998bbbe8bbb5c1b0ff5be3cfaf21dc` |

Connect exactly one authorized, unlocked device and accept its ADB authorization prompt if shown. Run once in Windows PowerShell:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\platform-tools\kr003-device-preflight-bundles\5a46f75\Test-KR003-DeviceTransport.ps1"
```

Expected duration after ADB authorization is about one minute. The runner verifies authorization without retaining the ADB identifier, records only the approved sanitized metadata, installs and hash-verifies the independent fixture, foregrounds it, reads its own probe coordinate/counter, attempts exactly one shell tap, and stops.

- **PASS — `PASSED_TRANSPORT_PREFLIGHT:FIXTURE_COUNTER_INCREMENTED_ONCE`:** preserve the printed evidence directory; transport alone passed for the recorded configuration.
- **FAIL — `FAIL:INPUT_NOT_DELIVERED`:** preserve the evidence and stop before installing the candidate.
- **INVALID:** preserve the evidence and stop. Authorization, metadata, hashes, fixture state, command acceptance or evidence integrity was not established.

## Executed v1 calibration handoff

Do not use this bundle unless the generic transport result above is PASS and its evidence directory is available.

| Item | Value |
| --- | --- |
| Source commit | `5a46f75e3dad68ccbf520bce327a6d1f1c03c77c` |
| Protocol | `KR003-GENERIC-ACTIVE-ORACLE-CALIBRATION` |
| Runner version | `1` |
| Windows directory | `C:\platform-tools\kr003-oracle-calibration-bundles\5a46f75` |
| `bundle.json` SHA-256 | `cf619b72543af7f43902d1204a8ee24750135bac50dd3f85d7436d281e913ccc` |
| Candidate SHA-256 | `5b27c891fe155ee4d26e4da68f8323f178f7116e73d8097ce07199e5800e318b` |
| Fixture SHA-256 | `223219c17a31439b52698e769bdf03ead0998bbbe8bbb5c1b0ff5be3cfaf21dc` |
| Qualification samples | `0` |
| Physical execution | **Three INVALID attempts** — runner Accessibility state not verified |

Verified payload:

| File | Bytes | SHA-256 |
| --- | ---: | --- |
| `Test-KR003-OracleCalibration.ps1` | 20,907 | `352c37c53298a0a15c9289de3baee290feb3f5c06aaab7e02cdfa696930c91c3` |
| `DevicePreflight.psm1` | 6,362 | `71d95e5040dece772e6d82dfd65c4b0debc06ada247d631546b255cbb3325efe` |
| `OracleTransport.psm1` | 3,364 | `b3a6d4a53d813e03e937c3f762343e88743045f29076f234255070d37f554e3f` |
| `Qualification.psm1` | 26,297 | `524cbf5f528e8ad88d0667a2aef1bd1f605331bc289cbdcb6e4f421bfede63b7` |
| `protocol.md` | 3,452 | `138db6bfe4541df30b095ce44a00bc49e0ad1f36320323a9ed7b0166ccf40a5a` |
| `candidate.apk` | 2,675,201 | `5b27c891fe155ee4d26e4da68f8323f178f7116e73d8097ce07199e5800e318b` |
| `ordinary-fixture.apk` | 2,556,059 | `223219c17a31439b52698e769bdf03ead0998bbbe8bbb5c1b0ff5be3cfaf21dc` |

Replace `ACTUAL_DEVICE_DIRECTORY` with the exact directory printed by the successful transport command, then run in an interactive Windows PowerShell window:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\platform-tools\kr003-oracle-calibration-bundles\5a46f75\Test-KR003-OracleCalibration.ps1" -TransportEvidence "C:\platform-tools\kr003-device-preflight\ACTUAL_DEVICE_DIRECTORY"
```

Allow roughly three to seven minutes, including owner permission setup and one agreement response. The runner verifies the transport evidence and exact APKs before installing the candidate. It asks the owner to grant Usage Access and enable the disposable Accessibility service; it does not change either permission. It performs one unblocked control, one blocked hold, service-continuity checks and one P/F/I visible agreement check, then performs sample-preserving cleanup and stops before 100 samples.

- **PASS — `PASSED_ORACLE_CALIBRATION_THIS_CONFIGURATION_ONLY:COMPLETED`:** preserve evidence. Prepare and review a new qualification bundle mapped to the exact configuration; do not count the calibration sample among the 100.
- **FAIL:** preserve evidence and stop before qualification. A required technical/visible/cleanup control failed.
- **INVALID:** preserve evidence and stop before qualification. Required transport, configuration, permission, correlation or observation evidence was unavailable or uncertain.

## Verification and evidence boundary

Both current bundles were created from the clean exact commit and then independently checked: every manifest-listed SHA-256 passed, every copied runner/module/protocol/APK matched its repository build byte-for-byte, and the fixture/candidate hashes remained the reviewed Q7/Q5 hashes. [Exact-source CI run 34190844982](https://github.com/felipebarbosa4/KidRemote/actions/runs/34190844982) covers repository/Node/PowerShell and Android debug/release jobs. CI device calls are synthetic or stubbed.

No physical device command was run while preparing either bundle. The owner later ran them: the Samsung SM-X400 transport passed, while three v1
calibrations remained INVALID with zero samples. See [the ingested evidence and verifier analysis](KR-003-SAMSUNG-TRANSPORT-CALIBRATION-2026-09-08.md).
A [corrected v2 calibration handoff](KR-003-SAMSUNG-CALIBRATION-V2-BUNDLE-2026-09-08.md) is recorded separately; these v1 runs and bundle hashes remain immutable. No result extends Mi 8, Pixel,
another Samsung build or another OEM evidence. The 100-cycle, remaining lifecycle/safety/device and external Play gates stay open.
