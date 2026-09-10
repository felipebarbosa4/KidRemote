# KR-003 Samsung runner-v11 qualification attempts — 2026-09-09

- **Goal:** Preserve and strictly classify the two independent owner-run runner-v11 attempts, including RUN A's post-cycle ADB rejection and RUN B's non-exercisable Home checkpoint.
- **Context:** Both runs used immutable source `6cf04ab8a9455689783ef97d8babb8cc07d81485` on the calibrated Samsung configuration. The owner separately reports that RUN B's restriction was visibly active but no Home control was visible at the exact Home prompt.
- **Constraints:** Preserve both historical verdicts; no deletion, merge, pooling, resume, replacement checkpoint, Home PASS/escape/resistance inference, screenshot/UI-node/content capture, navigation-mode change, new physical execution, cross-device inference or KR-004 work.
- **Done when:** Automated rows/statistics, checkpoint state, Home action boundary, candidate/fixture state, cleanup and the limits of the ADB diagnosis are explicit with OBSERVED / INFERRED / UNSPECIFIED separated.

## Strict verdicts

| Run | Strict ingestion | Rows and timing | Checkpoints | Home result | Cleanup |
| --- | --- | --- | --- | --- | --- |
| A — `run-20260909-122154-609630e9` | `INVALID:ADB_REJECTED`; `partial=true`; `kr003Complete=false` | 100/100 automated active-oracle PASS; p50 218 ms, p95 299 ms, max 316 ms | 1 PASS; 2 PASS; 3 INVALID | Final visibility and Home unrecorded; no Home prompt/action | Diagnostic CLEAR failed; Wi-Fi and stay-awake restoration unverified |
| B — `run-20260909-132619-dc9c6864` | `INVALID:SAFETY_FINAL_HOME`; `partial=true`; `kr003Complete=false` | 100/100 automated active-oracle PASS; p50 160 ms, p95 304 ms, max 333 ms | 1 PASS; 2 PASS; final visibility PASS; 3 INVALID | `HomePhysical=INVALID`, `HOME_ACTION_NOT_EXERCISABLE_OR_UNKNOWN`, owner-response source; no action/escape | Diagnostic CLEAR verified; network and stay-awake restoration verified |

Both manifests capture `samsung` / `SM-X400` / Android `16` / API `36` / build `BP4A.251205.006` / security patch `2026-07-05`. `Galaxy Tab S10 Lite` and `One UI 8.5` remain owner-provided labels, not captured system metadata.

## OBSERVED — common automated evidence

- Each run contains exactly 100 qualification rows, attempts 1–100 and 100 distinct revisions. Every row has `AutomatedOracle=PASS`, `InputOracle=PASS`, `PositiveControlTap=REACHED_FIXTURE`, `PhysicalObserver=NOT_SAMPLED`, and no row reason.
- Each run injected 20 blocked taps per row, 2,000 total. No blocked-input delivery or fixture focus regain is recorded. RUN A holds span 22,294–23,119 ms; RUN B holds span 22,246–24,618 ms.
- RUN A retains 7,888 candidate frames and RUN B 7,619. Every retained frame has Usage Access, Accessibility, heartbeat and eligibility true, with uncertainty and trace loss false. The typed permission record in each is Usage `ENABLED`, Accessibility `ENABLED`, heartbeat `FRESH`, candidate health `HEALTHY`, eligibility `ELIGIBLE`.
- Checkpoints 1 and 2 are explicitly PASS in each run: ten-second visible restriction plus active input denial, then controlled CLEAR plus an input reaching the independent fixture.
- The top-level results remain INVALID. The 100-row sets are retained sub-evidence, not qualification samples that can be resumed or pooled into another run.

## RUN A boundary

### OBSERVED

- Checkpoint 3 began with `CurrentStep=FINAL_VISIBILITY`. `FinalVisibilityPhysical=UNRECORDED`, `HomePromptedUtc=null`, `HomePhysical=UNRECORDED`, `HomeActionResult=UNRECORDED`, and `HomeResultSource=NONE`. No Home-specific phase or owner result began.
- The last retained candidate snapshot is request 12,772 / elapsed 150,286,368 / revision 640: `armed=true`, `restriction=true`, `attached=true`, `adapter=APPLIED`, `disposition=ORDINARY_APP`, `eligible=true`, `removals=0`, sample count 100. Usage, Accessibility and heartbeat are true.
- The following retained fixture reply is request 12,773 / elapsed 150,286,492: taps 102, `focused=false`, `resumed=true`, focus gains/losses 101/101. No fixture transition is recorded.
- `POST_RUN_SAFETY=INVALID` was retained at `2026-09-09T17:25:51.0666033Z`.
- Finalization attempted the diagnostic bailout, but its first candidate-state query also stopped `INVALID:ADB_REJECTED`; revision/sample counts and restriction release remain unverified.
- The separate Wi-Fi restoration command `RESTORE_WIFI` was rejected later with exit code 1 / `StderrClass=OTHER`; no readback followed. Mobile data was device-declared `ABSENT` / `NOT_APPLICABLE`. Stay-awake restoration also ended `RESTORE_FAILED_OWNER_ACTION_REQUIRED` with no observed readback. The final manifest captured Wi-Fi `0`, versus original `1`.

