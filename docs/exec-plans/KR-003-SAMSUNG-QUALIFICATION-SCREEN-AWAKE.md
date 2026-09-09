# KR-003 Samsung qualification screen-awake repair

- **Goal:** Preserve and classify the 100-row Samsung qualification attempt that stopped at checkpoint 3, then publish a reversible stay-awake runner without executing it.
- **Context:** Exact run `run-20260909-012601-0d666cb9` used runner-v9 on the calibrated `samsung` / `SM-X400` / Android 16 API 36 configuration. It retained 100 automated PASS rows but stopped `INVALID:SCREEN_OR_KEYGUARD` before any checkpoint-3 physical response.
- **Constraints:** The run remains one independent INVALID and cannot be resumed, pooled or converted to PASS. No root, device-owner assumption, lock-security change, raw battery/settings output, new physical execution, production code or KR-004 work. Unknown awake state or failed restoration remains INVALID/fail closed.
- **Done when:** Strict ingestion reports the 100 rows, statistics, checkpoint outcomes and cleanup boundary; retained facts are separated from inference and unspecified cause; runner-v10 captures, enables, verifies and restores Android's stay-awake-while-plugged-in state; PowerShell 5.1/7, Node, validation, isolated Android and CI checks pass; a clean-source immutable replacement is hash-verified; Issue #3 and PR #16 reflect the INVALID attempt; execution stops before another physical run.

## Execution boundary

1. Hash and ingest the mounted evidence without modifying it.
2. Treat automated row evidence and human checkpoints separately. One hundred valid automated rows followed by an incomplete/invalid checkpoint remains INVALID and supplies no resumable qualification.
3. Record only coarse power-source and stay-awake setting state. Do not retain raw `dumpsys battery` or `settings` output.
4. Require an already unlocked/interactively eligible device, a recognized plugged power source, successful Android stay-awake enablement and readback before qualification.
5. Reverify the setting, plugged state and candidate eligibility throughout unattended cycles and owner prompts.
6. Restore the exact original stay-awake setting in finalization, verify it independently, and never overwrite the primary result with cleanup failure.
7. Stop after immutable publication and administrative synchronization.
