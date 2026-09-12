# Control and sync protocol — design version 1

- **Goal:** Deliver ordered, idempotent control with local execution.
- **Context:** PRODUCT, STATE-MACHINE, ADR-0003/0006; paths below are proposed KidRemote APIs, not vendor SDK methods.
- **Constraints:** TLS, scoped identities, atomic persistence, push hints only, no cloud countdown.
- **Done when:** KR-009 passes duplicate/order/reconnect/failure-injection tests and publishes verified wire fixtures.

## Proposed routes

| Route | Identity | Behaviour |
| --- | --- | --- |
| POST /parent/households | Verified parent JWT | Idempotent first household |
| POST /parent/pairing-sessions | Parent JWT | Own-household QR challenge |
| POST /pairing/redeem | Single-use pairing secret | Create one device identity |
| POST /parent/devices/{id}/operations | Parent JWT | Validate membership and atomically accept operation |
| POST /device/sync | Device opaque credential | Own current policy, dated grant totals, commands and lifecycle |
| POST /device/ack | Device opaque credential | Persist own receipt + latest minimal report |
| POST /device/push-registration | Device opaque credential | Replace own provider address |
| POST /device/credentials/rotate | Device opaque credential | Bounded credential rotation |
| DELETE /parent/devices/{id} | Parent JWT + recent reauthentication | Revoke/remove device |
| DELETE /parent/account | Parent JWT + recent reauthentication | Revoke household devices and delete account workflow |

