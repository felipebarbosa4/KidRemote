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

Native emulator console accepts `virtualscene-image <wall|table> [path]`; omitting path restores default. Synthetic PNG/ciphertext artifacts stay in unique owner-local task directories; no upload/logging/image viewing. Preserve failed/partial artifacts for owner review, no automatic replacement/deletion.
[Official camera documentation](https://developer.android.com/studio/run/emulator-use-camera) describes importing PNG/JPEG, including QR, into the virtual scene. This tests CameraX/decoder acquisition only when actually observed; it does not certify physical camera quality.

Native AAPT2 37 inspected packaged `backup_rules.xml` and `extraction_rules.xml`: root/device_root exclusions, both cloud-backup and device-transfer. The CI audit now verifies packaged resources as well as merged `allowBackup=false` and identity storage in `noBackupFilesDir`. [Android backup documentation](https://developer.android.com/identity/data/autobackup) and [AAPT2](https://developer.android.com/tools/aapt2) are the configuration basis. Configuration inspection/clean-install ciphertext rejection are not OEM backup/transfer tests.

AC-2/3 and camera/incomplete-setup AC-4 remain partial until their evidence is obtained; physical/OEM requirements and AC-6/7 remain pending. No enforcement readiness, rotation, broader removal or KR-008 work.
