# Sprint 01 — Architecture and feasibility (one working week)

- **Goal:** Establish an approved product contract and evidence-based Android/backend/pairing path.
- **Context:** Architecture docs/backlog exist; production enforcement is unproven.
- **Constraints:** Five working days, no full MVP promise. Team size, start date, device inventory and availability **UNSPECIFIED**.
- **Done when:** Product gates reviewed, repository checks pass, feasibility evidence has a go/no-go, RLS and pairing designs are testable.

## Scope and capacity

Recommend KR-001 (3), KR-002 (2), KR-003 (8), KR-004 (5), KR-005 (3): **21 relative points**.
Points express uncertainty/relative effort, not hours or known team velocity.
This is conditional on two contributors (Android feasibility and backend/design) plus timely owner review and test devices.
If one contributor is available: commit KR-001/002/003; KR-004/005 deliver reviewed designs as stretch, not falsely completed migrations/tests.
The architecture-pass documents provide a starting point but do not satisfy physical-test acceptance.

## Dependency-based daily plan

| Day | Focus | Reviewable output |
| --- | --- | --- |
| 1 | KR-001 owner decisions; KR-002 docs/checks | Signed/recorded state semantics or explicit blockers; working validation; tooling decisions only if bootstrapping |
| 2 | KR-003 permission/runtime/safe blocking spike; KR-004 schema | Native disposable spike on authorized lab device; two-tenant data/RLS fixtures |
| 3 | KR-003 restart/offline/clock/emergency tests; KR-004 deny tests | Measured failures and supported-boundary draft; local migration + allow/deny evidence |
| 4 | KR-005 pairing transaction/security tests; KR-003 policy packet | QR race/replay/interruption evidence or blocked result; disclosure/least-privilege review |
| 5 | Resolve contradictions and review go/no-go | Updated ADR status, residual risks, next ready issues; no premature production enforcement |

No calendar dates or personal assignees are invented. Iterations are seven calendar days containing five working days; holiday handling **UNSPECIFIED**.

## Exit criteria

- OD-01–05/09/10 either approved with rationale or marked blocking dependent implementation.
- KR-002 scaffold validation and CI configuration reviewed; actual remote CI result distinguished from local checks.
- KR-003 reports observed enforcement/boot/offline safety and policy conclusion; unsupported claims removed.
- If devices unavailable, KR-003 remains Blocked; documentation alone cannot close it.
- KR-004 includes reviewed RLS matrix and, for full completion, executable local allow/deny tests under client roles.
- KR-005 includes threat model, atomic redemption/idempotency and interrupted-response recovery tests for full completion.
- No production table exposure, main enforcement build, store submission or final pairing before respective gates.
- KR-006–010 become Ready only as prerequisites and owner decisions allow.

Next sprint may pursue parent Auth, child identity and domain engine after feasibility gates. Full Android MVP remains a separate milestone.
