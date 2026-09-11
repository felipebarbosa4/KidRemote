# KR-004 local schema migrations

- **Goal:** executable local model/RLS/control under extended OD-42, not deployment.
- **Context:** [backend model](../../docs/product-specs/BACKEND.md), ADR-0003/0006.
- **Constraints:** synthetic task-owned database only; no direct client table writes or deployment.
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

`202609110002_atomic_control.sql` is the forward-only AC-6 extension: nullable legacy
request-digest/expected-version fields and one explicitly authorized parent transaction.
See [control semantics and tests](../functions/CONTROL-TRANSACTION.md). Migration 001
and its recorded 01/02 test files are unchanged; all run again after the extension.

## Deliberate remaining boundaries

OD-43 adds `202609110003_pairing.sql` on the unmerged KR-004 dependency:
scoped creation/cancel/recovery and service-only atomic redemption. See the
[pairing threat model and contract](../functions/pairing/README.md). The existing
combined checker now includes pairing SQL, twenty-worker concurrency and real
loopback HTTP-to-pairing-SQL tests with `--pairing`; no new database framework/reset.

- No view is introduced; normal client roles cannot write tables or create objects.
  Authenticated parents alone can invoke the narrowly scoped `accept_control` function.
- Future private/definer functions require explicit EXECUTE revocation and review.
  Global PostgreSQL PUBLIC EXECUTE defaults cannot be subtracted by per-schema revokes.
  The migration locks that default for its owner only; a different migration owner needs
  its own explicit defaults/revokes and tests.
- Actor membership/revocation, serialized control versions, typed control payloads and
  atomic grant/command/audit/outbox writes are now executed transaction tests, not merely
  structural claims. HTTP gateway storage integration, receipt/report persistence and
  a confirmed-parent Auth API remain outside this local SQL proof.
- Existing logical text fields without accepted enum vocabularies (e.g. deletion/outbox
  state and health) stay nonempty text; no new product state machine is invented here.
- Deletion/retention workers and production exposure are not implemented.
  Gateway HTTP predicates are separately tested with explicit storage stubs; SQL RLS
  does not prove privileged gateway authorization.

Official references verified 2026-09-11:
[Supabase RLS and grants](https://supabase.com/docs/guides/database/postgres/row-level-security),
[PostgreSQL RLS](https://www.postgresql.org/docs/17/ddl-rowsecurity.html),
[default privileges](https://www.postgresql.org/docs/17/sql-alterdefaultprivileges.html).
