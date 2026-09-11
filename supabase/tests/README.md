# KR-004 disposable local database tests

OD-42 authorizes AC-1–4 only. These are real SQL/pgTAP tests in Supabase PostgreSQL,
not a mocked database. No remote endpoint, production credentials, real Auth account,
HTTP signup, gateway, deployment, host port or host privilege change is used.

## Run

Prerequisites: Node.js and an already-running **local Linux Docker engine**.
The image is pinned to Supabase's officially published PostgreSQL 17.6.1.136:
`sha256:f371b5f3f2ac0a05703f33d6e6134515fb2498cab708fb948a0aeb7481467c00`.
It contains PostgreSQL 17.6, Supabase Auth SQL/roles and pgTAP. Pulling the image on first
use downloads software only; it uploads no project data. This is a local test-tool pin,
not a hosting, production support or Supabase project decision.

Linux / CI:

```sh
node --test tools/kr004/*.test.mjs
node tools/kr004/test-local-db.mjs docker unix:///var/run/docker.sock
node tools/validate.mjs
git diff --check
```

Existing WSL environment with native Windows Docker Desktop client:

```sh
node tools/kr004/test-local-db.mjs "/mnt/c/Users/3feli/AppData/Local/Programs/DockerDesktop/resources/bin/docker.exe" "npipe:////./pipe/dockerDesktopLinuxEngine"
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

Migrations execute in filename order. Each SQL suite rolls back its own synthetic fixtures,
temporary privilege changes and pgTAP setup. The runner rejects missing/empty/skipped tests
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
  Their PASS is **not** database evidence; CI separately executes both actual SQL suites.

Claims represent the trusted post-authentication SQL context. No JWT signatures, Auth
HTTP login, PostgREST role switching, device credentials or Edge gateway are validated.
No application RPC exists yet: tests reject an absent control RPC and exercise private
function EXECUTE boundaries with a test-only invoker function rolled back at the end.
These results do not fulfill gateway AC-5, transaction AC-6 or the full before-exposure AC-7.

[Supabase database tests](https://supabase.com/docs/guides/database/testing),
[official image selection](https://github.com/supabase/supabase/blob/master/docker/docker-compose.yml),
[Supabase Auth SQL](https://github.com/supabase/postgres/blob/develop/migrations/db/init-scripts/00000000000001-auth-schema.sql).
Verified 2026-09-11; immutable runtime identity is the digest above, not those moving source branches.
