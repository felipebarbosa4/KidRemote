# KR-004 local atomic parent control

The forward migration `202609110002_atomic_control.sql` adds a single public,
authenticated-only `accept_control(operation_id, device_id, kind, payload, expected_version)`
entrypoint. It has no caller/household argument: the actor is trusted `auth.uid()`.
It is a reviewed `SECURITY DEFINER` owned by the migration owner, with empty search path,
qualified application objects, no dynamic SQL and explicit EXECUTE revocation from
PUBLIC, anon and service_role. Client table writes/private grants remain unchanged.

This is the local SQL transaction boundary, **not** a parent HTTP login/control service.
Auth JWT validation/confirmed-parent checks at the eventual HTTP boundary remain integration
work; passing a caller identity in JSON is never allowed to substitute for trusted claims.

## Semantics

- Only LOCK, UNLOCK, SET_DAILY_LIMIT and ADD_TIME with exact approved payloads are accepted.
- A transaction-scoped advisory lock serializes the global operation ID; a device row lock
  serializes changes to that device. Membership/household shared locks and the policy row
  lock protect authorization, deletion state, timezone and current version until commit.
  Future revocation/lifecycle transactions must respect a consistent lock order.
- Current actor membership, device revocation and household state are rechecked even for
  retries. The same actor/target/kind/canonical request digest returns the original result;
  conflicting reuse is generic `OPERATION_CONFLICT` and never reveals a foreign command.
- Desired-state edits require the current expected version. Distinct ADD_TIME operations
  serialize and retain exact grants. Both additions and limit edits enforce base + today's
  bonus <= 86,400; integer bounds, 600/1800 additions and no implicit initial limit are preserved.
- Server time is sampled **after lock acquisition** for the household period; stale new
  grants conflict. An identical accepted retry retains its original period/version even
  after the day changes, without granting again. Household timezone validation fails closed
  through PostgreSQL timezone interpretation; no timezone-edit API is introduced.
- Policy/version, command, applicable grant, minimal audit and pending outbox commit in
  the caller's one database transaction. No push/network call occurs. No usage report is
  rewritten, and adding time never clears manual lock.
- Request digest and expected-version columns are additive/nullable for legacy rows;
  a legacy row lacking a matching digest cannot be silently replayed as an accepted retry.
  No command pruning or tombstone-deletion worker is implemented here.

## Executed tests

`03_atomic_control.test.sql`: 57 assertions, including per-write AFTER-trigger failure
injection and full business-state rollback, explicit caller rollback, identical/conflicting
retries, payload/version/day/cap/actor/revocation checks and minimum function privilege.

`04_concurrent_control.test.sql`: 44 assertions with two actual PostgreSQL sessions via
test-only dblink over the exclusive container's Unix socket. Workers use `authenticated`
with synthetic claims, not owner-role operations. Tests explicitly observe the losing worker
waiting on a lock before committing the winner. Covered: duplicate operations, distinct
grants, cap races, stale Lock/Unlock, cross-device operation-ID reuse, and membership deletion
or device revocation committed while the other session waits. Setup/revocation writers alone
use the task DB owner. The synthetic fixtures must be committed for other sessions to see
them; the whole task DB is removed afterward, not retained as a service.

Sources reviewed 2026-09-11: [PostgreSQL locks](https://www.postgresql.org/docs/17/explicit-locking.html),
[function security](https://www.postgresql.org/docs/17/sql-createfunction.html),
[dblink](https://www.postgresql.org/docs/17/dblink.html).
