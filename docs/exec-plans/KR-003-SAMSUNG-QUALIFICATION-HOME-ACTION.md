# KR-003 Samsung qualification Home-action checkpoint

- **Goal:** Preserve and classify runner-v10 run `run-20260909-101646-69c0fb84`, distinguish automated hold-oracle failure from an owner result, and publish only a configuration-neutral Home-action checkpoint correction if justified.
- **Context:** The exact Samsung qualification retained 100 automated PASS rows and a final-visible owner PASS, then stopped `FAIL:RESTRICTION_LOST` while `HomePhysical` was still `UNRECORDED`. Sanitized candidate trace records an out-of-sequence overlay Settings-button activation immediately before the hold invariant failed on an allowed safe-system transition.
- **Constraints:** Do not rewrite, resume, pool, downgrade or rerun the physical evidence; do not change device navigation mode, candidate enforcement semantics, permissions, safe-surface policy or oracle thresholds; retain no raw settings, UI content, nodes, screenshots, account/package history or identifiers; UNKNOWN remains fail closed; KR-004 remains untouched.
- **Done when:** Exact rows/statistics/checkpoint timeline and cleanup are recorded with OBSERVED/INFERRED/UNSPECIFIED boundaries; a future runner uses a minimized navigation-mode enum and explicit current-mode Home instruction, distinguishes owner response from automated hold failure and out-of-sequence Settings activation, passes PowerShell 5.1/7, Node, Android isolation, repository and CI checks, and is published immutably without execution.

## Plan

1. Strictly ingest and independently recompute all 100 rows and checkpoint-3 state/fixture transitions from the mounted directory.
2. Preserve the top-level FAIL while recording that no Home response/action is established and that the automated hold oracle observed an allowed safe-system transition after the overlay Settings control activated.
3. Add a read-only current-user `navigation_mode` parser with only `THREE_BUTTON`, `TWO_BUTTON`, `GESTURE` or `UNKNOWN`; persist no raw value/output and stop INVALID before qualification when unknown.
4. Make the Home prompt describe the current system action, prohibit the Settings control until the next phase, and retain typed Home-action result/failure-source fields.
5. Keep actual ordinary-surface restriction loss fail-closed as FAIL; classify out-of-sequence Settings-button activation as an INVALID Home action, without changing historical evidence.
6. Validate, commit, publish a clean-source immutable successor, synchronize Issue #3/PR #16 and stop before physical execution.
