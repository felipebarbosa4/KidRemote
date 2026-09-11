# Parent Android app

OD-44 local-development slice on unmerged KR-005. Provisional identifier:
`dev.kidremote.parent.unassigned.debug`; not a release identity or distribution approval.

- Goal: executable KR-006 signup/verification/login/recovery/logout and own household/empty list.
- Context: [Design](../../docs/adr/0001-parent-framework.md).
- Constraints: synthetic local accounts only; no physical install, cloud, real use or child enforcement.
- Done when: real Auth/persistence and APK tests execute; physical/emulator gaps stay explicit.

## Local services

Run from repository root on Linux with Docker already running:

```sh
node tools/kr004/test-local-db.mjs docker unix:///var/run/docker.sock --parent-dev
```

Existing WSL/native Windows engine:

```sh
node tools/kr004/test-local-db.mjs '/mnt/c/Users/3feli/AppData/Local/Programs/DockerDesktop/resources/bin/docker.exe' 'npipe:////./pipe/dockerDesktopLinuxEngine' --parent-dev
```

The existing runner allocates/validates its own disposable DB plus Auth/PostgREST/Mailpit
containers and a task bridge. Ports are loopback-only: Auth 57361, REST 57362, mailbox
57365. No DB port, external SMTP or shared volume. Masquerading is disabled; no global
Docker/host setting changes. A occupied port fails rather than replacing another service.
Ctrl+C performs exact-owned-resource cleanup; all synthetic account/mail state is disposable.
After an external process kill, identify resources by the emitted run ID/ownership label;
do not prune Docker or delete unverified resources. Never print container environment dumps.

Use `--parent-test` instead for executed HTTP fixtures and automatic cleanup. The native
Windows Node client contacts Windows loopback using secret-bearing stdin, never argv/logs.
The current debug APK expects an Android emulator's `10.0.2.2`, not a physical tablet.
The OD-44 runtime continuation provisioned one dedicated Windows AVD; instructions below
reuse only that owned target. Physical installation remains unauthorized.

## Verified Windows emulator integration

