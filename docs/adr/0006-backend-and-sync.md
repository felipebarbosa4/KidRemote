# ADR-0006 — Supabase and versioned desired state

Status: Recommended technical baseline; provisioning/budget and production acceptance **UNSPECIFIED**.

- **Goal:** Keep authorization, commands and recovery simple and inspectable.
- **Context:** PostgreSQL/Supabase preferred; 1,000 parents/5,000 devices is only a load-test assumption.
- **Constraints:** One DB, no microservices/complex event platform; mobile clients never get elevated keys.
- **Done when:** KR-004/009 implement local RLS and end-to-end duplicate/order/failure tests.

## Alternatives evaluated

Supabase/PostgreSQL/Auth/Edge: fits relational households, transactions and RLS with one managed system.
Firebase-only backend: FCM is valuable, but replacing the preferred relational model adds no demonstrated benefit.
Self-hosted API/PostgreSQL: full control but more auth/operations work and budget uncertainty.
Command-only event replay: easy conceptual log, but requires replaying stale toggles and careful additive deduplication.
Desired-state only: excellent convergence but insufficient user-facing intent/audit history and dated grant identities.
Recommended hybrid: auditable unique intents, monotonically versioned desired state, immutable dated grants and absolute bonus totals.

## Decision and reasons

Use Supabase for canonical data and parent Auth, with device routes implemented in Edge.
Push outbox is in the same PostgreSQL transaction as accepted control; a bounded dispatcher sends hints after commit.
Optional Realtime can improve parent freshness later, but MVP uses authoritative refresh and polling while visible.
No provider receipt counts as a device acknowledgement.
[Supabase Auth](https://supabase.com/docs/guides/auth),
[migrations](https://supabase.com/docs/guides/local-development/database-migrations),
[FCM receive](https://firebase.google.com/docs/cloud-messaging/android/receive-messages).

## Security/privacy implications

RLS for parent reads and dedicated device gateway tests; privileged keys bypass RLS.
Keep credentials/pairing/push/audit internal; enforce per-device transaction predicates.
No policy/content in FCM data hints. Opaque provider address is not an authorization token.
[Supabase keys](https://supabase.com/docs/guides/getting-started/api-keys).

## Operational implications

Use indexed membership/device/version lookups, bounded sync pages, idempotency tombstones and jittered retry.
Edge lifecycle is finite: no infinite loop/timer assumed. Dispatcher invocation/cron credentials must be configured and tested.
Background work does not make mobile push a guaranteed five-second service.
Current FCM fid/token migration is explicitly addressed in CONTRACT and KR-009.

## Risks and invalidation tests

Service-key authorization bugs, missing outbox row after commit, forged acknowledgements, stale snapshot races and load amplification.
Invalidate if two-parent/two-child negative tests fail, grants double-apply, response snapshots mix versions,
a crashed dispatcher loses canonical command state, or target p95 cannot be met with reasonable indexes/batching.
Hosting costs/tier **UNSPECIFIED**; measure before selecting capacity.
