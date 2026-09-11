# Native child Android agent

OD-45 local enrollment only. No enforcement or production use is authorized.

- Goal: Real local parent QR -> child independent identity -> initial scoped read -> parent list.
- Context: [Design](../../docs/adr/0002-android-enforcement.md).
- Constraints: Synthetic local accounts and verified task-owned emulator only; no physical install, enforcement, deployment or real use.
- Done when: The owning issue's acceptance/tests have evidence.

This is module `:child` in the existing `apps/parent-mobile` Gradle build, with the
same pinned Kotlin/Compose/AGP/JDK toolchain. Provisional ID
`dev.kidremote.child.unassigned.debug`; not a distribution identity.
ZXing core 3.5.4 decodes locally; CameraX 1.6.2 binds foreground user-requested analysis
to the lifecycle, closes each ImageProxy and stops on pause. No frame retention/upload,
gallery permission or background camera feature. See [ZXing](https://github.com/zxing/zxing/releases)
and [CameraX analysis](https://developer.android.com/media/camera/camerax/analyze).

Only the fixed debug endpoint `10.0.2.2:57366` is cleartext-enabled; release has no
endpoint. Credential bytes use AndroidKeyStore AES-GCM + AtomicFile/noBackupFilesDir,
with cloud/transfer exclusions. A durable nonsecret pending marker precedes redemption:
uncertain outcome cannot auto-replay; parent must verify/revoke incomplete pairing and
provide a fresh QR. Corrupt identity is never rendered paired; valid identity is not
discarded merely because a read fails. No default allowance or enforcement capability.

Current camera/physical execution is UNRUN. Synthetic QR encoder/decoder and actual
HTTP/storage/app tests are separate evidence, not camera permission/scan acceptance.
Rotation, removal and OEM backup/transfer acceptance remain pending. Local Node gateway
is not an Edge deployment. Startup/runtime results will be recorded in KR-007 evidence.

## Local startup and bounded test

From the repository root in WSL, start the reused task-owned services (Ctrl+C verifies
scoped cleanup; no pre-existing database is reset):

```sh
node tools/kr004/test-local-db.mjs '/mnt/c/Users/3feli/AppData/Local/Programs/DockerDesktop/resources/bin/docker.exe' 'npipe:////./pipe/dockerDesktopLinuxEngine' --enrollment-dev
```

This adds the loopback-only Node gateway on 57366 to the existing Auth/PostgREST/mail
ports 57361/57362/57365. The debug apps use Android emulator host alias `10.0.2.2`.
Use the existing [owned emulator startup](../parent-mobile/README.md#verified-windows-emulator-integration).
Do not operate another AVD or a physical device. Download the four APK artifacts from
the tested PR #20 CI source into the owned task directory's **apks-kr007/**, keeping
the previous KR-006 **apks/** and its exercised hashes unchanged.

For the automatic synthetic run, stop dev services first, then run:

```sh
KR006_RUNTIME_DIRECTORY=/mnt/c/Users/3feli/AppData/Local/KidRemote/kr006-runtime/e03b4820-193b-4132-b1fc-f7950eeed7fe node tools/kr004/test-local-db.mjs '/mnt/c/Users/3feli/AppData/Local/Programs/DockerDesktop/resources/bin/docker.exe' 'npipe:////./pipe/dockerDesktopLinuxEngine' --enrollment-runtime
```

This verifies AVD identity before every Android operation, runs the parent Auth
regressions, then the two applications sequentially on that same emulator. Generated
synthetic QR pixels exercise the real decoder and redemption callback; this does not
test a camera scan or permission prompt. The interruption hook exists only in debug
and throws after real redemption commit but before identity storage. It is not a
forged successful response or a simulated database transaction. Both app/test data
sets and all owned backend resources are cleaned; sanitized reports stay in the task
directory. Stop the owned AVD with the existing script's `-Mode Stop` afterwards.
