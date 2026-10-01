# KR-009 local control/sync/ack

[OD-47 execution contract](../../docs/exec-plans/KR-009-LOCAL-SYNC.md).

Use `node tools/kr004/test-local-db.mjs <local-docker> <local-endpoint> --sync-test`
for actual isolated PostgreSQL, Auth/mail/PostgREST and loopback gateway tests plus
existing regressions. `--sync-runtime` additionally uses the existing owned emulator
and `KR006_RUNTIME_DIRECTORY` / `KR009_APK_SOURCE` with matching APKs in
`apks-kr009-<source-prefix7>`. Start/stop only that owned emulator with the existing
owner-checking helper. No FCM, physical device, enforcement or deployment exists.

Parent requests go through real JWT verification and the existing atomic control
transaction. Sync persists canonical state and an immutable pending report together
in existing Room. Explicit restart/retry converges without push. The host test passes
only a real redeemed child identity through guarded stdin; no parent JWT enters the
child. Temporary handoff is deleted after Keystore-wrapped identity persistence.

Runtime reports contain APK hashes/source and enumerated results only. The kill
seam occurs after actual Room commit before ACK. Lost ACK hook withholds a real
successful HTTP response before local confirmation. Malformed/older response tests
modify a real received HTTP body before validation; this is a controlled client
boundary fixture, not a server corruption or packet-loss claim. Yesterday's grant
uses a disclosed historical SQL fixture, never backdated parent authority or edited
host/device clocks. No physical signal accuracy/performance acceptance follows.

The retained push outbox still receives rows inside KR-004 acceptance; it has no
provider registration or dispatcher here. Full KR-009 FCM/notification, background
scheduling, capacity/latency and physical acceptance remain open.

[Observed SQL/HTTP/Android results, exact APK identities, independent failures and cleanup](../../docs/test-plans/evidence/KR-009-LOCAL-2026-09-13.md). This local exception demonstrates AC-1/2 and parts of AC-3/4/7/8/9; the full issue remains open.

[OD-47 pagination/recovery extension results and independent partial attempts](../../docs/test-plans/evidence/KR-009-PAGES-2026-09-13.md): frozen authenticated pages, bounded history, durable coalescing/retry and actual local Worker/resume/network convergence. Dispatch controls and physical/provider/performance gaps are explicit.

## First-policy discovery investigation (owned emulator only)

`first-policy-native.mjs` reuses the existing owner-verified emulator at port 5584.
Start and stop it with `tools/kr006/windows-emulator.ps1`; this runner does not create
or discover a physical target. Native Windows Node is required; no WSLInterop repair.

Build the debug child and instrumentation APKs with the existing Gradle build. Retain
a new artifact directory under the owner directory, with `source.json` containing
`source`, `workingTreeChanged`, and `apks` (SHA-256 of `child-debug.apk` and
`child-debug-androidTest.apk`); `testSources` may pin the test-source hashes. Never
replace a previously retained artifact directory or claim a dirty build is exact-source CI.

Run `node tools/kr009/first-policy-native.mjs <absolute-owned-apk-directory>` for
real Android lifecycle/Keystore/Room against a clearly labelled loopback server
fixture. It observes normal first configuration and a deliberately retained
45-second retry deadline; fixture ACKs are not real backend reports.

Add `--connected` for real synthetic Auth/confirmation/enrollment/first policy and
server ACK, or `--connected-service` to enable the existing product service during
that same path on the emulator. All synthetic enrollment originates in Android;
no host-to-device credential handoff is used. These modes allocate a new isolated
native lease, require the original lab stopped and loopback ports free, and remove
only the newly owned resources. Successful cases clear only synthetic emulator app
state. Failed results remain separately recorded for review, not silently replaced.

[Executed observations and limits](../../docs/test-plans/evidence/PRODUCT-INITIAL-REPORT-TIMEOUT-2026-09-30.md#executed-android-first-policy-reproduction---2026-10-01)
distinguish the four runtime scenarios, the earlier guard failure and Samsung's
still-unresolved timeout. CI compiles these tests and audits the driver; it does not
execute this Windows emulator implicitly and does not accept physical enforcement.