### INFERRED from retained ordering plus immutable source

`Poll-SafetyHold` performs a candidate `Get-LabState` before its fixture query. `Get-LabState` increments the shared request counter and sends the candidate debug receiver a `SNAPSHOT`. Because request 12,773 is the last retained fixture reply, the next loop operation was candidate `SNAPSHOT` request 12,774. It failed before a reply could be journalled. This establishes the failing operation boundary as the candidate debug-control `SNAPSHOT` broadcast during final-visible monitoring—not ARM, a blocked hold, Home, Settings, or network isolation.

The later `RESTORE_WIFI` rejection is a distinct finalization failure and did not produce the already-retained primary result.

### UNSPECIFIED

- The primary `SNAPSHOT` process exit code, coarse stderr class and Android/ADB rejection cause. Runner-v11's generic `Invoke-LabAdb` did not journal those fields for candidate broadcasts; `INVALID:ADB_REJECTED` can represent a nonzero exit or a security/permission-class stderr. No raw output may be reconstructed or invented.
- Final restriction release, final Wi-Fi state after the failed restore attempt, and final stay-awake setting. RUN B's later initial values are a later independent observation and do not prove what occurred between runs.

## RUN B Home timeline

### OBSERVED

1. Final safety began at `2026-09-09T18:29:21.3671372Z`; the read-only coarse navigation signal was `THREE_BUTTON`, parsed from value 0 and verified twice.
2. The owner recorded final visible-check PASS at `18:29:49.7482010Z`.
3. Runner-v11 entered `CurrentStep=HOME_ACTION` and recorded `HomePromptedUtc=18:29:49.7502020Z`. The deterministic runner-v11 prompt, also supplied in the owner's console record, said: `HOME CHECK (THREE_BUTTON): tap the on-screen Home button once.` `HomeActionInstruction` was not a separate JSON property.
4. The last prompt-loop snapshot, request 12,282 / elapsed 154,140,798 / revision 844, retained `armed=true`, `restriction=true`, `attached=true`, `adapter=APPLIED`, `disposition=ORDINARY_APP`, `eligible=true`, `removals=0`. Fixture request 12,283 retained taps 102, `focused=false`, `resumed=true`, gains/losses 101/101.
5. At `18:30:05.4715073Z`, the owner response was retained as `HomePhysical=INVALID`, `HomeActionResult=HOME_ACTION_NOT_EXERCISABLE_OR_UNKNOWN`, `HomeResultSource=OWNER_RESPONSE`. Checkpoint 3 then retained INVALID.
6. Before CLEAR, bailout snapshot request 12,284 / elapsed 154,141,221 still retained revision 844, armed/restricted/attached true, ordinary-app disposition and applied adapter. No trace event or fixture focus/input transition occurred between the prompt and that snapshot.
7. Formal Settings/recovery/re-entry diagnostics never began. Finalization's lab-only CLEAR changed revision 844→845, preserved all 100 samples and reached unarmed/unrestricted/unattached state. Wi-Fi was unchanged at original 0 and verified; mobile data was absent/not applicable. Stay-awake was unchanged at original 15 and verified. `FinalizationErrors=[]`.
8. Owner-provided physical observation at the exact prompt: the KidRemote overlay occupied the screen and showed **Open device settings**; no three-button navigation bar or on-screen Home control was visible, so the requested action was not physically exercisable as presented. This is an owner observation only; the photograph is not stored, copied or treated as machine evidence.

### INFERRED

The absence of any candidate transition, trace event, fixture focus change or input count change across the retained Home interval corroborates the owner's report that no Home action was performed. It does not prove that every possible physical or synthetic Home path was absent.

### UNSPECIFIED

- Navigation-control visibility from software evidence. `THREE_BUTTON` describes only the coarse setting and cannot establish what System UI displayed above/around the restriction.
- Home resistance or Home escape. No physical Home action or system Home transition is established.
- A completed checkpoint-3 result, qualification PASS, or an ordinary-app enforcement loss. Restriction remained true and attached through the last pre-CLEAR snapshot.

## Requirement and design boundary

The existing repository contract resolves the current acceptance criterion as an exercised physical system Home action: [KR-003-PHYSICAL](../KR-003-PHYSICAL.md) requires “one physical Home attempt while restricted” that “does not restore ordinary use,” and Q7 requires the owner to exercise the current Android system Home action once. Therefore control-unavailable cannot already satisfy the Home gate. It is correctly INVALID under the current contract.

