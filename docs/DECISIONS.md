# Decision and unknown register

- **Goal:** Make current authorization discoverable without changing approved product semantics or rewriting evidence.
- **Context:** The original detailed register is preserved byte-for-byte in [DECISIONS-LOG](DECISIONS-LOG.md). Read the [current execution summary](exec-plans/TASK-CONTRACT.md#current-execution) first.
- **Constraints:** This index adds no device, destruction, real-data, deployment, distribution, merge, or acceptance authority. Unchosen facts remain **UNSPECIFIED**.
- **Done when:** Agents can identify the current task and controlling accepted scope without treating every historical “next action” as live.

## Current decision index

| Subject | Controlling accepted record and boundary |
| --- | --- |
| Minimal product, manual lock, allowance and time | OD-01–05, OD-08–12, OD-18–20 and accepted ADRs in the preserved ledger; [PRODUCT](PRODUCT.md) and [state machine](product-specs/STATE-MACHINE.md). No semantics are reopened here. |
| KR-003 acceptance | OD-06/07 and the subsequent qualification decisions; [ADR-0002](adr/0002-android-enforcement.md), [matrix](test-plans/MATRIX.md). Physical qualification and full owner acceptance remain open. |
| Local foundation despite open KR-003 | OD-42: bounded KR-004 schema/RLS; OD-43: local pairing; OD-44: parent auth and its emulator extension; OD-45: enrollment and its explicit camera/storage/rotation/removal extensions. These replace only their named prior holds. |
| Local accounting, sync and parent controls | OD-46 and extensions; OD-47 and extension; OD-48. Scope remains synthetic/local, not real-family use or public release. |
| Product enforcement integration | OD-49 and extensions: reuse the existing candidate with the actual product stack, keeping desired policy, observed adapter state and durable ACK separate. No production acceptance follows. |
| Dedicated synthetic physical lab | OD-50/51 and explicit extensions only. Exact ownership, device/APK provenance, consent, independent oracle and cleanup requirements remain. Past destructive permission is not a general reset permission. |
| Active continuation | [Pairing-cleanup callback recovery](exec-plans/PRODUCT-PAIRING-CLEANUP-CALLBACK-RECOVERY.md), with [preserved attempt evidence](test-plans/evidence/PRODUCT-PAIRING-CLEANUP-CALLBACK-2026-09-17.md). Its bounded autonomous continuation supersedes the former handoff for this task only; no historical result is upgraded. |
| Visual tooling | OD-41 lab-only exception remains narrow; later owner priority pauses optional capture/classifier/dedup/alignment work. It is not a prerequisite for current product progress and does not authorize production capture. |

The full wording, original dates, tradeoffs and limits remain in the [preserved decision ledger](DECISIONS-LOG.md). The current task summary is an index, not a substitute for that approval evidence. Append actual future decisions to the ledger and update this index/current task together. A newer plan or source change cannot invent consent or acceptance.

## Blockers and work that can proceed

Continue safe, non-destructive repository-local work covered by the active recovery task and approved architecture without routine owner handoffs. Physical actions still require the current operator authorization, exact preconditions and genuine human checkpoints. This harness-maintenance request does not itself request a device run.

The earlier September 10 statements that KR-004 development remained prohibited are historical: OD-42 and subsequent scoped exceptions explicitly changed that local-development boundary. They did not close KR-003 or approve a private-alpha support/distribution boundary. Likewise, later scoped continuations do not authorize adjacent work merely because it is useful.

Real-family use, broader hardware support, deployment, FCM/provider setup, public distribution, external Play acceptance and merging the existing draft stack remain outside this reconciliation. Follow their separate unresolved gates; never label them approved from a build, emulator result or local lab permission.

The latest classified physical attempt and exact next task live in [one current execution summary](exec-plans/TASK-CONTRACT.md#current-execution). Dated Sprint 01 notes and old handoff instructions remain history, not additional active schedulers.
