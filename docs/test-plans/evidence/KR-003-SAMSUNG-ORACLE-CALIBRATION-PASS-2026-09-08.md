# KR-003 Samsung active-oracle calibration PASS — 2026-09-08

- **Goal:** Preserve exactly what the runner-v5 physical calibration established on one Samsung configuration without converting the excluded sample into qualification or broader support evidence.
- **Context:** The owner ran immutable source `4690d3951d0952fefe43eab9de0799599c6ea903` once after the same configuration's fixture-only transport PASS and the retained earlier INVALID attempts.
- **Constraints:** Read directly from `/mnt/c`; preserve original files; retain only safe structured values and hashes; no raw command output, serial, account, content, screenshot, node text or package history; no cross-device inference, pooling, qualification execution or KR-004 work.
- **Done when:** Strict ingestion agrees with the console verdict; every requested technical/physical/cleanup/count sub-check is classified; captured metadata and owner labels remain distinct; only directly advanced matrix status is recorded.

## Source and verdict

- Windows directory: `C:\platform-tools\kr003-oracle-calibration\calibration-20260908-231756-97a0855b`
- Mounted directory: `/mnt/c/platform-tools/kr003-oracle-calibration/calibration-20260908-231756-97a0855b`
- Protocol: `KR003-GENERIC-ACTIVE-ORACLE-CALIBRATION`
- Runner source: `4690d3951d0952fefe43eab9de0799599c6ea903`, protocol version 5
- Started/ended: `2026-09-09T03:17:56.5882510Z` / `2026-09-09T03:18:52.8606146Z`
- Strict verdict: `PASSED_ORACLE_CALIBRATION_THIS_CONFIGURATION_ONLY:COMPLETED`
- Host diagnostic: stage `COMPLETED`, exception `NONE`, finalization `COMPLETED`, cleanup `VERIFIED`

`node tools/kr003/ingest.mjs calibration <directory>` independently returned the same PASS, one calibration sample, zero qualification samples, explicit physical agreement `PASS`, passed permission verification and `kr003Complete=false`.

## Captured configuration

| Source | Value |
| --- | --- |
| Captured manufacturer / model | `samsung` / `SM-X400` |
| Captured Android / API | `16` / `36` |
| Captured build / security patch | `BP4A.251205.006` / `2026-07-05` |
| Captured battery saver | `DISABLED` |
| Captured app standby | `ENABLED` |
| Captured adaptive/OEM battery management | **UNSPECIFIED** / **UNSPECIFIED** |
| Owner-provided labels | Galaxy Tab S10 Lite / One UI 8.5 |

The owner labels are not system-captured metadata and are not generalized to another product/build.

## Sub-check classification

| # | Sub-check | Result | Retained support |
| ---: | --- | --- | --- |
| 1 | Exact device metadata/configuration | **PASS** | All six required sanitized metadata fields captured as above |
| 2 | Transport provenance | **PASS** | Protocol `KR003-GENERIC-DEVICE-TRANSPORT-PREFLIGHT`; referenced `device.json` SHA-256 `e14837ade8cd72b48186ebc1bbdec439bb1ba1be263a8b6204696333db485ae7`, matching the preserved source-`5a46f75e3dad68ccbf520bce327a6d1f1c03c77c` transport PASS |
| 3 | Usage Access verification | **PASS** | `ENABLED`, source `CMD_APPOPS_GET_GET_USAGE_STATS`, parse `MODE_ALLOWED` |
| 4 | Accessibility enabled-state | **PASS** | `ENABLED`, source `SECURE_SETTINGS_CURRENT_USER_COMPONENT_NAME`, parse `GLOBAL_ENABLED_COMPONENT_MATCH_FULL` |
| 5 | Service heartbeat freshness | **PASS** | `FRESH` before ARM and after the blocked hold |
| 6 | Candidate health/eligibility | **PASS** | `HEALTHY` / `ELIGIBLE` |
| 7 | Fixture positive control | **PASS** | One pre-block input tap returned exit zero and incremented the independent fixture counter from 0 to 1 |
| 8 | ARM response/revision | **PASS** | Scalar schema-2 reply; revision `23`, armed, `remaining=10000`, unrestricted/unattached at ARM |
| 9 | Overlay/attachment verification | **PASS** | Revision 23 reached restriction + attachment + `APPLIED`; paired attachment latency `127 ms` |
| 10 | Blocked hold | **PASS** | `22,371 ms`, exceeding the required 10,000 ms minimum |
| 11 | Blocked-input denial oracle | **PASS** | 20 input operations returned exit zero; fixture taps remained `1` throughout the hold |
| 12 | Focus-regain oracle | **PASS** | Fixture lost focus once on attachment; focus-gain counter remained `1` with no regain during the hold |
| 13 | Owner physical agreement | **PASS** | Summary explicitly retains `PhysicalAgreement=PASS` after the continuous-visible-block prompt |
| 14 | CLEAR/cleanup | **PASS** | `CleanupVerified=true`, cleanup status `VERIFIED`; CLEAR response revision `24` |
| 15 | Final state | **PASS** | Final snapshot revision 24 was unarmed, unrestricted, unattached, `NOT_REQUIRED`, healthy and eligible |
| 16 | Calibration samples | **PASS: exactly 1 excluded** | One paired sample, `127 ms`; p50/p95/max of this one excluded sample are each 127 ms |
| 17 | Qualification samples | **PASS: exactly 0** | `QualificationSamples=0`; no attempt is a 100-cycle row |

