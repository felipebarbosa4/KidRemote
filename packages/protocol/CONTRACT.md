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
ack/push routes remain unsupported in the local enrollment gateway, not stubbed.
The AC-6 extension below implements local credential rotation.
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

## KR-007 local validated removal (OD-45 AC-7)

Own `POST /device/sync` with a matched digest and server-verified revoked **device**
returns HTTP 403 and exactly `{protocol_version:1, code:"DEVICE_REVOKED", device_id,
policy_epoch}`. Both IDs derive from the verified credential/device join. No policy,
credential, household or replacement identity is returned. Caller target overrides
are rejected. A retired credential of a still-active device (including AC-6 old
generation retirement) returns only `CREDENTIAL_REVOKED`, never device removal.
Unknown/purged digests remain generic 401 `UNAUTHORIZED`; account-deletion rows
excluded by the existing active-household adapter also remain generic. No tombstone
lookup, account deletion workflow or additional sync endpoint is implemented here.

Only an exact bounded response from the configured own-sync endpoint with matching
protocol/device/epoch authorizes removal. Bare 403, other route errors, malformed/
duplicate/foreign fields, timeout and 401 cannot do so. Rotation 403 is rechecked
through own sync; retirement alone cannot remove the installation. The local debug
loopback transport is unchanged; production server authenticity still requires TLS.

The child atomically stores the validated envelope in its existing encrypted identity,
then displays Removed/re-pair required, never healthy or enforcement-ready. Pending
rotation candidates and other identity fields are retained until the user explicitly
clears the confirmed removed identity. Offline restart restores this state without
contact; no automatic new identity/credential or QR replay. The explicit clear removes
the identity/key and returns to unpaired. Corrupt/ambiguous identity/removal cannot
authorize this clear; the older missing-identity pairing recovery cannot erase an
existing unreadable file. No guardian confirmation method is invented.

**Configured-policy boundary:** the current adapter rejects configured/nonzero-version
policy and the child stores identity only, not any downloaded policy/cache/ledger.
This slice proves identity/removal persistence, not offline configured-policy retention
or application. Architecture still requires retaining the last valid downloaded policy
on outage/expiry until a valid newer policy/removal. Implementing/testing that store
and ordered snapshot acceptance belongs to later sync work (KR-009; accounting KR-008).
AC-7 remains partial until that dependency exists; no dummy policy cache/test is substituted.

## OD-47 KR-009 local configured sync/ack

This extends the historical enrollment-only boundary above. It is a local gateway,
not a deployed Edge function. FCM/push-registration/dispatcher remain unsupported.

