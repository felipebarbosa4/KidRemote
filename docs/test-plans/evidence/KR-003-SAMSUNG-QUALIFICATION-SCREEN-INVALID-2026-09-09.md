# KR-003 Samsung qualification checkpoint-3 screen/keyguard INVALID — 2026-09-09

- **Goal:** Preserve and classify the physical runner-v9 attempt that completed 100 automated cycles and then stopped at checkpoint 3.
- **Context:** The owner invoked the immutable runner-v9 bundle on the calibrated `samsung` / `SM-X400` configuration. Run `run-20260909-012601-0d666cb9` ended `INVALID:SCREEN_OR_KEYGUARD`.
- **Constraints:** One independent INVALID run; no resume, pooling, replacement checkpoint, qualification PASS, cross-device transfer, raw device output, screenshot/content capture, new physical execution or KR-004 work.
- **Done when:** Exact automated rows, active oracles, latency statistics, health continuity, human-checkpoint boundary, cleanup, network restoration, root-cause limits and artifact hashes are explicit.

## Verdict

Strict ingestion of `/mnt/c/platform-tools/kr003-qualification/run-20260909-012601-0d666cb9` returns source `532bc22df0084b62e202a0cda0158dc61331f180`, status `INVALID`, reason `SCREEN_OR_KEYGUARD`, 100 retained qualification rows, 100 structurally valid automated active-oracle cycles, two passing human checkpoint sessions, one invalid checkpoint record, `partial=true`, and `kr003Complete=false`.

The 100 automated rows are useful retained sub-evidence, but the run is not a qualification PASS. Checkpoint 3 cannot be resumed or replaced, and no row may be pooled into a later run.

Captured system metadata is `samsung` / `SM-X400` / Android `16` / API `36` / build `BP4A.251205.006` / security patch `2026-07-05`. `Galaxy Tab S10 Lite` and `One UI 8.5` remain owner-provided labels rather than captured system metadata.

## OBSERVED

| Check | Retained result |
| --- | --- |
| Qualification rows | Exactly 100, attempts 1–100, 100 distinct revisions; every `AutomatedOracle=PASS`, `InputOracle=PASS`, `PhysicalObserver=NOT_SAMPLED` |
| Fixture positive controls | 100/100 `REACHED_FIXTURE`; each was performed before ARM on an unblocked fixture |
| Blocked-input oracle | 100/100 PASS; 20 injected blocked taps per row, 2,000 total; fixture counter did not advance during the blocked probes |
| Focus oracle | 100/100 PASS; no focus regain. Retained focus baselines are sequential 2–101, with no per-row baseline change during the hold |
| Attachment samples | 100/100 non-null, 51–334 ms; ordered samples are retained below |
| Hold duration | Every row exceeded ten seconds; retained range 22,238–24,454 ms |
| Permission/service continuity | All 8,380 candidate telemetry frames have Usage Access true, Accessibility true, heartbeat fresh/true, accounting uncertainty false and no trace loss. Runner permission verification at the final completed cycle was Usage `ENABLED`, Accessibility `ENABLED`, heartbeat `FRESH`, candidate health `HEALTHY`, eligibility `ELIGIBLE` |
| Checkpoint 1 | `PREFLIGHT_NORMAL_PASS=PASS`: ten-second visible result plus active fixture-input denial |
| Checkpoint 2 | `PREFLIGHT_NEGATIVE_CONTROL=PASS`: lab CLEAR plus one real input reached the fixture |
| Checkpoint 3 | `POST_RUN_SAFETY=INVALID`; no physical response was retained. `FinalVisibilityPhysical`, Home, recovery, re-entry and checkpoint CLEAR-touch fields are all `UNRECORDED` |
| Checkpoint-3 software boundary | It began at revision 230 with the restriction attached. `HoldOracle=RESTRICTION_HELD` was updated through elapsed 111,071,398, about 298.2 seconds after checkpoint start. The next retained frame at elapsed 111,071,759 had `eligible=false`; a following frame set `eligibilityLost=true`. Usage, Accessibility and heartbeat remained true, uncertainty remained false, and restriction/attachment remained true |
| Final CLEAR | Final checkpoint CLEAR did not occur. Finalization's separate lab-only diagnostic bailout did run: revision 230→231, all 100 samples preserved, restriction release `VERIFIED` |
| Final candidate state | Last telemetry: revision 231, unarmed, unrestricted, unattached, adapter `NOT_REQUIRED`, ordinary disposition; Usage/Accessibility/heartbeat true and uncertainty false. Eligibility remained false |
| Network cleanup | `RESTORED_AND_FLAGS_VERIFIED`: Wi-Fi restored to original `1`; mobile-data capability was captured `ABSENT` and remains `NOT_APPLICABLE` |
| Other final device state | **UNSPECIFIED.** Normal `final-metrics.json`, `end-device.json` and final APK re-verification were not reached after checkpoint INVALID |

The exact ordered attachment samples in milliseconds are:

```text
282, 127, 234, 211, 170, 208, 117, 192, 245, 125, 88, 74, 51, 188, 170, 73, 315, 249, 313, 207, 334, 114, 231, 152, 246, 276, 202, 204, 266, 218, 298, 326, 105, 164, 268, 225, 275, 98, 327, 221, 272, 67, 253, 311, 260, 181, 273, 247, 244, 214, 242, 256, 328, 91, 248, 317, 240, 144, 301, 78, 231, 156, 286, 309, 85, 70, 257, 279, 200, 90, 320, 69, 218, 166, 188, 284, 251, 221, 263, 175, 188, 201, 253, 296, 278, 188, 273, 201, 64, 283, 303, 278, 310, 171, 87, 173, 252, 249, 189, 217
```

