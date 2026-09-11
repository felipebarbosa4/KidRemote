# KR-006 local parent foundation — 2026-09-11

- **Goal:** parent debug application plus actual synthetic Auth/household flow under OD-44.
- **Context:** verified clean `6de53806d68ac151c57d2667e09c351272ea0b83`; branch
  `kr-006-local-parent-auth`, [draft PR #19](https://github.com/felipebarbosa4/KidRemote/pull/19)
  stacked on unmerged KR-005 PR #18. OD-43 is not this authorization.
- **Constraints:** task-owned local services/data only; no physical device/capture,
  cloud/deployment, real recipients, distribution, child enforcement or KR-007.
- **Done when:** executable slice/build evidence or exact blockers recorded, with
  UI/unit, HTTP/Auth/SQL and emulator/physical evidence separated.

## OBSERVED — local execution

The existing native Windows Docker client returned `linux` at the explicit
`npipe:////./pipe/dockerDesktopLinuxEngine` endpoint. Native Windows Node is v24.14.0;
WSL Node is v22.23.1. Neither WSL integration nor host privileges/settings were changed.
Requests to Windows loopback use native Node, passing credentials only through stdin.

Executed:

```sh
node tools/kr004/test-local-db.mjs '/mnt/c/Users/3feli/AppData/Local/Programs/DockerDesktop/resources/bin/docker.exe' 'npipe:////./pipe/dockerDesktopLinuxEngine' --parent-test
node tools/kr004/check-local.mjs '/mnt/c/Users/3feli/AppData/Local/Programs/DockerDesktop/resources/bin/docker.exe' 'npipe:////./pipe/dockerDesktopLinuxEngine'
node --test tools/kr006/security.test.mjs
node tools/validate.mjs
git diff --check
```

Four migrations passed. Original 487 SQL assertions and 28 KR-005 SQL/HTTP assertions
passed unchanged; gateway business storage stays stubbed. The combined checker passed
68 Node entries and exact DB cleanup. Three parent source/security tests passed.

Actual Auth/PostgREST local sequence first passed 41 assertions in DB container
`63cb3ed0ab89dfef4b5341b16ae1d7804dbff7a96d7257cede3caf93bfc50b17`, owner label
`d1be5929-d554-4db6-a723-90ef1a0cec3b`. A later provider-failure/log-scan extension passed
43 assertions in `966bbb13d95522f96717ffca507a297245aca65de6bffa48454389b7f4a38d36`,
owner label `958a2b09-ff9b-4cf5-9a00-862db6eddd09`. Current tests additionally target
outage/restart of the task's own REST service; final CI results are tracked in PR #19.
All corresponding Auth/REST/mail/DB/network resources were verified removed.

The executed cases use actual signup/confirmation email delivery/verification/password
login, not auto-confirm, admin-created verified users or forged JWTs. They cover:
unverified/invalid login, confirmation replay, ten concurrent HTTP bootstrap requests
with one created household/membership, own profile/household and empty devices,
foreign/removed membership denial with still-unexpired signed tokens, metadata/actor
override rejection, real recovery/password update, stale and expired recovery,
refresh/local logout and residual signed-token lifetime. Expiry failure injection
changes only synthetic recovery issuance time, never fakes successful authentication.
SMTP failure stops only the task-owned mailbox; source scan and runtime credential
canaries check logs without emitting raw contents. No local mail/data is uploaded.

DB identity is checked before migrations and removal; task network/containers have
unique names/ownership labels and pinned images. DB has no published port; Auth 57361,
REST 57362, mailbox 57365 bind only 127.0.0.1. User-defined bridge has masquerading
disabled. Auth uses actual database persistence, SMTP capture uses task-only tmpfs,
and cleanup removes only verified IDs. No global prune or unrelated resource mutation.

## Failures preserved / corrected

- Internal-network attempts in DB containers
  `5b3a72480c6d6f584f7a3e9fc4e1bd7eab65ed0890aa8f2d9828d7a73a0f8c12` and
  `346b387e3f3f789cd40c72967915823bf06cdcb48a817b2c35d54ac71d452ae2`
  failed readiness. Structured diagnostics found three running services, no matched
  password/connection/migration error, but native loopback Auth/REST status 0.
  Cleanup verified. Changing only task network configuration to the loopback-published,
  non-masquerading bridge allowed the subsequent real flow. This supports a local
  transport/configuration boundary, not a general Docker failure claim.
- Local Gradle configuration resolved, but Android tasks stopped with `SDK location
  not found`. No SDK licence was accepted, host SDK installed or emulator/ADB invoked.
- [Initial CI](https://github.com/felipebarbosa4/KidRemote/actions/runs/34632157386)
  passed real Auth tests but rejected compile SDK 36 in `checkDebugAarMetadata`:
  Compose BOM 2026.09.00 requires API 37. Parent compile SDK/Build Tools were corrected
  to 37/37.0.0; target remains 36, minimum 28. KR-003's independent pins are unchanged.
- [Second CI](https://github.com/felipebarbosa4/KidRemote/actions/runs/34632476093)
  executed 44 real Auth assertions, log-canary scan and all cleanup successfully.
  Parent debug/release builds, both lint tasks and four JVM tests passed. The new
  parent manifest audit then rejected AndroidX Core's generated same-app receiver
  permission. Its [official manifest](https://github.com/androidx/androidx/blob/androidx-main/core/core/src/main/AndroidManifest.xml)
  declares this guard with signature protection. The audit now requires the exact
  provisional application-scoped name and signature declaration; negative fixtures
  reject normal/foreign/broad permissions. No child permission or existing KR-003
  release validator was relaxed. The failed audit is retained, not reported as full PASS.

## IMPLEMENTED versus unrun

[CI 34633168769](https://github.com/felipebarbosa4/KidRemote/actions/runs/34633168769)
on `2de80751879cb5be56cae7521aed96a9f34e7529` passed all five jobs: repository,
Windows PowerShell 5.1/7, existing spike, DB regression and parent. Parent evidence:
44 actual Auth/HTTP assertions, four JVM tests, four Node security tests, debug/release
build and lint, merged-manifest/DEX isolation audit. The debug-only artifact was
downloaded and independently hashed:
`9fa72d9c1de1551891ab0dd4ecddc53dd808b57c99edff4a70af52e4ddb6cd55`.
CI read-only prerequisite checks returned `EMULATOR_BINARY=ABSENT`,
`EMULATOR_SYSTEM_IMAGE=ABSENT`, `KVM_ACCESS=UNAVAILABLE`. Emulator execution is UNRUN,
not skipped evidence counted as PASS. Existing visual-codec CI skips are unrelated;
no visual work or new manual Android build was performed.

An additional direct SQL security test initially failed with SQLSTATE 42703 because
the base image's minimal pre-GoTrue Auth fixture lacks confirmation/deletion columns.
The failed task DB `4356bf7563fef2933d8104b665ee8723bfbd9aeed227a2c2e97da18c126d37e3`
and task network were verified removed. Test-only columns now exist only inside its
rolled-back fixture transaction; real Auth tests still use the provider's migrations
and email verification. Nine assertions additionally cover missing/unconfirmed subject,
trusted catalog lookup despite a temporary shadow relation, own idempotent setup,
and denied anon/service execution. The function explicitly qualifies
`pg_catalog.pg_timezone_names`; no caller-controlled reference supplies timezone authority.
The corrected local run passed all 496 SQL assertions, 28 KR-005 SQL/HTTP assertions
and 44 real Auth/HTTP assertions in verified task DB
`721f3650ebabd88340a4974269249b95f238270b6733aa92106746771d613597`, owner label
`ac580fe4-e136-45d9-8eca-556e87ca18c8`. Secret-canary scan and removal of all owned
Auth/REST/mail/DB/network resources passed. Four Node security tests, repository
validation and whitespace check passed. Final-head CI is linked in PR #19 without
representing earlier CI as execution of a later commit.

Native screens: signup, verification pending, login, local-email recovery/password reset,
loading/error/retry, confirmed timezone setup, actual empty device-list projection and
logout. The local email action form rejects foreign URLs, fragments and ambiguous/type
overrides; it is not a deployed verified-link callback. No fake controls or deletion UI.

Refresh credentials are Keystore AES-GCM-wrapped in an AtomicFile in noBackupFilesDir;
access/password/link state is memory-only. Recovery sessions are not persisted as normal
sessions. Logout invalidates in-flight result publication, clears file/key/presentation,
and requests local-scope Auth logout. Provider failure and JWT expiry limitations are
explicit. Production release has no configured backend/emulator callback/cleartext path.

JVM reducer/callback tests and APK/lint/release audits are required in the parent CI job;
exact executed status and APK hashes are synchronized in PR #19. Compilation/source tests
are not emulator or physical evidence. Local SDK/emulator are unavailable; physical
storage/process recreation/backup, verified-link UX, TalkBack and large-font checks
remain unrun. CI records emulator prerequisites without changing host privileges.

[Account deletion](../../SECURITY.md#kr-006-account-deletion-design-od-44-not-an-implemented-endpoint)
is a design only: reauthentication, scoped revoke-before-delete, pending/retry behavior,
in-app/web request paths and offline-child consequences. No deletion endpoint or public
website was deployed. Auth provider configuration, real SMTP, production identifiers,
region, distribution and child enforcement remain separate gates.
