# KR-004 local device-gateway authorization boundary

`handler.mjs` is an executable Request/Response handler, not a deployed Edge function.
It uses the accepted ADR-0003 opaque 256-bit bearer (canonical base64url), SHA-256 digest
lookup and constant-time digest comparison. No JWT/device-account scheme, issuance,
pairing or parent login is added. Credentials never appear in responses or logs.

Three fixed contracts are recognized: `/device/sync`, `/device/ack`, and
`/device/push-registration`. Unknown routes, methods, parameters, fields, RPC selection
and caller-supplied device/household/actor fields fail closed. The receipt path verifies
the command's device (including same-household sibling denial), household, epoch and
version bounds before storage. Push address ownership cannot silently transfer.
Rotation is deliberately unsupported here; KR-005/007 implement its lifecycle.

`repository.withCredential(digest, callback)` is the storage transaction boundary.
It supplies a current credential/device join, policy version and fixed scoped methods:
`sync`, `findCommand`, `ack`, `findPushOwner`, `registerPush`. The future database adapter
must hold/recheck credential/device revocation and make address-conflict checks atomic
with storage. It must never dispatch a request-supplied RPC or use household membership
as a substitute for device identity. Only the handler authorizes the returned records.

**Explicit AC-5 test dependency stub:** the Node HTTP suite supplies those records and
storage callbacks synthetically. It does not mock credential verification or authorization.
42 HTTP scenarios (43 Node test entries including the parent test) passed on loopback;
responses from allowed operations are labelled `STUB_*`, not claimed persisted sync/ack.
No complete sync engine, Auth/PostgREST/Edge runtime integration, rate-limit service,
credential rotation or production-ready storage adapter is claimed by this slice.

Run `node --test tools/kr004/gateway.test.mjs`. The listener binds `127.0.0.1` on an
ephemeral port and closes after tests. Secrets are generated in memory per test.
No backend/node dependency package or server entrypoint is installed or published.

Sources reviewed 2026-09-11: [Supabase Edge authentication](https://supabase.com/docs/guides/functions/auth),
[Deno Node compatibility](https://docs.deno.com/runtime/reference/node_apis/).
Node execution here does not certify Deno/Edge compatibility or permit deployment.
