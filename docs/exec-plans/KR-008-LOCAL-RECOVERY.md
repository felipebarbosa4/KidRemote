# KR-008 AC-7 local recovery

- **Goal:** Demonstrate the owner-approved A/B recovery rule for local KR-008 AC-7.
- **Context:** Clean baseline `82e3d05d7dbf90023f1643d2a42261e0fea69dd1`, existing branch `kr-008-local-accounting`, draft PR #21 and Issue #8. OD-46 extension recorded in DECISIONS before implementation; OD-04/OD-05 remain approved. Existing reducer, encrypted identity, Room schema 2 and prior update evidence are retained.
- **Constraints:** Canonical trusted inputs are fixtures/local interface only. No new network trust, receipts, parent reset, enforcement, physical ADB, Samsung, battery acceptance or KR-009. No package history. Preserve failed attempts separately and all historical evidence unchanged.
- **Done when:** Complete bounded suffix and strictly newer trusted period recovery pass deterministic tests and real Room/write-failure/process-kill tests on the existing task-owned emulator; affected update/core regressions, lint/build/security and required CI pass; new classified evidence is committed and Issue #8/PR #21 synchronized without closure/merge.

Implementation: retain unresolved suffix endpoint and highest observed boot in the existing ledger payload; validate the entire suffix before mutation; advance/re-anchor only from bound trusted input; record a minimal durable write intent so failed/interrupted Room writes cannot masquerade as known accounting after restart. Keep Room schema/migration validation unchanged. Legacy payloads remain readable; legacy uncertainty without a recorded endpoint requires trusted newer-period recovery.

Validation: JVM fixtures, actual Room transaction kills before/after commit, injected SQLite write abort followed by restart, malformed intent/input rejection, core runtime and actual APK update regression. Results belong in `docs/test-plans/evidence/KR-008-RECOVERY-2026-09-13.md`; no runtime/build success is assumed in this contract.
