# KR-003 Samsung excluded dual-Home Path-B diagnostic PASS — 2026-09-10

- **Goal:** Strictly ingest the one owner-run excluded dual-Home diagnostic, establish its OD-39/OD-40 verdict, and decide whether the already-published immutable full runner-v12 bundle remains the correct next artifact.
- **Context:** The owner ran diagnostic bundle `4288c79` once on the authorized Samsung configuration after its publication as a zero-row readiness check.
- **Constraints:** Preserve the physical directory and all historical runs; no pooling, qualification/TIME-04/matrix promotion, cross-device inference, screenshots/content/package-history/serial collection, diagnostic rerun, full-run execution, repackaging without need, production claim or KR-004 work.
- **Done when:** The minimized evidence passes strict ingestion, every Path-B and cleanup subcheck has an observed/inferred/unspecified classification, and the existing full bundle is independently checked for the same Home implementation.

## Evidence identity and strict verdict

| Field | Retained value |
| --- | --- |
| Physical directory | `C:\platform-tools\kr003-dual-home-diagnostic\diagnostic-20260910-074340-2a891149` |
| Mounted directory | `/mnt/c/platform-tools/kr003-dual-home-diagnostic/diagnostic-20260910-074340-2a891149` |
| Diagnostic source | `4288c798bdf959857a2e0729e529d63910f9480c` |
| Protocol / runner | `KR003-DUAL-HOME-CALIBRATION-DIAGNOSTIC` / v12 |
| Start / end | `2026-09-10T11:43:40.5152828Z` / `2026-09-10T11:49:20.9937170Z` |
| Strict verdict | `PASSED_DUAL_HOME_DIAGNOSTIC_THIS_CONFIGURATION_ONLY:HOME_ESCAPE_PATH_BLOCKED_WITH_CONTROL_UNAVAILABLE` |
| Evidence path | `PATH_B_CONTROL_UNAVAILABLE_HOST_STIMULUS` |
| Qualification / TIME-04 rows | `0` / `0` |
| Matrix contribution | `NONE` |
| KR-003 complete / production approved | `false` / `false` |

The initial strict ingestion attempt rejected only the order of the nested `FixtureBaseline` JSON properties. The physical PowerShell record retained exactly the expected minimized fields, but JSON object member order is semantically irrelevant. The repository ingester now sorts only that key list before exact comparison; an added/removed field still rejects. Regression coverage uses the physical PowerShell order and separately rejects an unexpected field. The evidence files were not changed. With that bounded validator correction, `node tools/kr003/ingest.mjs home-diagnostic ...` returns the exact strict verdict above.

Key preserved hashes: manifest `71282d99fa0f2ef39c19bf4e2600668fa6356d04b22b7b78b6a680fa8a5d6387`, summary `c7e488a5e45c608fc4b20254721c82777532013f72159aac6d5b5c6eaf7c3cfa`, shell precondition `aeefa4b9e117b90784951f0d93a804da2b8e4c0ee16113f15bb8add7fdd420a4`, Home transport `ebfd11321381183cfabed8b76e2ae692ba669e084c88c3ea13b29d5bbfb4b236`, restricted Home `28cb7d883331d6feae770f9aa93fb73a8be0c808af4b3481959c1524cfd41001`, safety `5af17382bedb277b3c29001a400cf11ee79525bef8685db8a241117754c977e5`, cleanup `a44b36810467210263fb1c3f325c2f46a8e7ad63cb98111f09ee13491950ca13`, stay-awake restoration `ba59a1f3413059f45551766939d66371a752f4826c80aab42c4fe6a814fb7963`, and end-device `fe684a706753482740251bba0f1990980ec544de7cc3f99d51e06d81aafd8acd`.

## OBSERVED