The blocked input and focus outcomes come from the independent fixture state. Candidate telemetry corroborates attachment, revision, latency and continuity only.

## Artifact hashes

| Artifact | SHA-256 |
| --- | --- |
| `summary.json` | `c1119705a0bb30acbccc0caee6fb293815cfc3901a285fd346275321129f4a61` |
| `device.json` | `5e1c89c0cddcc8dc2b1b86bfe5b5e5ed2c61d4170d71318ceafc0c94906b6c23` |
| `permission-verification.json` | `2ac76b72a2d1028169f5b20e638e79991ccd6a60394adc6bb2b6187f6bfdea20` |
| `operations.json` | `167890169a66f3a1650172e7e7a1687f94d37a68b876b80bb67507c63a005543` |
| `fixture.jsonl` | `89df77e8fd941f0d4d1acdcebe4feb60318d78174d3fcdd54ed62b9881867c62` |
| `telemetry.jsonl` | `397b0a027e63647fd8f14706d29b603434f52b4dce94834389241f8428a30948` |
| `trace.jsonl` | `593a25822b55cea9da6623ff409eaa1657d700fba684c1980ec14aa6a2762817` |
| `verified-candidate.apk` | `5b27c891fe155ee4d26e4da68f8323f178f7116e73d8097ce07199e5800e318b` |
| `verified-ordinary-fixture.apk` | `223219c17a31439b52698e769bdf03ead0998bbbe8bbb5c1b0ff5be3cfaf21dc` |

All original mounted files remain unchanged.

## OBSERVED

- The top-level result and every table value above are retained in the sanitized evidence or independently derived from its numeric fixture/telemetry sequence.
- All 273 recorded ADB operations have exit code zero; the two APK pulls have safe stderr class `OTHER`, while all other operation records have `NONE`. Installed/pulled APK hashes match the calibration manifest.
- Candidate service continuity remained true; trace loss, eligibility loss, uncertainty and overlay removal during the hold remained false/zero.
- The runner changed neither network nor permissions and performed no destructive action.

## INFERRED

- Stable fixture tap/focus counters across the 20 successful input commands mean input did not reach or refocus the underlying ordinary fixture during this sampled hold. This supports only the defined active oracle; it is not a claim about every Android input path or rendering-only transient.
- Agreement between the independent fixture oracle, candidate telemetry and retained owner response makes the configuration-specific calibration PASS internally consistent.

## UNSPECIFIED / not established

- The calibration did not establish offline operation: it records `NetworkChanged=false`, and network availability was not an oracle.
- It did not establish a 100-sample p50/p95/max distribution, lifecycle/reboot/permission-revocation/tamper/battery survival, safe system surfaces, Play acceptance or production readiness.
- It cannot independently detect a rendering-only flash that neither changes focus nor leaks input.
- It does not apply to the Mi 8, another Samsung, another SM-X400 build/configuration, another Android 16 device or Android generally.

## Matrix disposition

- The configuration-specific **active-oracle calibration prerequisite** advances from Not run/INVALID to **PASS** for this exact captured Samsung configuration.
- Formal row **TIME-04** gains one excluded `127 ms` mechanism/hold observation but remains **open / not passed**: the required 100 fresh offline rows and p95 calculation do not exist.
- No PERM, lifecycle, tamper, safety, Play or production row advances. Existing transport provenance remains the earlier transport PASS, not a new row.

This PASS permits only preparation of an immutable configuration-bound qualification bundle. It does not authorize or execute that bundle.
