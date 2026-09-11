# KR-006 local parent foundation — 2026-09-11

- **Goal:** parent debug application plus actual synthetic Auth/household flow under OD-44.
- **Context:** verified clean `6de53806d68ac151c57d2667e09c351272ea0b83`; branch
  `kr-006-local-parent-auth`, [draft PR #19](https://github.com/felipebarbosa4/KidRemote/pull/19)
  stacked on unmerged KR-005 PR #18. OD-43 is not this authorization.
- **Constraints:** task-owned local services/data only; no physical device/capture,
  cloud/deployment, real recipients, distribution, child enforcement or KR-007.
- **Done when:** executable slice/build evidence or exact blockers recorded, with
  UI/unit, HTTP/Auth/SQL and emulator/physical evidence separated.

## Native Windows runtime follow-up — blocked before Android execution

Historical prerequisite result. The owner subsequently installed the SDK; the successful
runtime continuation below supersedes this *blocker*, not the recorded unrun attempt.

Verified clean HEAD `4b0a218ed6b38fcb31c76c47b16af71841b2c4b7`, branch
`kr-006-local-parent-auth`, open draft PR #19 base `kr-005-local-pairing`. OD-44's
prospective one-AVD/download authorization is recorded without changing earlier evidence.

**OBSERVED**, through existing native `powershell.exe -NoProfile -NonInteractive`:

- `ANDROID_HOME`, `ANDROID_SDK_ROOT`, `ANDROID_AVD_HOME`: UNSET.
- `Get-Command emulator.exe`, `sdkmanager.bat`, `avdmanager.bat`: NOT_ON_PATH.
- `Test-Path` false: `C:\Users\3feli\AppData\Local\Android\Sdk`,
  `C:\Android\Sdk`, `C:\Android`, `C:\Program Files\Android`,
  `C:\Users\3feli\.android\avd`. Additional targeted developer-tool directory checks
  found no Android/SDK/emulator/Studio/toolchain/AVD directory candidate.
- SDK registry entries absent: `HKLM:\SOFTWARE\Android Studio`,
  `HKLM:\SOFTWARE\WOW6432Node\Android SDK Tools`, `HKCU:\SOFTWARE\Android SDK Tools`.
- Native `Get-CimInstance Win32_ComputerSystem`: `HypervisorPresent=true`;
  `Win32_Processor`: `VirtualizationFirmwareEnabled=true`,
  `SecondLevelAddressTranslationExtensions=false`;
  `Test-Path` Windows System32 `WinHvPlatform.dll`: true.
- `Get-PSDrive C`: 287869734912 bytes free at the retained check (~268 GiB).
- Existing debug APK independently rehashed unchanged:
  `31abee2f6d1fecedbc4989f8d61f9003c6ee5b54d9b43aca8f85d77bc641bed4`.

**INFERRED:** Windows has virtualization-related facilities, but their presence does
not establish emulator acceleration. The processor report is not used to diagnose
an incompatible CPU or prescribe host changes.

**UNSPECIFIED:** SDK installations outside the bounded paths/registry/PATH inspected,
previous personal licence acceptance outside those installations, emulator version,
system image, usable acceleration, emulator-to-loopback connectivity and every requested
Android UI/session outcome. No exhaustive personal-file scan was performed.

**Exact boundary:** no SDK/emulator executable or accepted licence installation was
established. Official [SDK package documentation](https://developer.android.com/tools/sdkmanager#accept-licenses)
requires package licences; the owner prohibits agent acceptance. The official
[acceleration check](https://developer.android.com/studio/run/emulator-acceleration#accel-check)
requires the emulator binary. No download, licence acceptance, AVD creation, ADB command,
backend start, authentication attempt, device operation or cleanup was performed.
There are no failed Android test attempts to reinterpret: all runtime tests are UNRUN.
Existing backend/JVM/build PASS results remain distinct, AC-2/5 remain partial.

One owner action: initialize the official Windows Android SDK at the conventional
user-owned path above and personally review/accept prompted licences. No host feature
changes or owner-created AVD are requested. After that, repeat the native prerequisite
check and continue the authorized task; do not assume future package licences accepted.
Only documentation changed here; repository validation/whitespace are run locally and
required CI remains enabled. Prior APK and startup instructions remain unchanged in
[parent README](../../../apps/parent-mobile/README.md).

## Native Windows emulator runtime — actual PASS, exact configuration only

**OBSERVED:** [sanitized machine-readable result](KR-006-ANDROID-RUNTIME-2026-09-11.json).
Source `f017474366d68e8b5ac15e28efe8abff3fc5ee91`; APKs from successful
[CI 34640496055](https://github.com/felipebarbosa4/KidRemote/actions/runs/34640496055).
Native `emulator.exe -accel-check` returned exit 0 and WHPX 10.0.26200 usable.
Emulator 37.1.11, Platform Tools 37.0.1, AOSP API 36 x86_64 image revision 2.
The explicitly selected, manifest-owned AVD was
`kr006_e03b4820193b4132b1fcf7950eeed7fe`, `emulator-5584`; name and
`ro.kernel.qemu=1` were checked before targeted application operations.
No physical target or global ADB reset was used. Linux/CI KVM was not the prerequisite.

The existing `--parent-runtime` DB-runner mode allocated verified DB
`4a45ed38fccb140cd7ec45608d7d172390bbac2b0d38fca523be01dc884b2bae`, owner
`ce2ac59e-82f4-40c4-8fce-90339be7edbc`, synthetic data only, no DB port.
All four migrations, 496 SQL assertions, 28 existing pairing SQL/HTTP assertions and
44 actual Auth/PostgREST checks passed before app execution. Gateway storage remains
stubbed in its separate regression suite, not in this parent Auth/PostgREST boundary.

Four actual `AndroidJUnitRunner`/Compose methods passed with 13 retained checkpoint codes:

| Runtime method | Actual boundary and result |
| --- | --- |
| `enrollAndPersist` | Emulator reached Windows loopback Auth/REST/mail; real UI signup, verification pending, unverified login denied, actual SMTP email action entered through UI, confirmed login/setup, actual empty list; Activity recreation retained list in the **same PID**. PASS |
| `restoreAndLogout` | Host force-stopped only the task app; test required a **different PID**. Real vault decrypt/refresh restored session; setup re-read the household. UI logout removed session file and actual AndroidKeyStore alias and cleared the email field. PASS |
| `restartLoggedOutAndRecover` | Another different PID remained unauthenticated; recovery email was obtained locally and entered through UI; reset accepted, old password denied, new password login/list passed. Recovery refresh was not persisted. PASS |
| `networkFailureAndRecovery` | Host stopped only its verified PostgREST container; actual setup request failed with recoverable UI. A coarse nonsecret marker requested service restoration; same app process retried successfully, then logged out and cleared the vault. PASS |

The final actual SQL count was exactly one runtime household membership despite repeated
setup. UI tests never call model actions directly, set fake content/state, forge tokens,
auto-confirm accounts or replace AuthApi. Test-generated credentials stay in a temporary
target-UID no-backup fixture between process tests, separate from production session
storage; this test-only fixture is explicitly deleted, then both synthetic package data
directories are cleared. No credential/email link is in adb arguments, logs or artifacts.
Only stable checkpoint codes/results/metadata/hashes are retained. The service log-canary
scan covers host regression credentials; it is **not** a claim of exhaustive Android/IME
or provider-log proof for every runtime secret.

Cleanup: actual app/test data clear returned Success; Auth/mail/REST/DB/network removal
was ownership-verified. Emulator received only a name-verified targeted `emu kill`;
ports 5584/5585 subsequently closed. AVD files remain outside the repository for reuse;
no unrelated AVD/resources removed. The sanitized original local record is
`C:\Users\3feli\AppData\Local\KidRemote\kr006-runtime\e03b4820-193b-4132-b1fc-f7950eeed7fe\results-2026-09-11T19-52-24-006Z.json`.

**Preserved tooling failures/corrections:** SDK command-line tools 23.0 redirected the
initial `sdkmanager` listing to official Android CLI; subsequent calls used `--no-metrics`.
A guessed `android.bat` path was rejected; the installed binary is `android.exe`.
Package download/extraction ended with abnormal Windows exit `-1073740791` (observed for
Build Tools), so extraction alone was not treated as success. The image's package metadata,
AVD creation, boot and actual runtime independently passed afterward. The official image
licence text matched the installed accepted `android-sdk-license` modulo whitespace
(installed accepted hash `24333f8a63b6825ea9c5514f83c2829b004d1fee`); no new terms were
accepted. The initial CI 34640377591 was cancelled by PR concurrency after a test-fixture
UID correction; it is not reported as PASS. Windows console carriage returns were
normalized at the scoped AVD identity boundary. No app behavior defect was found in
the executed flows and no production app semantics were changed.

**Limits:** this closes APK-to-local-services evidence for this emulator only. Keystore
execution is not physical/OEM security proof. Headless Compose instrumentation is not
human-visible physical evidence. Deployed verified-link handling, physical storage/
backup/OEM behavior, TalkBack/large-font checks and production Auth/SMTP remain UNRUN.
AC-2/5 gain actual runtime evidence but remain partial against the full physical test
plan. Logout verifies local erasure here, not immediate global access-JWT invalidation.
No account-deletion implementation, real users, distribution, KR-007 or child enforcement.
Official references: [Compose instrumentation](https://developer.android.com/develop/ui/compose/testing#setup),
[emulator command line](https://developer.android.com/studio/run/emulator-commandline).

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
