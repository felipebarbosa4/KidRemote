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
