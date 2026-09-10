# KR-003 visual-channel calibration preparation

## Focused validity review — 2026-09-10

- **Goal:** Falsify classifier independence and temporal substitution claims using synthetic features/timelines only.
- **Context:** Clean review baseline `630eaad4cfa84d40aedf8ead6f93c593f1c212c3`; immutable bundle/source `0596173` remains physically Not run. The earlier conversation recap's `8416583` was stale, not the completed visual-task head.
- **Constraints:** KR-003 only; no ADB/device/media access, bundle mutation/publication, Android rebuild, capture-system redesign, historical reclassification or pooling.
- **Done when:** Counterexamples execute against the unchanged classifier, scope corrections and PR path correction are recorded, focused tests/repository validation pass, and review stops without a physical command.

## Synthetic deduplication prototype — 2026-09-10

- **Goal:** Reuse exact image recognition without losing per-frame evidence, and measure end-to-end analysis cost against an uncached frozen-reference baseline.
- **Context:** Preserve the reproduced v1 validity findings; deduplication cannot repair circular references or missed captures. Prototype references are independently authored synthetic full-pixel images, never learned from evaluated phases.
- **Constraints:** Repository-local synthetic inputs only; no device, private media, production path, bundle publication, qualification, approximate equality, unrelated build or KR-004 change. No integration into the published runner.
- **Done when:** Focused equality/context/unknown/timing tests and measured counts pass, review plus bounded prototype are committed, and handoff names unresolved sensitivity/reference calibration without requesting execution.

Outcome: [synthetic report](../test-plans/KR-003-VISUAL-DEDUP-PROTOTYPE.md) records exact-match correctness, unchanged review findings, native PowerShell tests and measured repeated/all-novel runtime. No physical or packaging operation is part of this prototype.

## Original preparation contract (completed)

- **Goal:** Prepare one immutable, short, excluded local-only visual-channel calibration for the exact authorized Samsung configuration.
- **Context:** OD-41 prospectively permits calibrated visual evidence to replace eligible human VISUAL checkpoints only after a configuration-specific channel calibration agrees with the independent fixture/input/focus oracle. The completed dual-Home diagnostic and immutable full runner-v12 bundle remain unchanged.
- **Constraints:** No device execution by the agent; no full qualification; no network mutation; no raw visual content in the repository, GitHub, CI, remote tools or assistant vision; no candidate APK capture feature; no secure-content bypass; zero qualification/TIME-04 rows and no matrix PASS; preserve failures and historical evidence; KR-004 untouched.
- **Done when:** The lab-only decision and retention boundary are recorded, the bounded capture/classifier runner has synthetic PASS/FAIL/INVALID and cleanup tests on Windows PowerShell 5.1/7, one immutable physically-unexecuted bundle is published, Issue #3 and draft PR #16 are synchronized, and handoff stops at one owner-operated command.
