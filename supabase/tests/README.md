# KR-004 disposable local database tests

OD-42's prospective extension authorizes local AC-5–7 after the retained AC-1–4 evidence.
SQL/pgTAP executes on real Supabase PostgreSQL, not a mocked database. Gateway HTTP tests
execute the actual handler on loopback with explicitly stubbed storage dependencies.
No remote endpoint, production credentials, real Auth account, HTTP signup, deployment,
published database port or host privilege change is used.

OD-43 separately authorizes KR-005 local pairing, stacked on unmerged KR-004.
The same checker now also runs suites 05/06 and real loopback HTTP-to-pairing-SQL
integration. This does not widen OD-42 or authorize downstream issues.

## Run

Prerequisites: Node.js and an already-running **local Linux Docker engine**.
The image is pinned to Supabase's officially published PostgreSQL 17.6.1.136:
`sha256:f371b5f3f2ac0a05703f33d6e6134515fb2498cab708fb948a0aeb7481467c00`.
It contains PostgreSQL 17.6, Supabase Auth SQL/roles and pgTAP. Pulling the image on first
use downloads software only; it uploads no project data. This is a local test-tool pin,
not a hosting, production support or Supabase project decision.

Linux / CI:

```sh
node tools/kr004/check-local.mjs docker unix:///var/run/docker.sock
```

Existing WSL environment with native Windows Docker Desktop client:

```sh
node tools/kr004/check-local.mjs "/mnt/c/Users/3feli/AppData/Local/Programs/DockerDesktop/resources/bin/docker.exe" "npipe:////./pipe/dockerDesktopLinuxEngine"
```

This uses the explicit named pipe, not the WSL Docker shim. The temporary password is
randomly generated in process memory, forwarded through process-scoped WSLENV for native
Windows Docker, and never put into command arguments or output. No persistent WSL or Docker
setting is changed. Do not run with shell tracing or publish Docker inspect environment dumps.

## Identity, isolation and cleanup

The runner allocates a unique `kr004-ac14-<UUID>` container, with its own ownership label,
pinned image, network `none`, no published ports, no shared/bind volume and tmpfs data.
Before starting/migrating it verifies the returned 64-character ID/name/label/image/network/
mounts and records sanitized identity. After image bootstrap it requires database `postgres`,
migration user `supabase_admin`, zero application tables and the real `auth.uid()` prerequisite.
The database name is only shared spelling: the instance/container and data are newly allocated.

Migrations execute in filename order. Suites 01–03 roll back their synthetic fixtures,
temporary privilege changes and pgTAP setup. Suite 05 also rolls back. Suites 04/06 deliberately commit synthetic fixtures
so independent database sessions can exercise real concurrency; the disposable DB is removed
afterward. dblink connects only to the same exclusive container's Unix socket, never another
database instance. The runner rejects missing required migrations/suites and empty/skipped tests
and TAP failures. Finally it revalidates exact ownership, removes only that container,
and verifies absence with a successful filtered local listing. The original error is not
overwritten by cleanup failure. No prune or arbitrary existing-target reset is provided.

On an externally killed process/engine loss, the exact reported container may remain.
Do not delete by wildcard or reset shared resources. First inspect that **exact recorded ID**
and verify its task label/name/image. Only then remove that single task container; if its
identity is uncertain, stop. No restart/resume of that database is required; the next test
invocation creates another fresh one. Committed sanitized execution evidence is retained;
the disposable synthetic database is intentionally not an evidence archive.

## Suites and boundaries

- `01_rls.test.sql`: actual `SET LOCAL ROLE authenticated/anon` with synthetic A/B
  `request.jwt.claim.sub`, and the image's existing `auth.uid()`; proves own/foreign
  reads/writes/joins, minimum grants, private table/function denial, self-promotion denial,
  null auth, absent policy/grant and inactive/deleted membership with unchanged subject.
  Real role, no BYPASSRLS, no table ownership are asserted. Profile self-read remains
  allowed after membership removal, as specified; tenant data does not.
- `02_constraints.test.sql`: privileged synthetic setup deliberately attempts malformed
  rows to prove relational/numeric constraints independently of client-grant denials.
- Node lifecycle tests use fake Docker only to test orchestration guardrails and cleanup.
  Their PASS is **not** database evidence; CI separately executes all actual SQL suites.

Suites 01/02 remain byte-for-byte unchanged as AC-1–4 regressions. Suite 03 proves
the [actual atomic control function](../functions/CONTROL-TRANSACTION.md), rollback,
idempotency and privileged actor checks. Suite 04 adds observed two-session locking races.
The original absent-RPC assertion is retained; the new actual `accept_control` privilege
and authorization boundary is tested separately, not inferred from an absent function.

`check-local.mjs` runs repository validation, all Node HTTP/guard tests, the actual DB
runner, and worktree/staged/commit whitespace checks, failing on the first error.
The same command runs in required CI alongside the unchanged Windows/Android jobs.
The **local reset procedure is another fresh invocation**: allocate and verify a new
task container, replay all versioned migrations, run all suites, verify exact-target removal.
There is no in-place DROP/reset option accepting arbitrary database/container targets.

Claims represent trusted post-authentication SQL context. No JWT signatures, Auth HTTP
login, PostgREST role switching or deployed Deno/Edge runtime is validated. Device
credential hashing/verification and HTTP authorization run in the actual handler, with
synthetic storage dependency callbacks: this is AC-5's explicitly permitted HTTP/stub
evidence, not database-backed gateway storage integration. Device sync/ack persistence,
push-provider delivery and credential rotation remain later integration work.
KR-005 pairing transactions are real SQL, including 20 concurrent sessions and
commit-response-loss recovery. The checker passes `--pairing` to the same runner
for the real pairing HTTP/SQL bridge; the gateway's business-operation storage
callbacks remain stubs even when credential/device records come from that database.
AC-7 is the reproducible **local** pre-exposure check, not authorization to expose services
or a statement that every production security/lifecycle requirement is complete.

[Supabase database tests](https://supabase.com/docs/guides/database/testing),
[official image selection](https://github.com/supabase/supabase/blob/master/docker/docker-compose.yml),
[Supabase Auth SQL](https://github.com/supabase/postgres/blob/develop/migrations/db/init-scripts/00000000000001-auth-schema.sql).
Verified 2026-09-11; immutable runtime identity is the digest above, not those moving source branches.
