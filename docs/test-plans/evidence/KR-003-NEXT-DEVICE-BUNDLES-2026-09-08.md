# KR-003 generic next-device bundles — 2026-09-08

- **Goal:** Publish a transport-first handoff for one newly authorized Android configuration, followed only on transport PASS by a bounded active-oracle calibration.
- **Context:** Shell input, UiAutomation and bounded Monkey input are all denied on the preserved Mi 8 configuration. The expected Samsung tablet's exact model, Android/API/build/power configuration and transport capability are **UNSPECIFIED** until owner execution.
- **Constraints:** Repository packaging only; no device command or physical claim; no Mi 8 change; no cross-configuration evidence transfer; no candidate in the first bundle; no timer, Accessibility setup, network change, destructive action, qualification sample or KR-004 work.
- **Done when:** Both clean-source bundles are independently hash-verified, exact owner commands and stop criteria are recorded, and exact-source automated checks pass.

## Immutable transport handoff

| Item | Value |
| --- | --- |
| Source commit | `bbdaefcdcf6393d21f6541e6dbba02d0a702b34d` |
| Protocol | `KR003-GENERIC-DEVICE-TRANSPORT-PREFLIGHT` |
| Runner version | `1` |
| Windows directory | `C:\platform-tools\kr003-device-preflight-bundles\bbdaefc` |
| `bundle.json` SHA-256 | `3f9a385ecfe4b238c773e927d9bd09ff705372c3780bfd6a24f1d998953ee3c9` |
| Fixture SHA-256 | `223219c17a31439b52698e769bdf03ead0998bbbe8bbb5c1b0ff5be3cfaf21dc` |
| Candidate included | `false` |
| Physical execution | **Not run** |

Verified payload:

| File | Bytes | SHA-256 |
| --- | ---: | --- |
| `Test-KR003-DeviceTransport.ps1` | 11,802 | `9fa3d5aa0052efbabbf958319efa768840ef7548400a457fc3b6166bdbb40f75` |
| `DevicePreflight.psm1` | 6,366 | `22b5399eb59d83c51e82f1668325d8e347bbdd94f470b2721fee0ed850e30188` |
| `OracleTransport.psm1` | 3,364 | `b3a6d4a53d813e03e937c3f762343e88743045f29076f234255070d37f554e3f` |
| `Qualification.psm1` | 26,297 | `524cbf5f528e8ad88d0667a2aef1bd1f605331bc289cbdcb6e4f421bfede63b7` |
| `protocol.md` | 5,250 | `0622567436b31601121f27a837290dd38d63cbc56c0b15490d348bb9338fb04e` |
| `ordinary-fixture.apk` | 2,556,059 | `223219c17a31439b52698e769bdf03ead0998bbbe8bbb5c1b0ff5be3cfaf21dc` |

