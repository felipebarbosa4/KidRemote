# KR-003 Samsung qualification Home-phase FAIL — 2026-09-09

- **Goal:** Preserve and classify runner-v10 run `run-20260909-101646-69c0fb84`, especially the checkpoint-3 `FAIL:RESTRICTION_LOST` boundary.
- **Context:** The owner ran the immutable runner-v10 bundle on the calibrated `samsung` / `SM-X400` configuration. The console reached all 100 automated expiries and the final Home prompt.
- **Constraints:** Keep the complete run FAIL; no rerun, resume, pooling, replacement checkpoint, navigation-mode change, cross-device inference, raw device output, screenshot/content capture, production claim or KR-004 work.
- **Done when:** Rows, timing, checkpoint responses, candidate/fixture transition, failure source, cleanup, navigation ambiguity and artifact integrity are explicit with OBSERVED/INFERRED/UNSPECIFIED separated.

## Verdict

Strict ingestion of `/mnt/c/platform-tools/kr003-qualification/run-20260909-101646-69c0fb84` returns source `fd9824943c35f70d393f7b0e0b252c2a8253a2d9`, status `FAIL`, reason `RESTRICTION_LOST`, exactly 100 retained qualification rows, 100 structurally valid automated active-oracle cycles, p50 227 ms / p95 318 ms / max 341 ms, two passing checkpoint sessions, one failed checkpoint record, `partial=true` and `kr003Complete=false`.

The existing top-level FAIL is preserved. It is not converted to PASS or INVALID, and none of its rows or checkpoint work may be resumed or pooled.

Captured system metadata remains `samsung` / `SM-X400` / Android `16` / API `36` / build `BP4A.251205.006` / security patch `2026-07-05`. `Galaxy Tab S10 Lite` and `One UI 8.5` remain owner-provided labels.

## OBSERVED

| Check | Retained result |
| --- | --- |
| Qualification rows | Exactly 100, attempts 1–100, 100 distinct revisions 237–435; all have `AutomatedOracle=PASS`, `InputOracle=PASS`, `PhysicalObserver=NOT_SAMPLED`, and null reason |
| Fixture positive controls | 100/100 `REACHED_FIXTURE` before ARM |
| Blocked input/focus | 100/100 PASS; 20 denied taps per row, 2,000 total; no focus regain |
| Attachment timing | 100/100 non-null; p50 227 ms, p95 318 ms, max 341 ms |
| Hold duration | 22,309–23,156 ms per row |
| Permission/health continuity | All 9,446 retained candidate frames have Usage Access, Accessibility and heartbeat true; uncertainty and trace loss false; eligibility true. The last completed permission verification is Usage `ENABLED`, Accessibility `ENABLED`, heartbeat `FRESH`, health `HEALTHY`, eligibility `ELIGIBLE` |
| Checkpoint 1 | `PREFLIGHT_NORMAL_PASS=PASS` |
| Checkpoint 2 | `PREFLIGHT_NEGATIVE_CONTROL=PASS` |
| Final visible check | Owner response `PASS`, retained at `2026-09-09T15:29:46.6978190Z` |
| Home response | `HomePhysical=UNRECORDED`, `HomeObservedUtc=null`; no Home P/F/I response was retained |
| Settings/recovery runner phase | Formal `recovery-final.json` was never created and `RecoveryReason=UNRECORDED`; the focused recovery diagnostic never started |
| Final checkpoint | `POST_RUN_SAFETY=FAIL`, `GUIDED_CHECKPOINT_STOPPED_WITH_PRESERVED_SUBSTEP_EVIDENCE`, retained at `2026-09-09T15:29:53.6741031Z` |

### Exact checkpoint-3 transition