Parent direct reads use RLS; delete/ack routes never trust client household/actor fields.
Device endpoints do not accept Supabase user JWTs as device identity. A publishable key alone is no authorization.
Supabase custom credential endpoints need handler authentication with the platform JWT gate configured appropriately; “verify_jwt=false” alone is never authentication.
[Edge auth](https://supabase.com/docs/guides/functions/auth).

## Operation envelope

The [KR-005 pairing contract](../../supabase/functions/pairing/README.md) defines the
accepted local QR version/session/token envelope and atomic transaction fixtures;
Auth/Edge deployment and the full device-storage adapter remain unrun.

OD-45's initial enrollment adapter implements only `POST /device/sync` with
`{"protocol_version":1,"after_version":0}` for an unconfigured version-zero policy.
Its fixed response is `kind=ENROLLMENT_BOOTSTRAP`, protocol_version, device_id,
policy_epoch, version, policy_configured=false, daily_limit_seconds=null, manual_lock
and enforcement_available=false. Values come from a single locked DB transaction;
this is **not** the full synchronization contract below. Configured-policy reads,
ack/push/rotation routes remain unsupported in the local enrollment gateway, not stubbed.
No device-state report/online/healthy status is created from this initial read alone.

```json
{
  "protocol_version": 1,
  "operation_id": "UUID",
  "device_id": "UUID",
  "kind": "ADD_TIME",
  "payload": {"seconds": 600, "period_key": "1:2026-09-05"},
  "expected_version": null
}
```

This is illustrative notation: literal UUID placeholders are not valid test IDs.
LOCK, UNLOCK, SET_DAILY_LIMIT require expected_version; ADD_TIME requires current period and exactly 600 or 1800 s.
Server appends authenticated actor_user_id, server accepted_at, policy_epoch and strictly increasing device version.
Operation ID globally unique; replay by same actor/target with identical content returns original result; changed actor/target/payload returns conflict without leaking foreign row existence.
A request failure before acceptance can be retried with the same ID. Client timestamps never order operations.

## Desired state + auditable intents

LOCK/UNLOCK set manual_lock; SET_DAILY_LIMIT sets recurring allowance. Server maintains latest absolute desired state.
ADD_TIME creates one immutable dated grant; sync returns the absolute bonus sum for each required day.
Commands record every accepted intent and its application outcome.
This avoids incrementing local bonus on delivery and allows a current snapshot to supersede stale manual-lock intent.

Each sync includes policy_epoch, version, manual_lock, recurring limit, household timezone/revision, server UTC,
current-period absolute bonus, period keys, operations after client's cursor through snapshot version, and compatibility requirements.
All components come from one consistent snapshot. Responses include a snapshot version and pagination cursor if needed.
Before an explicit initial limit is set, policy_configured=false and daily_limit_seconds=null; child remains in setup and does not infer a zero/default allowance.
Page fetches must remain bounded to that version; if snapshot expired, restart sync. Proposed page size 100; maximum payload 64 KiB.
Current desired state can be applied immediately; operation receipts are then reconciled through the same version.
A new future command cannot be stamped as applied by an older snapshot.
If detailed command history has been pruned, return history_pruned plus the latest authoritative snapshot and retained operation outcomes/tombstones.
Child advances its control high-water mark through that snapshot and reports convergence; it must not claim discarded intermediate intents were individually executed.
Past grants never migrate into the current day. Retained server idempotency tombstones reject old operation replays after payload pruning.

Child application order:
1. Authenticate server TLS; validate schema, own target, epoch, version and bounded numeric values.
2. Settle measured local usage to current monotonic instant.
3. In one local transaction replace only newer canonical control fields, merge absolute dated bonuses, preserve used_ms, persist version and pending receipt.
4. Derive required restriction; call native adapter; persist observed result/health separately.
5. Acknowledge durable policy and observed enforcement. Retry acknowledgement after crash.
6. Publish minimal state with increasing persisted report_sequence.

A duplicate/older snapshot cannot decrease version or used_ms; re-acknowledge already applied state.
Unknown operation types/protocol major → reject explicitly, retain last valid local policy, report App update required.
An older epoch never replaces local state without re-enrollment.

## Receipts and parent meaning

| Outcome | Meaning |
| --- | --- |
| accepted | Server transaction committed |
| pending | No device application receipt yet; push success does not change this |
| persisted | Child durably stored desired state; enforcement result may still be pending |
| applied | Desired state persisted and adapter reports required transition succeeded; include both booleans |
| superseded | An intermediate Lock/Unlock/limit intent was replaced before execution by newer desired state |
| expired_for_period | Old dated grant was not credited to today's balance |
| failed / rejected | Validation, compatibility or enforcement failure with redacted code; last good policy remains |

Do not claim that a superseded LOCK briefly ran. A grant included in absolute total is applied once, even if individually delivered many times.
At policy zero, an applied UNLOCK means manual flag cleared; required restriction remains true.
The UI distinguishes transport state, intent result, policy lock reasons, and observed enforcement.
Ack report includes device/epoch, applied_version, report_sequence, period_key, used_ms, bonus_seconds, remaining_ms,
manual_lock, restriction_required, restriction_applied, health flags, app/OS major, and observed_at.
Server receipt time drives freshness; untrusted device wall time is explanatory only.
Server can reject impossible/negative state but cannot prove honest usage on a rooted device.

## Synchronization and retries

Triggers: push hint, app resume, accessibility service reconnection, process restart, post-unlock boot recovery,
network available while process is alive, and unique WorkManager best-effort recovery work.
Registering a connectivity callback does not resurrect a dead process.
Coalesce concurrent triggers into one sync; if a hint arrives during sync, run another after completion.

Recommend full-jitter exponential network retry: 1 s base → 2/4/8… capped at 5 min while runnable; honour Retry-After on 429/503.
Persist retry intent for WorkManager, subject to OS scheduling. Retry resets after success; no tight unauthorized loops.
401 → attempt only supported credential rotation/recovery then stop/re-enrol; 403 revoked → removal state;
409 version/period → refresh and show conflict; malformed payload/unsupported version → no automatic replay with changed meaning.
Outbox dispatcher: attempt after commit, plus one-minute recovery scan; leases permit retry after worker death.
Cap provider retries at 24 hours per hint, then abandon the hint (never the canonical state). A later sync still discovers state.
Proposed hints expire after five minutes and collapse to latest version per device; data payload says only “sync”.
A normal-priority hint is default. High priority requires a real time-sensitive user-visible notification and compatibility review.
[FCM priority](https://firebase.google.com/docs/cloud-messaging/android-message-priority),
[Android receive](https://firebase.google.com/docs/cloud-messaging/android/receive-messages),
[message lifespan](https://firebase.google.com/docs/cloud-messaging/customize-messages/setting-message-lifespan).

## Push addressing — current documentation discrepancy

Verified 2026-09-05: HTTP v1 Message marks `token` deprecated and recommends `fid`; registration-management docs discuss Firebase Installation IDs.
The Android quickstart still demonstrates FCM registration tokens and `onNewToken`.
Follow the current REST contract for the new adapter and validate against a real Firebase project before selecting SDK versions.
Model `provider` and `address_kind` explicitly: `fcm/fid`, with a tested migration-only `fcm/registration_token` option if required.
Do not substitute a Firebase installation auth token for either push address or KidRemote credential.
Compatibility/rollout behaviour for our project: **UNSPECIFIED**; KR-009 evidence required.
[FCM REST Message](https://firebase.google.com/docs/reference/fcm/rest/v1/projects.messages),
[registration management](https://firebase.google.com/docs/cloud-messaging/manage-tokens),
[Android setup](https://firebase.google.com/docs/cloud-messaging/android/get-started),
[Installations](https://firebase.google.com/docs/projects/manage-installations).

Registration refresh is own-device authenticated, atomically replaces previous address, records timestamp and deletes invalid provider addresses on definitive response.
A provider address collision with another active device is rejected/investigated; never silently reassign or reveal its owner.
No household topics for private commands. No secrets or policy in push payload.

## Freshness proposal

Online means a successful device sync/report received within 120 seconds; label “Seen recently” in explanatory text.
Propose reports on state changes and at most every 60 seconds during active permitted use; asleep reports are best effort.
Offline means no recent report, not proof of disconnected radio. It may mean killed app, sleep or removed permissions.
Show “Last seen …”, last reported remaining, pending duration, and health last checked time.
Do not animate a precise parent countdown between unverified reports; refresh while screen open (proposed 15 seconds).
These are tuning proposals for KR-009/010, not provider guarantees.

## KR-007 local two-phase credential renewal (OD-20 / OD-45 AC-6)

`POST /device/credentials/rotate` uses the existing opaque bearer and bounded JSON.
All phases require exactly `protocol_version: 1`, UUID `operation_id`, and `phase`.
`BEGIN` additionally requires `new_credential`, a canonical base64url encoding of
32 securely random bytes. CONFIRM/STATUS reject that field; all phases reject caller
device/household targets, extra fields and arbitrary RPC selection. TLS remains the
production contract; only the existing fixed emulator/debug loopback exception applies.

Before any mutation request, the child atomically persists old credential, new
candidate and operation ID in its existing Keystore-wrapped, backup-excluded identity.
References to both candidates survive process death; no server plaintext recovery is
needed. BEGIN authenticates the old credential against current server records under
the device lock. Server time must be at/after its creation +30 days and before expiry.
It creates exactly generation+1 with 90-day expiry and fixes the old credential's
deadline to min(previous expiry, first BEGIN time +5 minutes). Identical retries return
the same generation/deadline, never another secret or longer overlap. Conflicting
operation/candidate reuse is rejected. There is no automatic scheduler in this slice.

CONFIRM authenticates only the persisted new candidate, marks the operation confirmed
and revokes old atomically. The five-minute limit also expires old if no confirmation
arrives; it does **not** extend old validity until an acknowledgement. New retains its
own 90-day expiry and may confirm after old expires: this is possession of an already
valid candidate, not recovery by an expired credential. STATUS requires either valid
candidate of this same operation. Expired/revoked credentials never regain authority.
No active candidate means explicit parent recovery/re-pair, not secret replay.

Success replies contain only `result` (PENDING/CONFIRMED), operation/device IDs,
unchanged policy epoch, generation, expires_at, rotate_after and overlap_until.
Unknown/expired bearer ->401; verified revoked ->403; malformed ->400; not-due,
conflicting or missing operation/old-possession confirmation ->409; storage failure
->503 without raw errors. The database transaction rechecks authority independently
of handler parsing. Private rotation rows contain lifecycle IDs/timestamps only;
credentials remain digests in the existing private table.

The initial authenticated bootstrap read now includes `credential_lifecycle`
(generation, expires_at, rotate_after, server-derived rotation_due). On authenticated
contact the child resumes a pending operation first: try new CONFIRM, and only a 401
permits retrying the same BEGIN with old. A successful CONFIRM permits atomic local
promotion and a new authenticated initial read. Any uncertain transport/storage
failure preserves the encrypted identity/pending candidates. Current local bootstrap
is still unconfigured; no configured-policy cache/sync/enforcement is implemented.

Tests move synthetic row timestamps, never clocks. Android debug instrumentation can
withhold a **real committed HTTP reply after HTTP receipt/JSON parsing but before
renewal consumes it**. This tests application response loss/process recovery, not
packet-level loss or an Edge deployment. The phase-only hook has no release storage
or setter, no secret output and is not an authorization/commit stub.