- **Physical-control path (current):** first establish that the current button/gesture control is actually available; then exercise it once and independently corroborate the held ordinary-app restriction. Unavailable/unknown is INVALID.
- **Control-absence path (not approved):** it could be defined as separate no-escape evidence only through an explicit owner/product evidence-model decision. It would need an owner absence observation plus independent software corroboration that restriction stayed active; it must not be labelled an exercised/resisted Home action.
- **Host-injected Home (not approved as a substitute):** an independently issued `adb shell input keyevent KEYCODE_HOME`, after its own positive transport calibration, could test response to a synthetic framework Home key while the owner observes. Android defines [`KEYCODE_HOME`](https://developer.android.com/reference/android/view/KeyEvent.html#KEYCODE_HOME) as system-handled rather than app-delivered, while Android's navigation help describes physical user Home as a button tap or bottom-edge gesture depending on configured mode and notes that device steps can vary ([Android Help](https://support.google.com/android/answer/9079644)). It would not prove visibility/discoverability/usability of the real System UI button/gesture or equivalence to physical navigation, and the candidate Accessibility service must not provide the stimulus. It can only supplement the present contract unless the owner explicitly changes it.

Prepared runner-v12 keeps the current gate and removes the unsupported implication: it records `NAV_MODE_*`, asks for `HomeControlExercisability` before showing any action instruction, and records `HOME_ACTION_EXERCISED` separately from `HOME_ACTION_RESISTED`/`HOME_ACTION_ESCAPED`. `UNAVAILABLE` and `UNKNOWN` stop INVALID before an action prompt. No runner-v12 physical bundle is published or executed.

## Artifact integrity

| Artifact | RUN A SHA-256 | RUN B SHA-256 |
| --- | --- | --- |
| `SUMMARY.md` | `29890b41d27d52577812fd3ea965111836a9723ec550383f7e8801eb51e71dab` | `4c4cc8b31ffa8a2ace9cfe8ad4ea63ac6ace0f6dcdf9783e101eba407c139397` |
| `attempts.json` | `f4ffc85863398ca850016d19b99d3219053f628c876904ff16d13ccd01361d31` | `6b204d2b21d65d4cc05ef87e076297bbabc8404943f6e60bc7808e13dc68ce75` |
| `human-checkpoints.json` | `95b755b6ec0de236065ef19d6bccfd24adb56ad83eed49259c0c245b9b7a1c0d` | `506090bba3c4d8001cf7ee0b40ef0a5841b3195017fc5a164dea18cc54b0c2bf` |
| `manifest.json` | `06da4bd5cde0ed44d03b98fcde9e954d544a7e6fd8b0be0a9043bb6ff256392b` | `faf1d292158b781a44a8450ee10843ee389d4fe9e5c51292461d31be575e84a5` |
| `safety-final.json` | `8aa8abd22959320ea001135eed1df39899185f8a4ab23271b1d572c7d718b517` | `88e427b70cf6247ec719c5b4f011a7e0360db664dbe14e1b044ccc9510759bb0` |
| `diagnostic-bailout.json` | `6216d9320177beab593322f76bf04f36c958830081a98da9095bdfd4ff3df6ad` | `6467cb33e154a2c74e16887df7747dd5a0394933434288ed533aea4961601a20` |
| `network-restoration.json` | `e0bc78d72de99749000745d8a56778b4d2d7771836284628b6e1c96c9d8f4e33` | `dfac8dc9e3040f3e6bb4c99687a4f79e53eca4c5d88f0c493ebc6d4ec34e8602` |
| `stay-awake-restoration.json` | `8e8e733100a54f3573b05d250a0f2d383be4eeeb64c1c85855316169f11481ee` | `6b4498657683f4deee9b99cd67bb860b48b2768cc4e283ece4b03d0b6fa86fb6` |
| `summary.json` | `a9a7dd6a9de6e07cedc298b9b0e19146d2c9b2ffef2ac9c388291c1ccb3495b5` | `7868186a186cd7f90899b66315b5e44079f73ab93f586e5b6458bf0e0cc8fb33` |
| `telemetry.jsonl` | `322ace69430380e7cb40de38d368b6aec0635e688c5c280e523817c8bbb9ce05` | `85e5fc04816fb7a0ab5fa89e841c4c569ab09b4e605a16de7a462f5cab6295b4` |
| `trace.jsonl` | `15acaec37ee738abbe90ea39cfe50584f03cf7fde03b3024888778e982d64ce1` | `bdd8272d6afbaeb9b9e8a87873ef7115b3fce447f7f6b2f01b79a19689f8a628` |
| candidate APK | `5b27c891fe155ee4d26e4da68f8323f178f7116e73d8097ce07199e5800e318b` | same |
| fixture APK | `223219c17a31439b52698e769bdf03ead0998bbbe8bbb5c1b0ff5be3cfaf21dc` | same |

Both mounted source directories remain unmodified.

## Matrix boundary

No formal KR-003 matrix row advances to PASS. Each run contributes another configuration-specific, non-poolable 100-row automated set with p95 below two seconds, but each required checkpoint 3 is INVALID. `TIME-04`, SAFE/TAMP, lifecycle, permission-revocation, Play and production gates remain open.