The last snapshot satisfying the Home-phase hold invariant was request 15858 / elapsed 143,328,737 (approximately `2026-09-09T15:29:53.273Z`): revision/sampled revision 435, `armed=true`, `restriction=true`, `attached=true`, `adapter=APPLIED`, `disposition=ORDINARY_APP`, `eligible=true`, `eligibilityLost=false`, `removals=0`.

At elapsed 143,328,790 (approximately `15:29:53.327Z`), the sanitized candidate trace records `recovery_open_requested trigger=settings_button`; dispatch follows at 143,328,812. At 143,329,028, a known-safe-system transition occurs and the overlay is removed with trigger `safe_surface`.

The first snapshot violating `Assert-KRHold` was request 15860 / elapsed 143,329,114 (approximately `15:29:53.650Z`): revision/sampled revision still 435, `armed=true`, `restriction=true`, `attached=false`, `adapter=SAFE_SURFACE_AVAILABLE`, `disposition=SAFE_SYSTEM`, `eligible=true`, `eligibilityLost=false`, `removals=1`. Thus the timer restriction flag did not become false. The phase invariant failed because the destination became an allowed safe system surface and the overlay intentionally detached.

The fixture remained `focused=false`; taps stayed 102 and focus gains/losses stayed 101/101. Its `resumed` state changed from true at elapsed 143,328,528 to false at 143,328,883 after the Settings action. There was no fixture input delivery or focus regain.

`Poll-SafetyHold` calls `Assert-KRHold` while waiting for an owner Home response. The retained `HomePhysical=UNRECORDED` proves no owner F response produced the result. The automated poll raised `FAIL:RESTRICTION_LOST` after the safe-system/overlay-detach snapshot.

The exact ordered qualification attachment samples in milliseconds are:

```text
282, 224, 273, 227, 77, 232, 181, 91, 301, 237, 256, 236, 290, 78, 167, 318, 270, 240, 289, 243, 235, 281, 173, 294, 236, 77, 261, 255, 143, 203, 161, 77, 119, 210, 159, 152, 182, 200, 184, 169, 253, 297, 197, 186, 265, 302, 83, 210, 224, 113, 97, 109, 150, 266, 307, 183, 213, 243, 179, 280, 228, 145, 288, 229, 87, 281, 181, 211, 86, 252, 275, 302, 223, 188, 324, 227, 124, 249, 219, 74, 251, 216, 271, 223, 188, 84, 77, 228, 331, 332, 64, 281, 321, 249, 185, 341, 239, 261, 277, 241
```

### Cleanup

Checkpoint CLEAR was not reached. Finalization's separate diagnostic bailout completed and verified revision 435→436, all 100 samples preserved and restriction released. Wi-Fi was restored to original `1` with flags verified; mobile-data capability was `ABSENT` / `NOT_APPLICABLE`. Runner-v10 restored the exact stay-awake setting from applied 15 to original 0 and verified readback. `FinalizationErrors=[]`.

## INFERRED

- The settings-button listener activation is consistent with a physical tap on the visible overlay control during the Home prompt. The retained trace establishes activation, but does not encode the actor or intent.
- The owner's separate statement that no literal Home button was available is consistent with gesture navigation, but runner-v10 captured no navigation-mode signal. It does not establish the mode.
- The generic Home wording plausibly contributed to the out-of-sequence Settings action. That human interpretation is not directly recorded.

## UNSPECIFIED

- Whether the device used gesture, two-button, three-button or an OEM-specific navigation mode.
- Whether any Android system Home action was attempted. No launcher/Home transition and no Home owner response are retained.
- The exact physical input that activated the Settings control and why it was selected.
- Home resistance or Home escape on this run. Absence of a Home action cannot pass or fail that specific check.

## Enforcement conclusion

This is not evidence that the active timer restriction became false or that an ordinary app/launcher became usable: the first bad snapshot retained `restriction=true`, and the transition was to the deliberately allowed `SAFE_SYSTEM` disposition. It is also not a valid Home-resistance PASS or Home-escape FAIL because no Home action is established. The established failure is the runner-v10 Home-phase hold oracle reacting to an out-of-sequence designated Settings action. Historical classification remains `FAIL:RESTRICTION_LOST` exactly as emitted.