| Required subcheck | Retained observation | Verdict |
| --- | --- | --- |
| Exact configuration | Initial, manifest and end metadata match `samsung` / `SM-X400` / Android `16` / API `36` / build `BP4A.251205.006` / patch `2026-07-05`; final installed candidate/fixture APK hashes also match the bundle | PASS |
| Exclusion | Empty `attempts.json` and `human-checkpoints.json`; summary and manifest each retain qualification rows `0`, TIME-04 rows `0`, matrix `NONE`; paired-statistics count `0` | PASS |
| Shell-input fixture transport | Same fixture true; focused/resumed before and after; exactly one tap increment | PASS |
| Home positive control | One host `KEYCODE_HOME`, accepted, exit `0`, stderr class `NONE`; fixture changed focused/resumed `true/true` to `false/false`, focus-loss delta `1`, tap delta `0` | PASS |
| Fixture return | `ReturnToFixture=VERIFIED`; the pinned assertion requires the same instance, focused/resumed state and unchanged tap count | PASS |
| Excluded restriction | Fresh revision `848`; status `RESTRICTION_ESTABLISHED`; restriction/attachment true, disposition `ORDINARY_APP`, candidate `HEALTHY_ELIGIBLE`, fixture unfocused; 10,000 ms timer produced one excluded 110 ms attachment sample | PASS, excluded |
| Visible restriction check | `FinalVisibilityPhysical=PASS`, `HoldOracle=RESTRICTION_HELD` after the required ten-second observation | PASS |
| Home exercisability | Owner response `UNAVAILABLE`; source `OWNER_RESPONSE`; `HomePhysical=CONTROL_UNAVAILABLE`; no physical Home action recorded | PASS for Path-B selection |
| Restricted Home stimulus | Exactly one `RESTRICTED_KEYCODE_HOME`, host-generated, accepted, exit `0`, stderr class `NONE`, calibrated transport | PASS |
| Candidate continuity | `CandidateContinuity=VERIFIED`; all 475 retained restricted-phase candidate observations have restriction/attachment true, `ORDINARY_APP`, `APPLIED`, eligible true, uncertainty false, Usage/Accessibility/heartbeat true, revision `848` and sample count `101` | PASS |
| Independent fixture continuity | All 475 paired fixture observations retain the same instance, focus gains `3`, focus losses `3`, taps `1`, probe ready and no focused state | PASS |
| Focus/input escape oracle | `FixtureFocusRegain=NONE`; `FixtureInputLeak=NONE` | PASS |
| Owner restricted-stimulus result | `OwnerObservation=PASS`; source combines owner response with the independent host stimulus; status `HELD_WITH_OWNER_AGREEMENT` | PASS |
| Stable Path-B result | `HOME_ESCAPE_PATH_BLOCKED_WITH_CONTROL_UNAVAILABLE`; it is not serialized as physical Home resistance | PASS |
| CLEAR and ordinary state | Cleanup `VERIFIED`; CLEAR attempted; candidate `UNARMED_UNRESTRICTED_UNATTACHED` and `HEALTHY_ELIGIBLE`; fixture `FOCUSED_RESUMED_TAP_VERIFIED` | PASS |
| Independent bailout/final release | CLEAR-only bailout `VERIFIED`; restriction released; latency sample count preserved; no clear-data, uninstall or permission alteration | PASS |
| Stay awake | Original/applied setting `15`, USB power, no setting change needed; final readback `15`, `RESTORED_AND_SETTING_VERIFIED` | PASS |
| Network | `NOT_CHANGED`, no network operation/capability/original/touched journals, as required for this Home-only diagnostic | PASS |
| Final device state | Final typed candidate/fixture state is ordinary and unrestricted; end metadata and APK hashes match the exact bundle | PASS |

## INFERRED

- The top-level PASS is valid under OD-39/OD-40 because every required retained physical response, host stimulus, candidate corroboration, independent fixture oracle and finalization condition agrees, and strict ingestion returns the stable Path-B result.
- The fixed host key had a real system foreground/focus effect in positive control because the independent ordinary fixture was displaced without receiving input, then its return assertion passed. No launcher/package identity is needed for that conclusion.
- This result removes the narrow uncertainty about whether Path B can be exercised reliably on this exact configuration. It supports offering one fresh full runner-v12 attempt; it does not predict that run's 100 cycles, offline state, later recovery route or final verdict.

## UNSPECIFIED / not established

- Why Samsung reported coarse `THREE_BUTTON` navigation while presenting no exercisable Home control remains **UNSPECIFIED**; navigation mode is contextual only.
- No real physical Home action was exercised, so physical Home resistance is not established and must not be claimed.
- Launcher/package identity, UI contents and the mechanism hiding the control are deliberately not retained.
- Mi 8, other Samsung/Android configurations, formal TIME-04, a full qualification PASS, remaining lifecycle/tamper/safety gates, Play approval, supported-device boundary and production readiness remain **UNSPECIFIED** or open.
- Historical Samsung INVALID/FAIL runs remain unchanged and no prior 100-cycle rows are pooled or resumed.

## Existing full runner-v12 readiness

The already-published full bundle remains byte-for-byte unchanged:

| Field | Value |
| --- | --- |
| Source | `80dcdf4846ccbe4fbb0eabb7c226ecf88c58bafd` |
| Path | `C:\platform-tools\kr003-qualification-bundles\80dcdf4` |
| `bundle.json` SHA-256 | `9d68d18a4e71f6d524a7fae77a0f5eedf4949d7d739bfedafd67054f08f30a28` |
| Protocol / cycles | `KR003-CONFIGURATION-ACTIVE-ORACLE-QUALIFICATION` / `100` |
| Physical execution | **Not run under runner-v12** |

Every payload still matches its immutable manifest. Its manifest declares the same dual-path and host-Home transport models, and the diagnostic manifest explicitly pins this source/path/hash as `homeLogicBaseline`. Independent PowerShell AST comparison found byte-identical bodies for the host Home command, positive control, exercisability/owner-state handlers, restricted Home stimulus/polling, all five Home helper/assertion functions, and the complete Path-A/Path-B portion of the safety checkpoint. The diagnostic source added only its excluded entry/cleanup/reporting wrapper around that unchanged shared flow. Therefore no rebuild or repackaging is justified; `80dcdf4` remains the correct next physical artifact.

Do not execute automatically. The future command, if the owner chooses one fresh full attempt, remains:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\platform-tools\kr003-qualification-bundles\80dcdf4\Start-KR003.ps1" -OfflineNetwork
```

Allow approximately 75–90 minutes, including approximately 60–70 unattended minutes. At checkpoint 3, watch the held restriction for ten seconds and answer the visible result. Then answer `A` only if Home is physically exercisable, `U` if unavailable as presented, or `I` if uncertain. On the demonstrated `U` route, do not change navigation mode or attempt a hidden control; allow the runner's one calibrated host Home stimulus and report whether restriction remains visibly effective. Only after that Path-B gate passes, follow the displayed Settings root, expected Digital Wellbeing denial, recovery-button ten-second stability, ordinary re-entry and final CLEAR/ordinary-use prompts exactly once each.
