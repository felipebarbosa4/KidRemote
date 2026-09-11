# KR-007 camera and identity continuation

OD-45 only, PR #20; emulator evidence, never physical/OEM acceptance.
Existing `fb52936` APKs and historical enrollment evidence remain unchanged.

## Retained initial attempt

Source `abd889f`, CI [34653409119](https://github.com/felipebarbosa4/KidRemote/actions/runs/34653409119): all five jobs passed, including Android builds/lint, four parent and five child JVM tests. New Y-plane tests cover padded row/pixel strides, nonzero buffer position, four QR orientations and rejected truncated/invalid planes; these are synthetic decoder tests, not camera evidence.

Actual owned Windows AVD: Android 16/API 36, AOSP x86_64,
`Android/sdk_phone64_x86_64/emu64x:16/BE2A.250530.026.D1/13818094:userdebug/test-keys`,
emulator 37.1.11, WHPX. Runtime-only back `virtualscene`, front `none`; no webcam,
physical device or persistent AVD configuration change.

Local report `results-2026-09-11T22-25-47-811Z.json` in the existing owned KR-006 runtime directory is **NOT_PASSED**: `ENROLLMENT_ANDROID_FAILED:permissionAndLifecycle`.
The 15 prior Android enrollment/Auth invocations passed again. Additional executed results:

- Actual gateway outage/recovery retained identical ciphertext and device identity: PASS.
- Same-length authenticated ciphertext tamper: rejected; original ciphertext control recovered: PASS.
- Missing original Keystore key: rejected/never paired, **but read recreated a key**. This observed mutation is not an authentication bypass. Follow-up makes key creation save-only and asserts reads never recreate it.
- Ciphertext copied into clean synthetic app installation without original key: rejected; no new database identity: PASS.
- No camera opened before explicit Scan: PASS. The combined permission/lifecycle test then failed before its denial milestone; precise substage was not retained. Denial, grant, camera QR, revocation and later lifecycle results are **UNRUN/not established**, not PASS. Follow-up adds safe step diagnostics.

Child APK SHA-256 `1ad18a15ab09c1243e8db6641b4cc31d200d432b77ce6a20b4066e2f61f66673`;
child test `d7106c5aba6160c06caaf668bdd4ceec56d7cd4fa1b8923dae29c1eb7d428eec`;
parent `6dd074842b497178235ed10e6b994df01a5fc3b3ce4fc4dfda83f696216cf9f3`;
parent test `5c421879f0aeab535a6c6ff7381b12f6bacde7bdfb6436cb63dd4db09817cff3`.

Same attempt: PostgreSQL 17.6 disposable tmpfs database, owner
`1bf42b85-225e-414b-a3a0-083d4cea397c`, container
`840cea583824a3f4d60501e0c1e88ced08906a314d37b3a5af792b1da1d1d2c7`;
496 SQL, 28 existing protocol, 44 actual Auth/PostgREST and 29 actual enrollment HTTP/database assertions passed. The old protocol suite's gateway storage is labelled STUB; the new enrollment adapter is real PostgreSQL. Apps/test data, default virtual-scene posters, gateway/services, database and network cleanup verified. Failure remains retained independently.

Command (repository root, already verified owned AVD started with `-CameraValidation`):

```sh
KR007_CAMERA_STORAGE=1 KR006_RUNTIME_DIRECTORY=/mnt/c/Users/3feli/AppData/Local/KidRemote/kr006-runtime/e03b4820-193b-4132-b1fc-f7950eeed7fe node tools/kr004/test-local-db.mjs '/mnt/c/Users/3feli/AppData/Local/Programs/DockerDesktop/resources/bin/docker.exe' 'npipe:////./pipe/dockerDesktopLinuxEngine' --enrollment-runtime
```

## Scope and references

Follow-up CI [34654590996](https://github.com/felipebarbosa4/KidRemote/actions/runs/34654590996), `cf32000`: builds/JVM/lint and debug packaged-resource audit passed, but release audit failed because it assumed the unoptimized ZIP resource path. APK upload was skipped. Resolve each named backup resource through the packaged AAPT2 resource table, then perform the same strict XML checks; do not remove the release check. Added synthetic lookup tests for ordinary/shortened paths, absent, unsafe and ambiguous resources. This CI failure is separate from Android runtime evidence. An isolated repeat of the original permission test also reproduced the same pre-denial failure without opening another backend or enrolling any identity.

**Environment diagnosis and independent repeat:** read-only minimized observations found the current focused window was an Android System UI ANR (`systemUi=true`, `anr=true`), camera permission denied with neither USER_SET nor USER_FIXED, screen awake, nonsecure keyguard not showing. No window contents or raw dump were retained. The earlier failure did not retain this contemporaneous signal, so its exact historical cause remains UNSPECIFIED; System UI interference is a supported inference, not a retroactive app defect or PASS. One owned-AVD stop/start (no wipe/configuration change) cleared the observed ANR. The first immediate restart was conservatively refused while its port was still in use; a later verified free-port start succeeded.

On the **unchanged `abd889f` APK**, the isolated `permissionAndLifecycle` repeat after restart passed: no camera before Scan, real system-dialog denial without redemption, real foreground grant/camera open, cancel/background/recreation release and explicit reacquisition. No camera implementation fix was needed for those checks. Earlier failed attempts remain failed. No new synthetic identity/backend was used in these isolated permission repeats.

Corrected audit/build CI [34655087343](https://github.com/felipebarbosa4/KidRemote/actions/runs/34655087343), `e60e72a`, passed all five jobs, including packaged debug/release backup XML, builds/lint, JVM tests, SQL/Auth and Windows PowerShell 5.1/7 suites. Runtime using these APKs is recorded separately below; compilation does not prove runtime behavior.

The full `e60e72a` runtime attempt `results-2026-09-11T22-48-02-207Z.json` remains **NOT_PASSED**, `ANDROID_RUNTIME_STAGE_FAILED:networkFailureAndRecovery`. Its first three parent invocations passed; the fourth retained `ACTUAL_REST_OUTAGE_RECOVERABLE_UI_PASS` only. Child/storage/camera were not reached. All 496 SQL/28 protocol/44 Auth/29 enrollment assertions and owned cleanup passed. Disposable DB owner `99973b18-185d-40a9-8017-47990098a862`, container `c4996440fbae88d761ed4d1b0a31377f401276e663c66ee1b4da282be47bbd62`. No prior attempt is replaced.

Code inspection establishes a test-helper defect: `get()` used AssertionError for a non-200 HTTP response, but the existing bounded readiness retry catches Exception. A transient non-200 would bypass retries. The retained failure does not establish its exact HTTP status, so that specific causal attribution remains INFERRED. Change only the instrumentation helper to IOException on non-200, retaining the same deadline and final assertion. Add an actual HTTP non-success regression (absent synthetic test resource) and a safe readiness milestone. No production parent/network behavior or assertion gate is weakened.

Independent permission execution on `e60e72a` child APK passed without backend/identity: `permissionAndLifecycle` (including actual deny/grant), then `revocationVictim` reached its camera-open marker. Targeted `pm revoke` caused the test app process to disappear and instrumentation **not** to complete, the expected OS termination, not a passing test invocation. `afterPermissionRevocation` passed in a different PID with denied permission, no paired/pending state, explicit system-dialog regrant and camera release. Scoped app-data cleanup passed. Child SHA-256 `cc2754d0779b78bf98fa82f7ce2682ae00bf973b7a89ea4b9b0ef44df563164f`, test `643e2f81c82546486841cdbeeff9febcd86e818d7f4ec948027e92810d60acf2`. The interrupted invocation is recorded separately from the two passing tests. No virtual QR decode claim follows from permission/camera opening alone.

Native emulator console accepts `virtualscene-image <wall|table> [path]`; omitting path restores default. Synthetic PNG/ciphertext artifacts stay in unique owner-local task directories; no upload/logging/image viewing. Preserve failed/partial artifacts for owner review, no automatic replacement/deletion.
[Official camera documentation](https://developer.android.com/studio/run/emulator-use-camera) describes importing PNG/JPEG, including QR, into the virtual scene. This tests CameraX/decoder acquisition only when actually observed; it does not certify physical camera quality.

Native AAPT2 37 inspected packaged `backup_rules.xml` and `extraction_rules.xml`: root/device_root exclusions, both cloud-backup and device-transfer. The CI audit now verifies packaged resources as well as merged `allowBackup=false` and identity storage in `noBackupFilesDir`. [Android backup documentation](https://developer.android.com/identity/data/autobackup) and [AAPT2](https://developer.android.com/tools/aapt2) are the configuration basis. Configuration inspection/clean-install ciphertext rejection are not OEM backup/transfer tests.

AC-2/3 and camera/incomplete-setup AC-4 remain partial until their evidence is obtained; physical/OEM requirements and AC-6/7 remain pending. No enforcement readiness, rotation, broader removal or KR-008 work.

## Final available-configuration execution

APK/host source `01c6264096d773670dbc0846413ceb00e54c2c05`, CI
[34655855796](https://github.com/felipebarbosa4/KidRemote/actions/runs/34655855796):
all five required jobs passed. The superseded in-progress `45dfcf2` CI was cancelled,
not passed; the final HTTP regression requires an actual non-200 response, not merely
a failed connection. No assertion deadline or acceptance gate was relaxed.

[Sanitized actual runtime record](KR-007-CAMERA-STORAGE-RUNTIME-2026-09-11.json),
original `results-2026-09-11T23-00-06-316Z.json`: **NOT_PASSED** overall,
`ENROLLMENT_ANDROID_FAILED:invalidCameraQr`. **23 PASS invocations, one failed**,
plus one deliberately interrupted camera-open invocation for OS revocation (not counted as PASS).

| Boundary | Observed result |
| --- | --- |
| Parent Auth/UI/recovery, enrollment/initial read/list, interrupted commit/revoke/fresh QR | PASS again through actual apps/HTTP/database; initial QR was decoder input, not camera |
| Retry helper HTTP non-success and actual REST outage/recovery | PASS; readiness milestone retained |
| Gateway outage | PASS, same valid local identity and exact ciphertext retained; real authenticated read recovered |
| Same-length authenticated ciphertext tamper | PASS rejection/no paired state; original encrypted control recovered |
| Missing Keystore key | PASS rejection, **no replacement key created** |
| Copy ciphertext into clean installation without original key | PASS rejection, no key creation and no new database identity |
| Camera before explicit Scan | PASS, not opened |
| Actual permission denial/grant | PASS, truthful denial/no pending identity, foreground camera opens only after grant |
| Cancel/background/recreation/return | PASS release, no automatic resume, explicit reacquisition |
| Camera permission revoked while open | Expected OS process termination; separate restarted test PASS, permission denied and no paired/pending state, explicit regrant/release |
| Native virtual-scene poster control | Console accepted local synthetic invalid PNG for wall/table; hash retained; no webcam |
| Invalid QR via actual camera/analyzer | **FAILED test**, expected `QR inválido` state not established; safe exception enum OTHER |
| Valid camera QR/redemption, repeated frames, camera-enrolled identity restart | **UNRUN**, blocked by failed preceding control |
| Camera/app/service cleanup | PASS; default posters restored, synthetic app/test data cleared, owned gateway/Auth/mail/REST/database/network removed |

The invalid-camera test includes a 45-second state wait, but its retained OTHER enum does
not independently identify the exception class. **UNSPECIFIED:** whether the boundary
is frame delivery, virtual-scene framing, decoder recognition or another test error.
Camera opening and console acceptance do not prove QR acquisition. Post-attempt read-only
check found no focused System UI ANR; native console help exposes `virtualscene-image`
but no pose-control command. Do not claim that the virtual camera is universally
unsupported, that the application has a reproduced decoder defect, or that invalid
camera input successfully reached validation. No replacement camera simulator, webcam,
image viewer or retained camera frame was used. This is the bounded remaining emulator
limitation; independent permission/storage work completed despite it. No owner action
or physical operation was requested to bypass it.

Same attempt: disposable PostgreSQL 17.6 container
`564ce131de2a1bee621fd75589c1e5e5a4d3a3981ad107f37dbd5227679f28c9`,
owner `f566734e-d8bf-4413-90ab-77606075319d`, zero database ports, task tmpfs.
Four migrations, **496 SQL + 28 existing protocol + 44 Auth + 29 enrollment HTTP/DB**
assertions passed. The old gateway-operation STUB boundary remains explicitly separate.
Local Node source/security/resource-lookup tests: **13 passed**, no skips.
CI executed parent/child JVM (4/5), debug/release build/lint/isolation, actual local
backend tests and native Windows PowerShell 5.1/7. CI does not run emulator integration;
the Windows runtime above is the executed evidence. No extra manual unchanged Android build.

| Exercised APK (`apks-kr007-camera`, owner-local task directory) | SHA-256 |
| --- | --- |
| app-debug.apk | `cd6b0e911a0547003a949268cb39bd78a2179d07228370158fd4c8dc7ea248b7` |
| app-debug-androidTest.apk | `81518c1db3ad6160cab1f60f60cc3067042d5cede715a57237dc706fd36fe2b4` |
| child-debug.apk | `77850d6c4317095f03fe41294ca7dc8afb114f47206393164097327ee2837bd9` |
| child-debug-androidTest.apk | `459ede363ea433b35233110a8d5cc80d50e73ebf8715325ccc94ab8af6482326` |

Full local root: `C:\Users\3feli\AppData\Local\KidRemote\kr006-runtime\e03b4820-193b-4132-b1fc-f7950eeed7fe`.
Downloaded APKs remain additionally in `artifacts-kr007-01c6264`; prior versions remain
in their separate directories. The four original `apks-kr007` hashes still match the
published `fb52936` evidence. AVD stop was explicitly targeted and acknowledged; no
AVD deletion/wipe or host configuration change. Retain local failed synthetic artifacts
and reports for owner review; no upload or silent replacement. No real account was used.
Post-stop native Windows listener check found zero listeners on the task emulator/service
ports 5584/5585/57361/57362/57364/57365/57366.

The only reproduced production-code hardening change is save-only key creation;
camera conversion was extracted unchanged for synthetic stride/orientation tests.
The release resource audit and HTTP readiness fixes are test/validation changes.
AC-2/3/4 remain unchecked overall: camera QR acquisition and physical/OEM acceptance
are open; AC-4 evidence covers camera only, not enforcement permissions. AC-6/7 remain
out of scope. KR-003 evidence, visual work and immutable bundles are unchanged.
