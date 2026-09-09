# KR-003 Samsung runner-v4 ARM host exceptions — 2026-09-08

- **Goal:** Preserve and compare four independent runner-v4 Samsung calibration attempts without converting host exceptions into enforcement or qualification evidence.
- **Context:** The owner invoked exact source `af723c5a7af530a2c694e2749c533de1e18f4cab`, runner protocol 4, four times on the transport-approved Samsung SM-X400 configuration.
- **Constraints:** Direct `/mnt/c` ingestion; every directory remains separate and immutable; retain only safe structured fields and hashes; no raw command/exception output, stack, serial, account/content/history or screenshot; no pooling, replacement, physical rerun, 100-cycle qualification or KR-004 work.
- **Done when:** Each directory passes strict ingestion; its terminal host record, completed device operations, ARM boundary and cleanup are explicit; OBSERVED, INFERRED and UNSPECIFIED remain separate; the deterministic runner defect is fixed and tested without advancing a physical matrix row.

## Four independent records

All four strict `ingest.mjs calibration` reads returned source `af723c5a7af530a2c694e2749c533de1e18f4cab`, `INVALID:HOST_EXCEPTION`, zero calibration samples, zero qualification samples and `kr003Complete=false`.

| Run directory | Summary state / revision | Host diagnostic | Permission / positive control | ARM device record | Downstream protocol | Finalization / cleanup |
| --- | --- | --- | --- | --- | --- | --- |
| `calibration-20260908-223757-f4dc0d8b` | `INVALID:HOST_EXCEPTION`; `Revision=null` | `ARM`; `PROPERTY_NOT_FOUND_EXCEPTION`; primary `INVALID:HOST_EXCEPTION` | passed / `true` | exit 0; reply revision 11, armed, 10,000 ms; follow-up state still armed | attachment verification, hold, denial oracle and prompt not started | `COMPLETED` / `VERIFIED`; CLEAR reply revision 12, released |
| `calibration-20260908-223820-98dc0663` | `INVALID:HOST_EXCEPTION`; `Revision=null` | `ARM`; `PROPERTY_NOT_FOUND_EXCEPTION`; primary `INVALID:HOST_EXCEPTION` | passed / `true` | exit 0; reply revision 14, armed, 10,000 ms; follow-up state still armed | attachment verification, hold, denial oracle and prompt not started | `COMPLETED` / `VERIFIED`; CLEAR reply revision 15, released |
| `calibration-20260908-223851-a15b8d45` | `INVALID:HOST_EXCEPTION`; `Revision=null` | `ARM`; `PROPERTY_NOT_FOUND_EXCEPTION`; primary `INVALID:HOST_EXCEPTION` | passed / `true` | exit 0; reply revision 17, armed, 10,000 ms; follow-up state still armed | attachment verification, hold, denial oracle and prompt not started | `COMPLETED` / `VERIFIED`; CLEAR reply revision 18, released |
| `calibration-20260908-223912-eaa6d3f9` | `INVALID:HOST_EXCEPTION`; `Revision=null` | `ARM`; `PROPERTY_NOT_FOUND_EXCEPTION`; primary `INVALID:HOST_EXCEPTION` | passed / `true` | exit 0; reply revision 20, armed, 10,000 ms; follow-up state still armed | attachment verification, hold, denial oracle and prompt not started | `COMPLETED` / `VERIFIED`; CLEAR reply revision 21, released |

`Permission / positive control = passed / true` means every retained permission record says Usage Access `ENABLED` / `MODE_ALLOWED`, Accessibility `ENABLED` / `GLOBAL_ENABLED_COMPONENT_MATCH_FULL`, heartbeat `FRESH`, candidate health `HEALTHY` and eligibility `ELIGIBLE`, and the independent fixture counter advanced exactly once. It does not mean enforcement passed.

The stage enum is terminal rather than a complete transition journal. The sanitized operation journal is identical in all four directories and records successful ADB authorization, metadata reads, bundle APK installation/pull verification, candidate initialization/CLEAR, repeated permission reads, fixture open/state, exactly one positive-control input tap, pre-ARM candidate/permission reads, `CANDIDATE_ARM`, cleanup candidate state, and `CANDIDATE_CLEAR`. Ordered source plus those records place bundle/hash verification, transport ingestion, ADB preflight, metadata, APK verification, candidate initialization, permission verification, positive control, candidate state query and pre-ARM permission verification before the terminal ARM boundary. No operation category exists for attachment verification because it is a state-polling phase; both the terminal `HostStage=ARM` and immediate catch/cleanup state show that `WAIT_FOR_ATTACHMENT` was never entered.

## Immutable artifact hashes

These common files were independently re-read in every directory:

| Artifact | SHA-256 in each of four directories |
| --- | --- |
| `device.json` | `5e1c89c0cddcc8dc2b1b86bfe5b5e5ed2c61d4170d71318ceafc0c94906b6c23` |
| `operations.json` | `de5debbc6daadbbf8badcb290a7cb40a19be9cfa43792d4ec6daf00f7ce65219` |
| `permission-verification.json` | `2ac76b72a2d1028169f5b20e638e79991ccd6a60394adc6bb2b6187f6bfdea20` |
| `verified-candidate.apk` | `5b27c891fe155ee4d26e4da68f8323f178f7116e73d8097ce07199e5800e318b` |
| `verified-ordinary-fixture.apk` | `223219c17a31439b52698e769bdf03ead0998bbbe8bbb5c1b0ff5be3cfaf21dc` |

