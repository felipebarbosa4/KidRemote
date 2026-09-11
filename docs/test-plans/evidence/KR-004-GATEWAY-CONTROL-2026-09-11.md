# KR-004 local AC-5–7 completion evidence — 2026-09-11

- **Goal:** complete OD-42's prospective local gateway/control/validation extension.
- **Context:** clean baseline `80c68faa3df07b9977ed423845037bd1e886a52e`;
  existing `kr-004-local-schema-rls` / draft PR #17 remains stacked on KR-003.
  The original [AC-1–4 evidence](KR-004-LOCAL-DB-2026-09-11.md) is unchanged.
- **Constraints:** synthetic local data/resources only; no deployment, real family use,
  QR/login, push delivery, device/capture operation, KR-005/006 or production enforcement.
- **Done when:** actual handler HTTP tests and SQL transaction/concurrency tests pass,
  original regressions remain intact, cleanup and local checks verify, required CI is
  recorded separately from unrun full-stack behavior.

## OBSERVED: executed local result

The native Windows Docker client independently returned `linux` from the explicit local
Docker Desktop named pipe. The complete executed command was:

```sh
node tools/kr004/check-local.mjs "/mnt/c/Users/3feli/AppData/Local/Programs/DockerDesktop/resources/bin/docker.exe" "npipe:////./pipe/dockerDesktopLinuxEngine"
```

It exited **0**, ending `KR004_LOCAL_CHECKS_PASSED:DEPLOYMENT_AUTHORIZED=false`.

| Check | Executed result |
| --- | --- |
| Node / HTTP / guard tests | **60 PASS**, zero fail/skip: 42 HTTP scenarios + one parent test, 10 runner guard tests, four acceptance-counter tests, three inventory/baseline tests |
| Original RLS suite 01 | **243 PASS**, unchanged file |
| Original constraints suite 02 | **45 PASS**, unchanged file |
| Atomic control suite 03 | **57 PASS** |
| Actual concurrent-session suite 04 | **44 PASS** |
| Total SQL | **389 PASS**, zero fail/skip |
| Migrations 001 and 002 | Both applied successfully to empty application schema |
| Repository validation / worktree, staged and HEAD whitespace checks | PASS |
| Cleanup | Exact task container ownership reverified, removed, successful filtered listing proved absence |

### Verified disposable identity

- Container `875fa8f131a49844a5564aefef96c62a3a7eee822e0b12f2fe825cc724c2b475`.
- Name `kr004-ac14-ca202c93-fa03-423f-8c66-71fb03cbbc54`; ownership label
  `org.kidremote.kr004.disposable=ca202c93-fa03-423f-8c66-71fb03cbbc54`.
  The existing runner name prefix is retained; it does not limit which suites execute.
- Local database `postgres` in that new exclusive instance; migration owner
  `supabase_admin`; zero initial public/private application tables and real Auth SQL
  prerequisite verified before migrations.
- Image `supabase/postgres:17.6.1.136@sha256:f371b5f3f2ac0a05703f33d6e6134515fb2498cab708fb948a0aeb7481467c00`;
  executed PostgreSQL **17.6**.
- Network `none`, zero published DB ports, task-owned tmpfs, no shared/bind volumes.
  HTTP testing used only a short-lived `127.0.0.1` listener.
- Only task-owned synthetic DB contents were removed. Earlier intermediate task
  containers `9681ed301821`, `f889cd1f9935`, `d8795eb5e31b` and `dbaa928775ba`
  also passed their then-present suites and verified removal; they are not substituted
  for the final all-suite run above. No new SQL/HTTP test failure occurred during this
  extension. The historical development failures in the AC-1–4 evidence remain recorded.

## What each evidence layer proves

**AC-5 HTTP:** the actual handler hashes/verifies an in-memory synthetic opaque bearer,
separately authorizes records and derives device/household scope server-side. Own sync,
ack and push contract dispatch succeeds; missing/invalid/expired/revoked/malformed-record
credentials, siblings, foreign tenants, forged scope, wrong epoch/future receipt,
address theft, parent JWT/control routes, arbitrary RPC/operations, oversized/unknown
payloads and post-success revocation deny. Responses/errors do not disclose credentials.
Storage/transaction callbacks are explicitly **dependency stubs** and return `STUB_*`.
They do not decide authorization. This is the issue's permitted handler HTTP/stub proof,
not a database-backed device gateway integration claim.

**AC-6 SQL:** one authenticated-only security-definer entrypoint rechecks `auth.uid()`,
active owner membership, device revocation and household state under locks. Typed
control input and current version/period/cap checks precede atomic business writes.
An identical operation reuses the original version/result; conflicting reuse denies.
Failures injected after policy/command/grant/audit/outbox writes and an explicit caller
rollback preserve the complete before-state. No push call or usage reset occurs.

**Concurrency:** two actual dblink sessions in the same exclusive database use the
authenticated role/claims. Tests observe a worker waiting on a lock, then verify the
committed result for duplicate/distinct additions, daily-cap races, stale Lock/Unlock,
global operation-ID reuse across devices and membership deletion/device revocation
while authorization waits. This is not a sequential mock or a simulated database lock.

**AC-7:** the one-command checker fails fast; the DB runner requires the complete
migration/suite inventory, checks exact local target identity before migration/removal,
and preserves primary failure independently of cleanup. Reset means a **new** owned DB,
not dropping shared schemas. Baseline hashes prevent accidental changes to AC-1–4.
Required CI uses the same command; existing unrelated CI checks remain enabled.

## Input integrity (SHA-256)

| Input | SHA-256 |
| --- | --- |
| Migration 002 | `81ac482f55dce734ff24068bd824bf905e2dea892df8aff3a7ceb2384ab167b2` |
| Gateway handler | `75ea5b006c73ee686864c2a529b2610db28cd1bfd4e246a45638d1b5671ceae0` |
| SQL suite 03 | `f75804f7e56541acc4006ceb523272692762683ccde8319a8792f54ec17ac0aa` |
| SQL suite 04 | `86d6c9a606630de122f6e88505a8ec36a0dcd3e4cf800620ea18e7885461734d` |
| Complete checker | `f0a52a4990d7a7ff40b1fed45507d9b5f6a4ea6871ec9eeb84c2c70833048338` |
| Disposable DB runner | `167b1f453e25fc87d93a046b1f4622d6e133c8775cd262ba151f2224af728737` |

## UNSPECIFIED / unrun / not authorized

No database-backed gateway storage adapter, Auth HTTP/JWT signature verification,
confirmed-parent login integration, PostgREST or Deno/Edge runtime was executed.
No FCM request, full sync engine, pairing, credential rotation, retention/deletion worker,
real device, deployment or real-family scenario was run. These are not silently labelled
PASS by local KR-004 completion. Node execution does not prove hosted Edge compatibility.

No unchanged manual Android build was repeated. Exact required remote CI results and
any inherited visual test skips are recorded in the Issue #4 / PR #17 publication
comment for the final commit. No skip in SQL/HTTP acceptance is accepted as PASS.
No attempt to repair or expand paused visual tooling is authorized by this task.

**INFERRED next step:** KR-004's bounded local ACs are ready for review, not automatic merge
or issue closure. The existing next product issue can be proposed separately (KR-005's
pairing threat model/local redemption tests); do not start it without direction.
KR-003 and all original physical verdicts/support/use/distribution gates remain unchanged.