## Artifact integrity

| File | SHA-256 |
| --- | --- |
| `SUMMARY.md` | `b1bfe21af897b09fed8b6f7499f6427ae154ba8977528733ba00ccf90e45f3fc` |
| `attempts.csv` | `1c005027a6016ed9215a52e9549e4eba779f58d46a97a3307f8167388f5c442f` |
| `attempts.json` | `211f8ed79345405758621056bae1afe0857ccf9eb421be2cb1d4164e4b3d574d` |
| `calibration.json` | `f03ab964d981207cdc572efb032be73b5dabebba388c347f1a35d19755bfd7a4` |
| `diagnostic-bailout.json` | `2c21f3569f994ba8cfb729bd39236db94707b5a776b22b9e185f181a80ee38bb` |
| `fixture.jsonl` | `afaa20b22037d5a48d24339d07f4f4a67bbc74f3ceb54ca1cfaef7200741008e` |
| `human-checkpoints.json` | `9acd2b9d65c005e2e7b04dcf1ad874b13bb329e9b4d492716cdbd128a221906e` |
| `manifest.json` | `d45a340c1eeb46438a9219983cea3a598dbc7849e5bc3a5d309501646015f2f3` |
| `network-capabilities.json` | `dd46333f8131d835707b3b4c844a079df196d971c27143f9087efd4d522c31cc` |
| `network-operations.json` | `c1e49c9903189cb110481878c122b3f04a323df86d2bfc4ce8356f5cd5e9660e` |
| `network-original.json` | `a332ba61d36e43c30f984e1d109ac2de9c13cef574ae9479b92a4843924b8801` |
| `network-restoration.json` | `b37924d9bcb09dbcbeda897f2087eaadbee5e913d2d19789b8c451db57ff424b` |
| `network-touched.json` | `54f99457c188496eea76f2aa36037affba6dd011141e532b80720f255fa6afa3` |
| `permission-verification.json` | `f3ad4aa9bf56053e02112769110191c09c599478da78cff863c7d0f15deb2b96` |
| `prior-metrics.json` | `0b7ae998459d2adcda0e6649c20695871f13f75226950242793ab01f6e65cae2` |
| `safety-final.json` | `f15d0bfadc0d746dc161f554162cf63eeaf36812b62315efc057d36e3f734ef0` |
| `stay-awake-restoration.json` | `382fbcdc80f0e546b2a83390d1de32e42c6c87a0248237370cb81423e8151c7f` |
| `stay-awake.json` | `813ffafaca33ef6007cda7677f0562d37ac513305c3df01a65fac2640d23f00a` |
| `summary.json` | `ce325bd7a835953c9bcef1154080814856d6b5f0b4772891bb7f7acac4e18ca7` |
| `telemetry.jsonl` | `008068555ffb8efdd6a4bd5d2963e17c168b5a366f7d20b77a941e470f5cf6b7` |
| `trace.jsonl` | `b282ca0d0632078c2eb77583e7a2246567f2524ece30eca939431bc9b4d8ab59` |
| `verified-candidate.apk` | `5b27c891fe155ee4d26e4da68f8323f178f7116e73d8097ce07199e5800e318b` |
| `verified-ordinary-fixture.apk` | `223219c17a31439b52698e769bdf03ead0998bbbe8bbb5c1b0ff5be3cfaf21dc` |

The mounted source evidence remains unmodified.

## Matrix boundary

No formal KR-003 matrix row advances to PASS. `TIME-04` retains another exact-configuration non-poolable run with 100 automated PASS rows and p95 318 ms, but checkpoint 3 is incomplete/failed and Home was not established. Lifecycle, permission-revocation, tamper, broader safety, Play and production gates remain open.