Connect exactly one authorized, unlocked device and accept its ADB authorization prompt if shown. Run once in Windows PowerShell:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\platform-tools\kr003-device-preflight-bundles\bbdaefc\Test-KR003-DeviceTransport.ps1"
```

Expected duration after ADB authorization is about one minute. The runner verifies authorization without retaining the ADB identifier, records only the approved sanitized metadata, installs and hash-verifies the independent fixture, foregrounds it, reads its own probe coordinate/counter, attempts exactly one shell tap, and stops.

- **PASS — `PASSED_TRANSPORT_PREFLIGHT:FIXTURE_COUNTER_INCREMENTED_ONCE`:** preserve the printed evidence directory; transport alone passed for the recorded configuration.
- **FAIL — `FAIL:INPUT_NOT_DELIVERED`:** preserve the evidence and stop before installing the candidate.
- **INVALID:** preserve the evidence and stop. Authorization, metadata, hashes, fixture state, command acceptance or evidence integrity was not established.

## Conditional calibration handoff

Do not use this bundle unless the generic transport result above is PASS and its evidence directory is available.

| Item | Value |
| --- | --- |
| Source commit | `bbdaefcdcf6393d21f6541e6dbba02d0a702b34d` |
| Protocol | `KR003-GENERIC-ACTIVE-ORACLE-CALIBRATION` |
| Runner version | `1` |
| Windows directory | `C:\platform-tools\kr003-oracle-calibration-bundles\bbdaefc` |
| `bundle.json` SHA-256 | `d4383e3059e4a4053cfb89573641ab97cc791cf32a2277cb0437fdb7861ed53b` |
| Candidate SHA-256 | `5b27c891fe155ee4d26e4da68f8323f178f7116e73d8097ce07199e5800e318b` |
| Fixture SHA-256 | `223219c17a31439b52698e769bdf03ead0998bbbe8bbb5c1b0ff5be3cfaf21dc` |
| Qualification samples | `0` |
| Physical execution | **Not run** |

Verified payload:

| File | Bytes | SHA-256 |
| --- | ---: | --- |
| `Test-KR003-OracleCalibration.ps1` | 20,907 | `352c37c53298a0a15c9289de3baee290feb3f5c06aaab7e02cdfa696930c91c3` |
| `DevicePreflight.psm1` | 6,366 | `22b5399eb59d83c51e82f1668325d8e347bbdd94f470b2721fee0ed850e30188` |
| `OracleTransport.psm1` | 3,364 | `b3a6d4a53d813e03e937c3f762343e88743045f29076f234255070d37f554e3f` |
| `Qualification.psm1` | 26,297 | `524cbf5f528e8ad88d0667a2aef1bd1f605331bc289cbdcb6e4f421bfede63b7` |
| `protocol.md` | 3,452 | `138db6bfe4541df30b095ce44a00bc49e0ad1f36320323a9ed7b0166ccf40a5a` |
| `candidate.apk` | 2,675,201 | `5b27c891fe155ee4d26e4da68f8323f178f7116e73d8097ce07199e5800e318b` |
| `ordinary-fixture.apk` | 2,556,059 | `223219c17a31439b52698e769bdf03ead0998bbbe8bbb5c1b0ff5be3cfaf21dc` |

Replace `ACTUAL_DEVICE_DIRECTORY` with the exact directory printed by the successful transport command, then run in an interactive Windows PowerShell window:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\platform-tools\kr003-oracle-calibration-bundles\bbdaefc\Test-KR003-OracleCalibration.ps1" -TransportEvidence "C:\platform-tools\kr003-device-preflight\ACTUAL_DEVICE_DIRECTORY"
```

Allow roughly three to seven minutes, including owner permission setup and one agreement response. The runner verifies the transport evidence and exact APKs before installing the candidate. It asks the owner to grant Usage Access and enable the disposable Accessibility service; it does not change either permission. It performs one unblocked control, one blocked hold, service-continuity checks and one P/F/I visible agreement check, then performs sample-preserving cleanup and stops before 100 samples.

- **PASS — `PASSED_ORACLE_CALIBRATION_THIS_CONFIGURATION_ONLY:COMPLETED`:** preserve evidence. Prepare and review a new qualification bundle mapped to the exact configuration; do not count the calibration sample among the 100.
- **FAIL:** preserve evidence and stop before qualification. A required technical/visible/cleanup control failed.
- **INVALID:** preserve evidence and stop before qualification. Required transport, configuration, permission, correlation or observation evidence was unavailable or uncertain.

## Verification and evidence boundary

Both bundles were created from the clean exact commit and then independently checked: every manifest-listed SHA-256 passed, every copied runner/module/protocol/APK matched its repository build byte-for-byte, and the fixture/candidate hashes remained the reviewed Q7/Q5 hashes. [Exact-source CI run 34189822315](https://github.com/felipebarbosa4/KidRemote/actions/runs/34189822315) passed repository/Node/PowerShell and Android debug/release jobs. CI device calls were synthetic or stubbed.

No physical device command was run while preparing either bundle. Samsung metadata, transport and calibration remain **UNSPECIFIED**. A future result belongs only to its recorded API/OEM/build/power/permission configuration and does not extend Mi 8, Pixel, another Samsung build or another OEM evidence. The existing 100-cycle, remaining lifecycle/safety/device and external Play gates stay open.
