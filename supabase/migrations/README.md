# KR-004 local schema migrations

- **Goal:** executable AC-1–4 model/RLS under OD-42, not deployment.
- **Context:** [backend model](../../docs/product-specs/BACKEND.md), ADR-0003/0006.
- **Constraints:** synthetic task-owned database only; client reads only. No new control/gateway RPCs.
- **Done when:** migration + real-role pgTAP pass; see [execution evidence](../../docs/test-plans/evidence/KR-004-LOCAL-DB-2026-09-11.md).

`202609110001_schema_rls.sql` creates nine public and six private application tables.
Auth schema/users/functions/roles are Supabase prerequisites, not KidRemote replacements.
The migration is atomic and includes RLS, explicit grants/revokes, composite tenant FKs,
OD-12 membership uniqueness, numeric bounds and indexed FK/tenant access paths.
No implicit cascade deletion or client mutation policy is supplied.

Execute via [the local test runner](../tests/README.md). It always creates a new DB container:
there is no reset/resume mode and no remote connection string option. The application model
starts empty, while the pinned Supabase image supplies its own Auth/database initialization.
This does not claim a full Auth/PostgREST/Edge integration environment.

## Deliberate remaining boundaries

- No product RPC/view is introduced; normal client roles cannot write or create objects.
- Future private/definer functions require explicit EXECUTE revocation and review.
  Global PostgreSQL PUBLIC EXECUTE defaults cannot be subtracted by per-schema revokes.
  The migration locks that default for its owner only; a different migration owner needs
  its own explicit defaults/revokes and tests.
- Tenant relationships are structural; verified actor membership at privileged writes,
  monotonic updates, future receipt/version rejection, total daily grant cap under concurrency,
  timezone-name validation against IANA, typed payload allowlists and atomic control/outbox
  transactions remain server-route/transaction work. No schema PASS certifies those paths.
- Existing logical text fields without accepted enum vocabularies (e.g. deletion/outbox
  state and health) stay nonempty text; no new product state machine is invented here.
- Deletion, retention workers, gateway HTTP predicates, pairing and production exposure
  are not implemented by this migration.

Official references verified 2026-09-11:
[Supabase RLS and grants](https://supabase.com/docs/guides/database/postgres/row-level-security),
[PostgreSQL RLS](https://www.postgresql.org/docs/17/ddl-rowsecurity.html),
[default privileges](https://www.postgresql.org/docs/17/sql-alterdefaultprivileges.html).
