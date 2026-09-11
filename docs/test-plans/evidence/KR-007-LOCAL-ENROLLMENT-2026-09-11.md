# KR-007 local enrollment — 2026-09-11

OD-45 scope only; PR #20 stacked on unmerged PR #19 at `a4d6beb`.
No physical device, enforcement, distribution or real account evidence.

## Executed backend evidence

Command from repository root:

```sh
node tools/kr004/test-local-db.mjs '/mnt/c/Users/3feli/AppData/Local/Programs/DockerDesktop/resources/bin/docker.exe' 'npipe:////./pipe/dockerDesktopLinuxEngine' --enrollment-test
```

Two separate successful disposable runs, not pooled samples:

- Initial implementation `b87f8d9`: owned database `64f0fbe5ab1ac35aae00a2e2570e95af7364559def52b97f35ac38d97288d2c7`, owner `964b31cb-54fe-4b84-b6df-dac7767921a1`.
- Regression `817a10f`: owned database `ed693e4b5f9d5f642b1a3a2fd11f3cd12f030dbcc412e6b1a6a0ab67d522a838`, owner `a5221a1d-c462-4168-9da8-ae8d14322413`; sibling/foreign targets are persisted synthetic devices.

Each: PostgreSQL 17.6, zero published database ports, isolated tmpfs, four migrations,
496 actual SQL assertions including real concurrent pairing/control sessions,
28 existing pairing protocol/HTTP assertions, 44 actual Auth/PostgREST/mail assertions,
28 new actual enrollment HTTP/database assertions. Secret-canary scan, owned gateway,
Auth/mail/REST, database and network cleanup passed. No unrelated resource mutation.

New enrollment tests use an authenticated SQL-role fixture for parent creation and
real HTTP redemption plus real database-backed credential authorization/initial read.
They test own unconfigured state, sibling/foreign overrides, parent/unsupported routes,
missing/invalid/expired/revoked credential, expired/cancelled/replayed/foreign-backend QR,
discarded committed response, revoke/fresh-QR recovery, digest-only persistence and
denial of direct parent PostgREST access with the device credential.

The **old** 28-test pairing suite still labels its gateway operation storage STUB.
That does not describe the **new** initial-read adapter, which uses one real locked
PostgreSQL transaction. No Edge deployment/full provider integration is claimed.

## Retained failures and Android boundary

CI [34646453818](https://github.com/felipebarbosa4/KidRemote/actions/runs/34646453818)
on `b87f8d9`: compilation, JVM and lint tasks completed; the child merged-manifest
least-privilege audit failed with `CHILD_PERMISSION_BACKUP_SCOPE`. APK upload steps
were skipped. This is not an Android runtime PASS or an accepted permission exception.
Follow-up audit emits only safe merged permission/backup metadata to identify the
boundary; the allowlist remains enforced.

CI [34646977122](https://github.com/felipebarbosa4/KidRemote/actions/runs/34646977122)
on `817a10f` reproduced the audit failure and established the extra merged declaration:
`ACCESS_NETWORK_STATE`; backup exclusions were present. The child source does not
request/use network-state monitoring. Remove that transitive declaration explicitly
at manifest merge, retaining the original INTERNET/CAMERA/same-app signature allowlist.
Both failed CI runs remain failures, not silently replaced by subsequent builds.

Android enrollment runtime is not established by these backend or build results.
Subsequent actual app attempts/results are recorded below when executed. Synthetic QR
decoder input is never camera capture/permission evidence. Physical Keystore/OEM,
camera grant/refusal/scanning, transfer/restore, rotation and broader removal/permission
acceptance remain unrun/outside this first slice. No child policy/enforcement is active.
