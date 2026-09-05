# First ten prioritized issues

- **Goal:** Give an agent one bounded, testable unit of work at a time.
- **Context:** Initial architecture creates proposed content; implementation and owner/physical acceptance remain separate.
- **Constraints:** Dependency/gate ordering overrides a numeric list; points are relative estimates.
- **Done when:** Each issue has explicit scope, acceptance, tests, security and linked source-of-truth documents.

KR identifiers are stable repository planning IDs, not assumed GitHub issue numbers.
Publication mapping is in [PUBLISHED](PUBLISHED.md). Full bodies below are the source for the publisher.
Project fields are metadata; the repository docs define the technical behaviour.

| ID / full body | Title | Priority | SP | Risk | Dependencies | Milestone | Concise acceptance |
| --- | --- | --- | --- | --- | --- | --- | --- |
| [KR-001](issues/KR-001.md) | Approve the MVP product contract and screen-time state machine | P0 | 3 | High | None | Architecture & Feasibility | Given manual_lock=true and remaining=0, when the approved Unlock behaviour is exercised, the expected remaining block reason is specified and tested in fixtures. |
| [KR-002](issues/KR-002.md) | Verify the repository, agent map, documentation and CI foundation | P0 | 2 | Low | None | Architecture & Feasibility | A new agent can navigate README → issue → spec/ADR → test plan and state Goal/Context/Constraints/Done when. |
| [KR-003](issues/KR-003.md) | Prove or reject consumer Android enforcement and Play feasibility | P0 | 8 | High | KR-001, KR-002 | Architecture & Feasibility | The four-option ADR covers actual enforcement, setup, versions, policy, uninstall/disable, reboot, OEM, consent, bypasses and invalidation tests. |
| [KR-004](issues/KR-004.md) | Implement local schema and prove RLS and gateway trust boundaries | P0 | 5 | High | KR-001, KR-002 | Architecture & Feasibility | Migrations build the model from empty local DB with keys, composite tenant FKs, uniqueness, numeric constraints and needed indexes. |
| [KR-005](issues/KR-005.md) | Validate single-use QR pairing and device-authentication protocol | P0 | 3 | High | KR-001, KR-004 | Architecture & Feasibility | OD-09/10/20 outcomes are recorded; unapproved choices stay UNSPECIFIED. |
| [KR-006](issues/KR-006.md) | Build parent authentication and sole-owner household foundation | P1 | 5 | Medium | KR-001, KR-002, KR-004 | Android Alpha | Owner approves framework/Auth/sole-owner decisions before bootstrap; stable tooling versions are verified and recorded. |
| [KR-007](issues/KR-007.md) | Implement child enrollment, scoped identity and permission-health setup | P1 | 5 | High | KR-003, KR-005, KR-006 | Android Alpha | Successful pairing creates exactly one correct-household identity and the child cannot call sibling/parent routes. |
| [KR-008](issues/KR-008.md) | Build the persistent local screen-time accounting engine | P1 | 8 | High | KR-001, KR-002, KR-003 | Android Alpha | Eligible interactive/keyguard-hidden intervals count once; screen-off/locked/sleep/blocked-screen intervals do not consume allowance. |
| [KR-009](issues/KR-009.md) | Implement idempotent control, sync, acknowledgements and FCM hints | P1 | 8 | High | KR-004, KR-007, KR-008 | Android Alpha | Every operation has unique ID, target, authenticated actor, server timestamp, ordering/version, payload and status; duplicate same payload returns original result. |
| [KR-010](issues/KR-010.md) | Build minimal parent controls and child blocked/health UI | P1 | 5 | Medium | KR-003, KR-006, KR-009 | Android MVP | Parent list/detail implement every required state with nickname, last reported time/lock reasons, freshness and health. |

The first sprint targets KR-001–005 under the capacity assumptions in [SPRINT-01](../exec-plans/SPRINT-01.md).
KR-003 may invalidate the consumer product path; that outcome is valuable evidence, not a reason to proceed to production anyway.
Use [the reusable issue template](ISSUE-TEMPLATE.md) for future work.