Independent recomputation and the retained summary agree: count 100, p50 221 ms, p95 317 ms, maximum 334 ms.

## INFERRED

The approximately five-minute delay between checkpoint-3 start and loss of eligibility is consistent with an unattended screen timeout, and the owner's report that the tablet appeared screen-off and/or keyguarded is consistent with the candidate signal. It does not establish which condition occurred.

The candidate computes one `eligible` boolean as `PowerManager.isInteractive && !KeyguardManager.isKeyguardLocked`. Runner-v9 retained only that combined boolean. Therefore the direct cause is established only as loss of screen/keyguard eligibility while the owner prompt was waiting; screen-off, keyguard, or both cannot be separated.

Runner-v10 uses Android's reversible Stay awake while plugged in control. Android documents the developer option as keeping the screen on while the device is plugged in. AOSP's `svc power stayon true` wakes the screen and applies the supported plugged-source bitmask; Android defines AC/USB/wireless/dock as distinct power-source bits. The runner requires an initially eligible device, captures only a coarse source class and integer setting, verifies the applied value covers the current plugged source at cycle boundaries, and restores/readbacks the exact original setting in finalization. It never removes or alters lock credentials. [Android developer option](https://developer.android.com/studio/debug/dev-options#general), [Android 16 `svc power` source](https://android.googlesource.com/platform/frameworks/base/+/android16-qpr2-release/cmds/svc/src/com/android/commands/svc/PowerCommand.java), [BatteryManager source constants](https://developer.android.com/reference/android/os/BatteryManager#BATTERY_PLUGGED_USB), [Settings global value](https://android.googlesource.com/platform/frameworks/base/+/android16-qpr2-release/core/java/android/provider/Settings.java).

## UNSPECIFIED

- Whether the physical display turned off, keyguard engaged, or both.
- The screen-timeout value, keyguard timeout, original stay-awake setting, USB/AC/wireless/dock charging state, and whether any charging state changed during runner-v9; none was retained.
- Any cause beyond the combined candidate eligibility loss.
- The unexecuted runner-v10 mechanism's behavior on this Samsung configuration; synthetic and host validation cannot replace a future fresh physical run.

## Artifact integrity

| File | SHA-256 |
| --- | --- |
| `SUMMARY.md` | `73fa8a9710faa2285aa67b7f611e7653735f25455c1e29b6d614222478adc07a` |
| `attempts.csv` | `49036c1acc32306625c5ef3b3a4b30e99e2ed95eaf163400d3856d625116a763` |
| `attempts.json` | `984f0117ac2d6a6fe768397c8a8d74b0953619047c47ac32edf64a6026e75856` |
| `calibration.json` | `e4fff1c1eb43941432ec3de88a4317f6c0a217cde1fe821c4cd87c3273afa721` |
| `diagnostic-bailout.json` | `409006aca1f993764b1037950612fc34a57efbad68c68d7a71011fec4086104f` |
| `fixture.jsonl` | `0330295507bf28cea77e555ab26ddb45d2a9eae94f531c5e19ff6cc07a697a57` |
| `human-checkpoints.json` | `5ff081ad98b71a897d6bb43678213c3ac24f416bd316aceb1263739b6e24821a` |
| `manifest.json` | `974f2626ef7ed7ac92670349fac71af9789500f2835b6ce39996baaf9f5c3097` |
| `network-capabilities.json` | `87c3b98c1d25eb6848b2f54aca698908b3ec35540f8a320d3595cb4bda752b95` |
| `network-operations.json` | `af7cb85d9beadba85e4681f1ae067f2917075511c9e220162484f48e651a20b2` |
| `network-original.json` | `a332ba61d36e43c30f984e1d109ac2de9c13cef574ae9479b92a4843924b8801` |
| `network-restoration.json` | `6f40807537e0d9435643e1e79fe0ac34a5324d2505aaf89c922b71c7311e2743` |
| `network-touched.json` | `54f99457c188496eea76f2aa36037affba6dd011141e532b80720f255fa6afa3` |
| `permission-verification.json` | `f3ad4aa9bf56053e02112769110191c09c599478da78cff863c7d0f15deb2b96` |
| `prior-metrics.json` | `8a873772c2db44c06000ae20920ae94fbf48a65103aebf96c2e90cf183b5802b` |
| `safety-final.json` | `ebfe21b6c589255c6b4ff8cf31ee83332f62e3a418c1a2e5b6dd3cf80bfac218` |
| `summary.json` | `cbc8edff20169698740f4a5072d7102e9382d1c4c82740ada44ae0339ed26b91` |
| `telemetry.jsonl` | `80c8c95cfc09221aaee962199a93d6a1943a91cfc74ccabf9f2dced079fe2314` |
| `trace.jsonl` | `8cd22c0c95ef76fdd3a52556812eeb2d4af67b727da8db1b84e771fa1fb04a23` |
| `verified-candidate.apk` | `5b27c891fe155ee4d26e4da68f8323f178f7116e73d8097ce07199e5800e318b` |
| `verified-ordinary-fixture.apk` | `223219c17a31439b52698e769bdf03ead0998bbbe8bbb5c1b0ff5be3cfaf21dc` |

The source evidence directory remains unmodified.

## Matrix boundary

No formal KR-003 matrix row advances to PASS. `TIME-04` now has one exact-configuration INVALID attempt containing 100 valid automated active-oracle rows and a measured p95 of 317 ms, plus checkpoint 1/2 PASS, but its required third checkpoint is INVALID. The whole contract remains open and non-resumable. `TIME-02`/`TIME-03` gain only a combined eligibility-loss observation; because screen and keyguard are not separated, neither row passes. Lifecycle, permission-revocation, tamper, broader safety, Play and production gates remain open.
