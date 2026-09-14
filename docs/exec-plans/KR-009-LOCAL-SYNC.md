# KR-009 bounded local control/sync/ack

- **Goal:** Demonstrate parent JWT operation → canonical PostgreSQL state → authenticated device snapshot → existing Room accounting/pending ACK → authenticated report → truthful parent-visible operation status.
- **Context:** Clean verified baseline `cde74f6`; Issue #9; OD-47 recorded before implementation. ADR-0003/0005/0006 and current protocol/state/time remain authoritative. Existing KR-004 control transaction, KR-007 credential lifecycle and KR-008 A/B recovery are reused.
- **Constraints:** Local loopback, task-owned Docker/network and existing owned API-36 emulator only. No FCM, provider addressing, enforcement, physical execution, deployment/distribution, next issue, new identity/policy architecture or modification of earlier PRs/evidence. No credentials/raw policy/package history in logs/evidence.
- **Done when:** Actual SQL/HTTP/Room tests cover idempotency, version/period ordering, restart/outage/response loss, pending ACK transaction seams, scope/auth failures and truthful status; focused and required regressions/build/lint/security/CI pass; all attempts/identities and gaps are recorded, resources cleaned, bounded commits pushed and Issue #9/new draft PR synchronized without closing full acceptance.

Use bounded latest-snapshot convergence and explicit sync first. Push/provider and performance/physical acceptance remain separately unrun. No adapter means no applied-enforcement claim.
