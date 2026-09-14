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
