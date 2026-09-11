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

### First Android attempt — not passed

CI [34647531872](https://github.com/felipebarbosa4/KidRemote/actions/runs/34647531872)
on `fb52936` passed all five jobs, including both app build/lint/release audits and
seven JVM tests (four parent, three child). Debug manifest now has only INTERNET,
CAMERA and the exact same-app signature receiver guard; no network-state permission.

Owned runtime report `results-2026-09-11T21-11-38-956Z.json` is preserved outside the
repository in the existing task directory. It records `TARGETED_ANDROID_OPERATION_REJECTED`,
zero instrumentation stages, cleanup `UNVERIFIED` and overall `NOT_PASSED`.
The exact AVD and qemu flag were verified; a separate scoped installation diagnostic
confirmed `INSTALL_FAILED_UPDATE_INCOMPATIBLE`, exit 1, for the parent APK. No app flow
passed in that attempt. This is a debug signing-key/reinstallation boundary, not an
authentication or enrollment failure. Its parent APK SHA-256 was
`3c285506d58e6070a096f52db9fd32f70b7537faa728cfef30c4703b68dc98b5`.

Fix: fresh synthetic runtime reinstalls only the four explicit task app/test packages
after exact AVD verification. It never uninstalls another app or touches physical
devices. Cleanup skips verified-absent packages (the first attempt never installed
the child). Prior APK files and historical evidence stay unchanged. Subsequent fresh
attempts do not overwrite this failed report. Backend cleanup completed; its owned
database was `0973f53dc34c37a97055932ce50ebfaae14e4a2ba3e4d17c6ab0e14ab57b1bc3`.

### Fresh actual Android run — PASS on this emulator only

[Sanitized complete result](KR-007-ANDROID-RUNTIME-2026-09-11.json), original local
`results-2026-09-11T21-13-59-613Z.json`; the separate
[failed installation result](KR-007-ANDROID-INSTALL-FAILURE-2026-09-11.json) is unchanged.
Host/adapter source `b6087c31d629041b7fc58341be89c6cc2ba9452b`; app/test APK source
`fb52936843690f8c9da2659a119670aaf1454723`, CI 34647531872. Later reporting-only CI
artifacts do not replace these exercised APK identities.

**OBSERVED:** 15 instrumentation invocations passed (14 unique methods, restart/deny
method exercised twice on distinct identities). Four existing parent stages retain
actual signup/unverified denial/local email confirmation, login/household/list,
activity recreation, separate process restart, logout/key/cache clearing, password
recovery and real REST outage/recovery. Then actual parent UI creates/displays/cancels
QR; real child decoder/callback redeems over HTTP, stores independent identity and
reads its unconfigured projection. Child process restart restores/decrypts identity;
target overrides, parent route and replay deny. Actual authenticated parent UI reads
exactly one device, independently confirmed in PostgreSQL at that point.

Further separate synthetic fault cases: corrupt wrapped identity cannot appear paired;
debug exception after actual redemption commit but before local persistence leaves
pending state across restart, no auto-replay. PostgreSQL confirms consumption. Actual
parent UI verifies consumed status, revokes incomplete identity, issues a fresh QR;
PostgreSQL confirms revocation and a different session. Child accepts the fresh QR and
again survives process restart. This is **commit-before-persistence fault injection**,
not a literal dropped network packet. Additional identities in these separate fault
cases are not duplicate successes for the first challenge; no pooled evidence.

Same pre-existing owned Windows AVD, sequential separate app identities, not two
physical devices: Android 16/API 36, AOSP x86_64 image,
`Android/sdk_phone64_x86_64/emu64x:16/BE2A.250530.026.D1/13818094:userdebug/test-keys`,
native Windows emulator 37.1.11 with existing WHPX. Runtime SQL/HTTP regressions again
passed: 496 SQL + 28 old pairing protocol + 44 Auth + 28 new real enrollment assertions.
Owned database `9fdac0d60f5a203439b73236b51664c1aefac5c88fd4cdb5f419d446b5136284`,
owner `c8eb0835-9e37-4830-abd8-46524a87277f`; zero database published ports.

**Cleanup OBSERVED:** app/test data cleared; service log canary scan passed; own gateway,
Auth/REST/mail, DB and network removal verified. Exact AVD stop requested without AVD
deletion; Windows read-only checks found zero listeners at 5584/5585 and
57361/57362/57365/57366. Previous KR-006 APK hashes were rechecked unchanged.
No physical ADB target, capture, installation or enforcement occurred.

**Scope limits / UNSPECIFIED:** generated synthetic QR pixels pass through the actual
ZXing decoder, then the production enrollment callback. This does not prove camera
permission/scanning or physical Keystore/OEM behavior. Expired/cancelled QR and
expired/revoked credential exact HTTP statuses are covered by actual backend tests,
not all by Android UI scenarios. Sibling/foreign records exist in backend denial
fixtures; Android tests additionally reject arbitrary target overrides. Source guards
and service canary scan are not an exhaustive device-log/side-channel audit. Hosted
Edge, final scan UX, camera grant/refusal, backup/transfer/update/data-loss recovery,
credential rotation and remaining permission/removal acceptance remain open. No
configured policy, sync loop, timer, push, protected/online/healthy state is synthesized.

## Exercised APKs and startup

Directory (all four artifacts):
`C:\Users\3feli\AppData\Local\KidRemote\kr006-runtime\e03b4820-193b-4132-b1fc-f7950eeed7fe\apks-kr007`.

| APK | SHA-256 |
| --- | --- |
| app-debug.apk | `3c285506d58e6070a096f52db9fd32f70b7537faa728cfef30c4703b68dc98b5` |
| app-debug-androidTest.apk | `a5d0e4b78d58d23615b36ed8a3723d5644d3019be30bb5003ae172d2adf7d1e3` |
| child-debug.apk | `24563b8d8917b506ccc41bec8fcdbacd986810d420f665a0f0b86cd19734a043` |
| child-debug-androidTest.apk | `7ec4026f5e66185964dbafa74f0359ccc8d393c61ef342f09b5cdbcb4b693053` |

[Exact local startup/runtime commands](../../../apps/child-android/README.md#local-startup-and-bounded-test).
No services or emulator left running. No owner action is required to complete this
demonstrated local slice; this is not physical-installation or real-use permission.

CI [34648325818](https://github.com/felipebarbosa4/KidRemote/actions/runs/34648325818)
on `b6087c3` also passed all five required jobs after the scoped reinstall fix:
repository/evidence/security validation, native Windows PowerShell 5.1/7, database
pre-exposure checks, existing spike isolation and both parent/child JVM/build/lint/
release audits. Eleven focused Node source/security tests and repository validation/
`git diff --check` passed locally. CI does not execute the Windows emulator flow;
the separately retained native runtime above does. No unchanged manual Android build
or KR-003 physical/visual run was repeated for the reporting update.
