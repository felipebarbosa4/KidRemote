# KR-005 local pairing execution — 2026-09-11

- **Goal:** prove OD-43's local pairing transaction/protocol scope, not product deployment.
- **Context:** clean baseline `bc6e36508b27b39b8805f10f048be97a990947ff`, branch
  `kr-005-local-pairing` stacked on unmerged `kr-004-local-schema-rls` / draft PR #17.
- **Constraints:** synthetic identities; task-owned disposable DB only; no real
  credentials/media/device operations, remote DB, production exposure or next issue.
- **Done when:** local SQL/race/protocol evidence and required CI are recorded;
  unrun integrations remain explicit and historical KR-003/004 evidence unchanged.

## OBSERVED — executed locally

Native Windows Docker client with explicit
`npipe:////./pipe/dockerDesktopLinuxEngine` returned `linux`, exit 0.
The combined checker executed:

```sh
node tools/kr004/check-local.mjs '/mnt/c/Users/3feli/AppData/Local/Programs/DockerDesktop/resources/bin/docker.exe' 'npipe:////./pipe/dockerDesktopLinuxEngine'
```

Final local target before publication:

- Container `490b90a1b1b71403b522e249cef6d1c8a33e9d68a1c4cf87c89b6f48d9ee2c3c`.
- Name `kr004-ac14-a6bdb712-f48a-4f2b-b8ac-432cc457c41f` (existing runner naming retained).
- Ownership label value `a6bdb712-f48a-4f2b-b8ac-432cc457c41f` verified before start/removal.
- Pinned `supabase/postgres:17.6.1.136@sha256:f371b5f3f2ac0a05703f33d6e6134515fb2498cab708fb948a0aeb7481467c00`.
- PostgreSQL 17.6; database `postgres`, migration owner `supabase_admin`,
  Auth SQL prerequisites present, zero initial application tables.
- Network none; zero published ports; task-owned tmpfs only, no shared volume.
  HTTP test listener was separately bound to host `127.0.0.1` on an allocated port.
- Three versioned migrations passed. Exact-target removal verified, no retained
  synthetic DB. No unrelated container/volume was reset or removed.

| Executed checks | Result |
| --- | --- |
| Node protocol/security + inherited gateway/runner tests | 68 passed, zero failures/skips |
| Original RLS / constraints | 243 + 45 passed, original files hash-preserved |
| KR-004 atomic / concurrency regression | 57 + 44 passed |
| Pairing persistence/authorization/TTL/quota/rollback | 62 passed |
| Pairing concurrent sessions / cancel races / expiry waiting | 36 passed |
| Total real PostgreSQL assertions | 487 passed, zero skips |
| Real loopback pairing HTTP + committed SQL, response loss, new credential gateway authorization | 28 passed |
| Repository validation, worktree/staged/HEAD whitespace checks | passed |

Twenty independent service-role sessions were observed simultaneously waiting on the
same locked challenge. Releasing it produced one REDEEMED and nineteen DENIED, exactly
one device and credential. Both cancellation-first and redemption-first transactions
were held open while the other session waited; outcomes were CANCELLED/DENIED or
REDEEMED/ALREADY_REDEEMED. Expiry while waiting denied the subsequent claim.

The local HTTP test throws after a real successful SQL commit to simulate lost
delivery, then proves replay denial and explicit parent revoke/fresh-QR recovery.
New credential/device records are fetched from PostgreSQL for actual gateway
authorization; sibling/foreign/parent-control attempts are denied. **Gateway operation
storage is stubbed**, not a completed serialized DB-backed device API. Parent Auth
claims are synthetic real-role contexts, not verified HTTP JWT signatures.

Raw secrets were generated only in memory. SQL receives digests. Assertions checked
database rows, actual local DB logs and error bodies without emitting their contents.
The only successful credential response is consumed in memory; there is no plaintext
replay cache, URL token or analytics path. Tests do not prove provider log configuration.

## Development failures retained

Initial 57-assertion pairing suite passed in task container
`d3b63f2ceb9062b03eab88ac403318c26104b9068537ebdcb27a62f99a8301b8`.
The first concurrency attempt in
`88286333a6cec4d4092969342af62a694fc03086f50fc77d24e06efb5504b9f4`
failed before concurrency assertions: SQL fixture used backslash-escaped nested
quotes, which psql did not parse as intended. Safe runner output reported exit 3,
SQLSTATE/line UNSPECIFIED; source inspection identified and corrected that fixture
quoting, using numeric timeout and dollar quoting. This was not a database isolation
PASS. Both containers were verified removed. The subsequent combined run in
`2cd3d0fb6848220a217f43bcde9d82e7b3bc64b35669869c13a868bec02bd19c`
passed 65 Node / 482 SQL / 28 HTTP assertions and cleanup; final validation above
adds the focused SQL payload/quota and security regressions. No failed run is erased.

## INFERRED scope and UNSPECIFIED / unrun boundaries

The observed tests support local AC-1–7/threat-model acceptance, not production use.
Auth signatures, PostgREST, deployed Edge, trusted ingress/source-key derivation,
TLS/provider logging, Android Keystore/backup/QR UX, full device-storage integration,
two-phase rotation and scheduled retention remain unrun or unimplemented integration
work. Production rate quotas remain UNSPECIFIED; fixed-window recommended local
values are not a new owner product decision. Physical enforcement remains KR-003's
open gate. No pooling/reclassification or immutable-bundle changes.

Implementation commit: `57ed9e9ea808f1a9bb03549a532d7f68820f1b09`.
Required [implementation CI](https://github.com/felipebarbosa4/KidRemote/actions/runs/34628882029)
has independently passed its real database and repository jobs. The final head's
complete CI status (including inherited Windows/Android jobs and explicit skips)
is synchronized on [draft PR #18](https://github.com/felipebarbosa4/KidRemote/pull/18)
and [Issue #5](https://github.com/felipebarbosa4/KidRemote/issues/5); pending jobs are
not called PASS. No unchanged manual Android build was repeated. Inherited CI
requirements are unchanged, and PR #17/#16 remain unmerged.