`POST /parent/devices/{id}/operations` accepts exactly the operation envelope above;
body device ID must equal path, and actor is always the verified parent JWT subject.
All four kinds retain KR-004's existing transaction and preconditions. Its known
business conflicts pass through an invoker-rights `parent_operation` wrapper to
HTTP 409; `accept_control` is unchanged. This avoids PostgREST 14's documented
[custom 40001 retry loop](https://supabase.com/docs/guides/troubleshooting/high-cpu-and-infinite-transaction-retries-when-using-custom-error-codes-in-rpc-functions-77326b).
Unknown failures stay generic; raw DB errors are not returned. Response `accepted`
means commit only. `GET` on the same own-device path returns at most 100 operation
statuses under parent RLS, including server report receipt time and enforcement health.
Foreign/missing reads both return an empty result.

Configured own sync keeps request `{protocol_version:1, after_version:N}`. Response
has exactly protocol_version, kind=`CONFIGURED_SNAPSHOT`, device_id, policy_epoch,
version, policy_configured=true, daily_limit_seconds, manual_lock,
enforcement_available=false, timezone_name, timezone_revision, server_utc,
period_key, bonus_seconds, operations, history_pruned and credential_lifecycle.
Credential lifecycle is the existing generation/expires_at/rotate_after/rotation_due.
Operations contain operation_id/version/kind/period_key/status, sorted by version,
bounded to the newest 100 after the cursor through this snapshot. `history_pruned`
means older detail was omitted from this response window (not that server rows were
erased). There is no multi-page history API in this slice. Canonical state/high-water
convergence works despite omitted detail; no intermediate enforcement is inferred.
Policy, dated sum, outcome window and server UTC use one locked repeatable-read
transaction. Unconfigured version-zero bootstrap remains unchanged.

Child validates exact schema, own identity/epoch, numbers, zone and period before
settling measured use and merging only newer canonical fields. Duplicate JSON keys
and unknown fields/types are rejected. Existing approved A/B recovery is reused;
same-period sync does not forgive missing use. The existing ledger codec version 3
adds report_sequence and one immutable pending ACK in the same Room payload/transaction;
SQL schema 2 and migration validation remain unchanged. Older codecs are readable.
Process restart sends the pending ACK first with the original sequence/body; the
next report may describe the newly observed uncertainty. No second policy/identity
store or event history is introduced.

`POST /device/ack` has exactly protocol_version, device_id, policy_epoch,
applied_version (durable canonical version, not adapter success), report_sequence,
period_key, used_ms, bonus_seconds, remaining_ms, manual_lock, restriction_required,
restriction_applied=false, health=`ENFORCEMENT_UNAVAILABLE`, accounting_status
(NONE/HISTORY/CLOCK/STORAGE), observed_at (snapshot UTC; explanatory only).
IDs must match the authenticated credential. Server checks version, period, canonical
limit/lock/grants and aggregate consistency. A higher sequence replaces the latest
minimal report; same sequence + identical report returns the original receipt/time;
changed or older sequence conflicts. Receipt time, never observed_at, controls freshness.
This local protocol rejects applied=true: no enforcement adapter exists.

The RLS status projection distinguishes pending, persisted, superseded, expired grant
and recorded failed/rejected outcomes; applied additionally needs an actual observed
adapter receipt and report, which this slice never fabricates. Admission failure
returns rejected/failed explicitly and is not a committed operation. Only latest
report/retry digest is retained; unlimited receipt/event history is not added.

## OD-47 extension: local pages and recovery

This supersedes only the latest-100 shortcut above. First configured request retains
`after_version`; response adds `snapshot_id` and nullable `next_cursor`. The gateway
copies canonical fields, lifecycle and ordered operation outcomes in its existing
locked repeatable-read transaction into one private, RLS-protected temporary snapshot
per device/epoch. Cursor validity is five minutes; a new first request replaces that one
sequence unless canonical version, initial cursor, epoch, current period/zone and
credential generation still match a valid cache, in which case page 1 is identical.
At most one cache slot remains per device until replacement or device deletion;
expiry invalidates access and is not a background physical-deletion promise. Maximum 1,000 retained outcomes / 256 KiB server cache per device; at most
100 outcomes / 64 KiB per response. `history_pruned` means older detail was omitted
from this cache, never that omitted intents ran. Canonical version/high-water remains
authoritative. Server command/idempotency history is unchanged.

Later request is exactly `{protocol_version:1,after_version:N,cursor:"snapshot-uuid:offset"}`.
Offset is a page boundary 100..900; authenticated device/epoch, original N, snapshot
identity and expiry must all match. Every later response reuses the frozen canonical
fields/outcomes/time/version; newer commits and report status changes cannot leak in.
Duplicate cursor reads are identical while retained. Invalid syntax/extra page-size
fields return 400. Expired/replaced/missing/foreign sequences return the same bounded
410 `SNAPSHOT_RESTART_REQUIRED`, without device metadata. No cursor replaces device
authentication. The client restarts once immediately on 410, then uses bounded retry.
It validates all pages before the existing Room policy/ACK transaction and persists
only a minimal page checkpoint, never operation history. Process death discards that
checkpoint's sequence and starts a full fresh snapshot using the durable ledger.

Lifecycle triggers coalesce through one coordinator. A group runs at most one initial
and one follow-up sync. A bounded AtomicFile transport intent is separate from policy:
identity binding, pending/stopped and bounded stop reason, attempt, boot and
monotonic due/delay only; a checksum and AtomicFile protect recovery writes. It does
not contain bearer, cursor, policy or operations. One unique constrained periodic WorkManager
recovery request (15-minute interval, five-minute initial delay) is durably enqueued
before HTTP, closing the process-death seam between a worker and a later trigger; in-process retries use full jitter
1 s exponential to 5 min. Retry-After seconds or an HTTP date relative to server Date
forms a lower bound (bounded to 24 hours). WorkManager's own retry scheduling may
run later. Each recovery execution also refreshes canonical state when there is no
local pending intent, so a missed remote operation needs no push callback. Stopped
authentication never polls. Reboot rebases a stored retry delay without cross-boot elapsed
subtraction; this never supplies accounting time authority. 401/403 stop automatic
retry and retain downloaded state; supported rotation/removal stays in KR-007.
Explicit credential recovery may request another attempt. A successful approved
local accounting recovery may release only a STORAGE stop, never an AUTH or
PROTOCOL stop; becoming writable does not alter accounting uncertainty. Corrupt transport state
stops scheduling and cannot erase policy. No foreground service or exact alarm is
used; WorkManager is recovery, not a latency promise.

WorkManager 2.11.2 was checked against the [official release notes](https://developer.android.com/jetpack/androidx/releases/work).
[Work request documentation](https://developer.android.com/develop/background-work/background-tasks/persistent/getting-started/define-work)
explains constraints, initial delays and inexact minimum retry backoff. No FCM SDK,
provider address or physical/background delivery acceptance is selected by this slice.

## OD-48 local parent presentation

`POST /rest/rpc/parent_devices` (local PostgREST `/rpc/parent_devices`) accepts an
optional UUID `p_after`, parent JWT only. This invoker-rights SQL function reads
existing RLS-protected devices/policy/latest ACK/household in one statement snapshot.
It returns protocol version, server UTC and at most 50 rows ordered by device UUID;
a full page offers the next page, an empty page ends traversal. Each page is a new
read, not an immutable history sequence. Nickname/model presentation is bounded to
128 characters. No private credential, receipt digest or command history is exposed.
Report values are labelled with server receipt time; no parent countdown is derived.
Current canonical version/household period supplies operation preconditions, while
remaining/manual reasons come only from the last ACK, never desired-state optimism.

The parent submits the unchanged KR-009 operation envelope. A single latest retry
request (no bearer) is Keystore-wrapped under noBackup, account/epoch bound and cleared
on logout; retries reuse its ID/payload/preconditions. A new intentional action gets
a new UUID. Uncertain requests require retry/discovery before another action. The
existing operation-status GET resolves pending/persisted/superseded/expired/rejected.
This local UI never labels persistence as enforcement application. Server admission
conflicts are visible and are not silently retried with new payload/version.

List/detail refresh explicitly, on resume and every 15 seconds while open; only
freshness ages locally. No FCM or parent background scheduler is added. Last-known
rows remain timestamped in memory across backend failures; logout clears that cache.
Process restart restores authentication and the latest request, then rereads reports;
no second durable device-policy cache is introduced on the parent.

## OD-49 local observed enforcement extension

This supersedes only OD-47's local `restriction_applied=false`/unavailable-only ACK
restriction. Own-device reports retain the same exact keys, monotonic sequence,
immutable response-loss retry body, canonical version and aggregate validation.
Allowed adapter health values now include RESTRICTED_OBSERVED,
UNRESTRICTED_OBSERVED, SAFE_SURFACE_AVAILABLE, UNKNOWN_SURFACE_FAIL_OPEN,
SERVICE_DISCONNECTED, PERMISSION_REQUIRED, ADAPTER_PENDING and ADAPTER_FAILED.
`restriction_applied=true` requires RESTRICTED_OBSERVED and required=true; an
unrestricted observation requires both booleans false. A safe surface does not
claim the overlay is currently attached. Accounting health remains separate.
The server accepts authenticated device observations, not independent physical
attestation; received_at still means report receipt, not continuous enforcement.

Operation status remains pending until durable report, preserves superseded and
expired-period precedence, and reports applied only when the current observation
matches the required restriction or confirmed absence of the overlay. Parent UI
labels this as a device report; acceptance/persistence alone remains insufficient.
The frozen snapshot's legacy enforcement_available=false is not a child capability
or adapter observation; only the authenticated observed report describes the adapter.

Room payload format 5 reads formats 1–4 and keeps one bounded (512-character) latest
adapter observation beside the immutable pending ACK. It is diagnostic past state,
never restored as applied on process restart. No operation/window/package history
is added. New observations can persist offline without overwriting a pending retry.
The existing accounting A/B uncertainty rule is unchanged. The persisted blocked
measurement signal stops consumption while the overlay remains attached, independently
of permission/setup readiness and desired restriction; it cannot latch an Unlock.