Source `f017474` passed four actual Compose instrumentation methods (13 checkpoints)
against real local Auth/PostgREST/mail, including Activity versus process restoration,
Keystore file/key logout clearing and actual REST outage/retry. See
[runtime evidence](../../docs/test-plans/evidence/KR-006-LOCAL-PARENT-2026-09-11.md#native-windows-emulator-runtime--actual-pass-exact-configuration-only).
This is AOSP API 36 x86_64 revision 2 / Emulator 37.1.11 / WHPX evidence only.
It does not establish physical Samsung behavior, verified production links or accessibility.

The existing owned AVD and APKs are retained, stopped and cleared, under
`C:\Users\3feli\AppData\Local\KidRemote\kr006-runtime\e03b4820-193b-4132-b1fc-f7950eeed7fe`.
To repeat this **synthetic emulator-only** integration, start that AVD in Windows PowerShell:

```powershell
& '\\wsl.localhost\Ubuntu-24.04\home\felby\projects\KidRemote\tools\kr006\windows-emulator.ps1' -Mode Start -TaskDirectory 'C:\Users\3feli\AppData\Local\KidRemote\kr006-runtime\e03b4820-193b-4132-b1fc-f7950eeed7fe'
```

Wait for the dedicated AVD to boot, then from this repository in WSL:

```sh
KR006_RUNTIME_DIRECTORY=/mnt/c/Users/3feli/AppData/Local/KidRemote/kr006-runtime/e03b4820-193b-4132-b1fc-f7950eeed7fe node tools/kr004/test-local-db.mjs '/mnt/c/Users/3feli/AppData/Local/Programs/DockerDesktop/resources/bin/docker.exe' 'npipe:////./pipe/dockerDesktopLinuxEngine' --parent-runtime
```

The runner allocates its own backend, runs existing regressions and actual instrumented
UI flows, then removes verified services and clears only the two synthetic packages.
Credentials are generated inside instrumentation, never supplied in arguments. JSON
results are separate timestamped files in the task directory; no screenshots or logcat
are captured/uploaded. Test APK contains test code only, not account fixtures/secrets.
CI builds both APKs but **does not** execute this Windows runtime step automatically.

Stop or bail out of the **verified task emulator only**, in Windows PowerShell:

```powershell
& '\\wsl.localhost\Ubuntu-24.04\home\felby\projects\KidRemote\tools\kr006\windows-emulator.ps1' -Mode Stop -TaskDirectory 'C:\Users\3feli\AppData\Local\KidRemote\kr006-runtime\e03b4820-193b-4132-b1fc-f7950eeed7fe'
```

This retains the AVD and reports uncertainty rather than operating another target.
If stopped during instrumentation, the bounded host test detects failure and finalizes
backend cleanup; app-data cleanup may be UNVERIFIED until the same owned AVD can be
accessed again. Do not force-kill the DB runner or prune Docker globally. For manual
local backend startup, use `--parent-dev` above; Ctrl+C performs scoped backend cleanup.

## Implemented screens and limits

Signup sends a real confirmation message to the local mailbox at `http://127.0.0.1:57365`.
Only synthetic `@example.test` accounts are appropriate. Copy the confirmation link into
the app's verification form; it validates exact origin/path/type/parameters then exchanges
the token in a POST body. Sign in after confirmation. Confirm the visible IANA household
zone to bootstrap once, then read actual own profile/household/device rows via PostgREST.
No fake devices, remaining-time values or remote-control buttons are provided.
OD-45 adds only real create/display/cancel pairing QR and a read-only enrolled list.
The QR is memory-only and clears on background/expiry; a nonsecret session ID supports
explicit revoke/fresh-QR recovery after a consumed response was not saved. Parent JWTs
never enter the QR. Devices are labelled setup incomplete/protection unverified, not
healthy or protected merely because registered. Use the child slice's
[enrollment startup and test commands](../child-android/README.md#local-startup-and-bounded-test)
for the additional local gateway. Earlier KR-006 APK evidence above stays unchanged.

Recovery sends a local email; paste its link into the recovery form, verify with Auth,
set a new password and sign in again. No exported implicit-token/custom-scheme callback
is accepted. Production verified-link UX remains an integration/physical acceptance gap;
manual local email-action input is a bounded lab flow, not a final public callback design.

Only the refresh token is persisted: platform AES-GCM key in AndroidKeyStore and
encrypted AtomicFile under noBackupFilesDir. Access tokens/forms remain in memory;
passwords/links are not saved into instance state. Refresh revalidates against Auth;
network failures show retry, never manufacture a session. The dedicated emulator now
exercised actual vault encryption/decryption, process restoration and logout erasure.
Physical/OEM transfer, backup, TalkBack and large-font behavior remain unverified.
Source/unit or emulator checks do not prove physical-device behavior.

Logout clears memory, encrypted file/key and UI cache, and requests Auth `scope=local`.
Offline/server failure is reported as unverified server revocation. Already issued JWTs
can remain accepted by PostgREST until expiry; membership removal is independently checked
by RLS on every request. This local test uses five-minute access JWTs, not a production
lifetime decision. Child downloaded policy is neither accessed nor changed.

Release has no backend configured, no emulator endpoints, no callback origin and no
cleartext exception. Debug alone allows the exact emulator host. Parent requests only
INTERNET plus AndroidX's own signature-scoped receiver compatibility permission,
never child/Accessibility/device-admin/camera permissions. No backend key in APK.

## Build/test

Requires an already licensed compile SDK API 37 / Build Tools 37.0.0 and JDK 17.
Target API remains 36 and minimum API 28; this bootstrap is not a device-support claim.
The first CI build correctly rejected compile SDK 36 because the current stable Compose
BOM requires 37. Only the parent compile SDK changed; KR-003 is untouched. See
[Android SDK setup](https://developer.android.com/about/versions/17/setup-sdk).

```sh
spikes/android-enforcement/gradlew -p apps/parent-mobile --no-daemon testDebugUnitTest lintDebug assembleDebug lintRelease assembleRelease
node tools/kr006/audit-parent.mjs
```

This reuses only the unchanged Gradle wrapper; KR-003's code/pins are not modified.
Tooling: AGP 9.4.0 / Gradle 9.6.0 / built-in Kotlin + Compose compiler 2.2.10,
Compose BOM 2026.09.00, Activity Compose 1.13.0, Lifecycle 2.10.0, JUnit 4.13.2.
Verified 2026-09-11 from [AGP](https://developer.android.com/build/releases/agp-9-4-0-release-notes),
[AGP published POM](https://dl.google.com/dl/android/maven2/com/android/tools/build/gradle/9.4.0/gradle-9.4.0.pom),
[Compose BOM](https://developer.android.com/develop/ui/compose/bom/bom-mapping),
[Activity artifacts](https://dl.google.com/dl/android/maven2/androidx/activity/activity-compose/maven-metadata.xml).
Build/lint evidence, not version strings alone, establishes this bootstrap's compatibility.

Auth v2.196.0 and PostgREST v14.17 follow the current
[official self-hosted manifest](https://github.com/supabase/supabase/blob/master/docker/docker-compose.yml);
Mailpit v1.31.1 follows its [official release](https://github.com/axllent/mailpit/releases/tag/v1.31.1).
All three images are digest-pinned in the runner. APIs follow the
[Auth source contract](https://github.com/supabase/auth/blob/master/README.md).
No parent JWT is forged; confirmation comes only from the captured email.