| Run suffix | `summary.json` | `fixture.jsonl` | `telemetry.jsonl` | `trace.jsonl` |
| --- | --- | --- | --- | --- |
| `f4dc0d8b` | `595bbc623120b81f491d257f1caad92a43b3dff55ea7130882ecfd420957644d` | `936d8eb0b8d66ad41f29e831fc4abf08bb607a3628759520435b0188539f3d94` | `e97fe361fdb458a0f0cd4b89df57f4a81c17543fa717d644dfab12b23b888715` | `0f236eba948e74ea983812a66736e401e7e77e3a4dda3e286623b65d1a2f52af` |
| `98dc0663` | `29f3715b194e749617c228da896374ccc63927fd668af139a7d84dce6255ff4d` | `bf26b1d93d66cfad92a9c0aa19e6c35d5ee5680c6f9c21bc78cddab319ab293a` | `edfb000321d60ea697724a3d0f804de3421a19902b768f0b9db77f526a4f4bbf` | `e52212470efc4044f615eb235d2f45079588cdec784b32da6d77c7b669ac7c29` |
| `a15b8d45` | `0f1ca19ec3ae677d2efa2ed2af18dae6436e740d18734bcfc3bd5bd45fc26429` | `b28c8698146f0ad852eb9810e6539cc99ff6a83a053b7e21170c4972997a1b12` | `1ebcc146115ed41d92723772b453305e158ab965b92a4ff0034a1e5ca238124e` | `c007ed3273d913f2a33f635f2df0f8cf1982ae814eacb2295710bc2eb3f320b6` |
| `eaa6d3f9` | `074fd16d85d5662df7ea78cbf1ad422c19cc781271bdc58d3e75340228dff037` | `c0fd782e52e9db9637a3788ca4a7729d77b7a700309216cffc75bdccb335e302` | `6af2b02c231f62017069bbdfbda0f9989a5064af76b4da1227c60a44310a769d` | `65adb5f53e4d8a16db574612fc4a9be2b26c04f30e3fb77af51774d749df7699` |

## OBSERVED

- Sanitized metadata in every run is `samsung` / `SM-X400`, Android 16, API 36, build `BP4A.251205.006`, security patch `2026-07-05`; the owner labels the hardware Galaxy Tab S10 Lite / One UI 8.5.
- Each typed host record is schema 1, `HostStage=ARM`, `ExceptionClass=PROPERTY_NOT_FOUND_EXCEPTION`, `PrimaryReason=INVALID:HOST_EXCEPTION`, `FinalizationStatus=COMPLETED`, `CleanupStatus=VERIFIED`.
- Every ARM operation returned exit zero and its sanitized reply was a scalar schema-2 object containing the numeric revision shown above, `armed=true`, `remaining=10000`, `restriction=false` and `attached=false`.
- Each catch-path state query occurred about 0.1–0.2 seconds after ARM and remained armed without restriction or attachment. CLEAR then returned exit zero and the final reply was unarmed, unrestricted and unattached. `CleanupVerified=true` in every summary.
- `BlockedControl=false`, `LatencyMs=null`, `HoldMillis=0`, `InjectedBlockedTaps=0`, `ServiceContinuous=false` and `PhysicalAgreement=UNRECORDED` in all four summaries. There are zero calibration and qualification samples.
- Owner-provided current UI observations say the disposable Accessibility service is ON and candidate health/permissions/service are healthy. Those observations agree with the retained permission snapshot but are not runner-oracle or enforcement results.

## Established root cause

The exact source and immutable bundle bytes match. At runner-v4 line 208, top-level `$armed=Get-CandidateState 'ARM'` stored the scalar ARM reply. The next statement, `$script:Armed=$true`, addressed the same case-insensitive script-scope variable and replaced that reply with a Boolean. Strict-mode evaluation of `$armed.revision` then raised `PropertyNotFoundStrict`, whose exception type is `System.Management.Automation.PropertyNotFoundException`; the safe diagnostic correctly mapped it to `PROPERTY_NOT_FOUND_EXCEPTION`.

The correction removes the unused script-scoped flag, names the response `$armReply`, and extracts its revision through a fail-closed scalar/property/type validator. It does not change ARM, timer, enforcement, permission, fixture, owner-oracle or cleanup behavior.

## INFERRED

- The identical typed stage/class, identical operation sequence and exact same-scope reproduction establish one deterministic runner defect rather than four independent device failures.
- The v4 records refine the earlier runner-v2 interval to the same immediate boundary: ARM reply capture completed, but host revision assignment did not. Runner-v2's exact exception remains historically **UNSPECIFIED**; the v4 finding does not retroactively type it.
- No blocked-enforcement step executed. ARM briefly started the disposable timer, but cleanup ran before expiry and retained telemetry shows no restriction or attachment.

## UNSPECIFIED

- Whether this Samsung configuration can attach the overlay at expiry, deny fixture input/focus for ten seconds, maintain service continuity, agree with the owner, meet latency, satisfy safety/lifecycle rows or support 100 qualification cycles remains **UNSPECIFIED / Not run**.
- The four INVALID attempts establish neither physical enforcement PASS nor FAIL and advance no KR-003 matrix row.

## Disposition

All four runs remain independently and correctly `INVALID:HOST_EXCEPTION`. None is pooled or counted. The transport and permission-verifier results remain configuration-specific, all historical Mi 8/Samsung evidence remains unchanged, and cleanup succeeded four times. The immutable
[runner-v5 replacement](KR-003-SAMSUNG-CALIBRATION-V5-BUNDLE-2026-09-08.md) is a future one-run handoff only; no physical execution is authorized by this record.
