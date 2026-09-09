# Acceptance and failure-injection matrix

- **Goal:** Make MVP correctness, isolation and supported Android behaviour observable.
- **Context:** First-pass design only; every execution result below is **UNSPECIFIED**.
- **Constraints:** Synthetic families/secrets; physical evidence required for OS behaviour; no production tenant data.
- **Done when:** Relevant issue tests pass with evidence and release gates cover all required rows.

U = deterministic unit/domain test; I = integration (local DB/Auth/API or instrumented Android); P = physical device; F = failure injection.
Store each run under `docs/test-plans/evidence/` with commit, app/protocol versions, model/OS/build, permission/battery settings,
network state, steps, expected/observed results, timing sample count and redacted artefacts.
Do not mark a documentary test plan as executed. Owner-approved semantics must replace provisional expectations first.

## Pairing and authorization

| ID | Given / when | Then / observable pass criterion | Level | Issue |
| --- | --- | --- | --- | --- |
| PAIR-01 | Auth parent and valid QR; child redeems | One correct-household device, scoped credential, challenge consumed | I/P | 005/007 |
| PAIR-02 | Server TTL passed | No device/credential; explicit expired state | U/I | 005 |
| PAIR-03 | Redeem consumed QR again | Replay rejected, no credential reissue | I/F | 005 |
| PAIR-04 | B polls/cancels A session or supplies foreign household | Denied without foreign metadata | I | 004/005 |
| PAIR-05 | Network lost before commit | No partial identity; retry if unexpired | I/F | 005 |
| PAIR-06 | Network lost after commit before secret saved | Token remains consumed; visible incomplete device; fresh QR/revoke recovery | I/P/F | 005/007 |
| PAIR-07 | 20 concurrent redemptions | Exactly one commits; all others reject | I/F | 005 |
| PAIR-08 | Oversized/malformed/arbitrary-host QR | Reject, no external request/secret log | U/I | 005/007 |
| AUTH-01 | A reads own household/device | Allowed minimum fields only | I | 004/006 |
| AUTH-02 | A uses every verb/RPC/join against B | Zero unauthorized access/control; no role/household self-edit | I/F | 004 |
| AUTH-03 | DA targets DB, parent route or Auth exchange | Denied; no sibling/profile access | I | 004/007 |
| AUTH-04 | Anonymous/public-key-only/expired parent token | Denied | I | 004/006 |
| AUTH-05 | Membership removed while JWT still valid | Access denied immediately by authorization | I | 004/006 |
| AUTH-06 | Own safe profile update vs membership escalation | Only permitted fields change | I | 004/006 |
| AUTH-07 | New verified parent completes sign-up twice/retries household creation | Exactly one account/sole-owner household; retry returns the same outcome | I/F | 006 |
| AUTH-08 | Parent logs out, uses recovery, or restarts after logout | Parent tokens/cache are cleared or safely replaced; child identity/policy is unaffected | I/F | 006 |

## Commands and synchronization

| ID | Given / when | Then / observable pass criterion | Level | Issue |
| --- | --- | --- | --- | --- |
| CMD-01 | Positive balance; LOCK accepted/delivered | Pending then persisted then observed block, no extra consumption while blocked | U/I/P | 009 |
| CMD-02 | Manual lock + positive / zero; UNLOCK | Clears manual only; zero stays expired | U/I/P | 001/009 |
| CMD-03 | Same-day +10 | Exactly 600 s allowance; local persist ≤1 s after validated snapshot receipt | U/I/P | 009 |
| CMD-04 | Same-day +30 | Exactly 1800 s; same persistence bound | U/I/P | 009 |
| CMD-05 | Duplicate request/push/snapshot/ack 100 times | No double grant, no rollback, original operation result | U/I/F | 009 |
| CMD-06 | Same ID with changed payload/target/actor | Conflict without leaked original data | I/F | 009 |
| CMD-07 | Stale UNLOCK after newer LOCK | Remains locked; stale result ignored/superseded | U/I/F | 009 |
| CMD-08 | Grant accepted yesterday, delivered today | No today's credit; expired_for_period | U/I | 009 |
| CMD-09 | Missed pushes then reconnect | Current snapshot discovered and applied, correct absolute bonus | I/P/F | 009 |
| CMD-10 | Limit reduced below consumption / raised later | No consumption reset; appropriate remaining time | U/I | 001/009 |
| CMD-11 | Crash after local persistence before adapter/ack | Resume restriction; resend receipt, never re-add grant | I/P/F | 008/009 |
| CMD-12 | Concurrent writers/sync pagination | One sequence; internally consistent snapshot; no version/data mix | I/F | 004/009 |
| CMD-13 | Unknown major/kind or future ack version | Reject/update required; retain last valid local policy | U/I | 009 |
| CMD-14 | Dispatcher crash after DB commit | Outbox recovers hint; command discoverable even if all pushes fail | I/F | 009 |
| CMD-15 | Stale report arrives after newer report | Latest state not overwritten; report_sequence/epoch enforced | I/F | 009 |

## Timer and lifecycle

| ID | Given / when | Then / observable pass criterion | Level | Issue |
| --- | --- | --- | --- | --- |
| TIME-01 | 60 s interactive/keyguard hidden/permitted | Counts 60 s once; physical accuracy target confirmed | U/I/P | 008 |
| TIME-02 | Screen off / ambient display | No eligible consumption | U/P | 008 |
| TIME-03 | Keyguard shown including swipe-only lock | No eligible consumption | U/P | 008 |
| TIME-04 | Remaining reaches zero offline | Observed safe restriction p95 ≤2 s, no network dependency | U/P/F | 003/008 |
| TIME-05 | Normal process kill, then restore | No lost durable policy/grant; uncovered suffix reconciled once | I/P/F | 008 |
| TIME-06 | App restart/resume repeatedly | Used/version monotonic, no new allowance | I/P | 008 |
| TIME-07 | Reboot online | New clock origin handled; policy/receipt recovery; unlock gap measured | P/F | 003/008 |
| TIME-08 | Reboot offline while expired/manual-locked | Restores downloaded restriction; no invented daily credit; degraded clock | P/F | 003/008 |
| TIME-09 | Wall clock +24h mid-use | Monotonic use unchanged; no extra reset | U/P/F | 008 |
| TIME-10 | Wall clock −24h mid-use | No negative used or duplicated day | U/P/F | 008 |
| TIME-11 | Device timezone crosses date line | Household period unchanged | U/P | 008 |
| TIME-12 | DST forward/back and midnight during use | One allowance/date; interval split; bonus clears/manual lock persists | U/I/P | 001/008 |
| TIME-13 | Deep sleep then wake | No sleep charge; current state reconciles | U/P | 008 |
| TIME-14 | App update/migration with pending receipt | All durable state preserved; failure does not reset budget | I/P/F | 008 |
| TIME-15 | Missing/truncated/contradictory UsageEvents | Uncertain/degraded, approved conservative recovery, no fabricated precision | U/I/P/F | 008 |
| TIME-16 | Multi-window/PiP/launcher/video | Total counted once; safe enforcement across surfaces | P | 003/008 |
| TIME-17 | Duplicate event ranges at checkpoint seam | No double count or lost interval | U/I | 008 |
| TIME-18 | Storage write fails / corrupt record | Explicit degraded state; no acknowledgement of unpersisted policy | I/P/F | 008 |
| TIME-19 | Zero and ADD_TIME race | Reducer serializes, one correct result and observed adapter state | U/I/P | 008/009 |

## Network, permissions and tamper

| ID | Given / when | Then / observable pass criterion | Level | Issue |
| --- | --- | --- | --- | --- |
| NET-01 | Disconnect before expiry | Existing policy expires locally | P/F | 008/009 |
| NET-02 | Disconnect during command/ack | Idempotent retry, honest pending UI | I/P/F | 009/010 |
| NET-03 | Backend unavailable/5xx | Local timer unaffected; bounded backoff | I/P/F | 009 |
| NET-04 | Reconnect after extended outage | Latest state/period reconciled; no yesterday credit | I/P | 009 |
| NET-05 | Push never arrives/callback absent | Resume/restart/reconnect/best-effort work discovers state | I/P/F | 009 |
| NET-06 | Provider invalid address / fid-token compatibility | Registration repair with verified current API; no duplicate identities | I/P | 009 |
| PERM-01 | Usage Access revoked mid-use | Permission required; uncertain accounting surfaced | P | 003/008 |
| PERM-02 | Accessibility disabled | Degraded, no false applied enforcement | P | 003 |
| PERM-03 | Setup incomplete / consent refused | Remain setup state; refusal path works without coercion | P | 003/007 |
| TAMP-01 | Force-stop | No guarantee claimed; stale UI and user-driven recovery documented | P | 003 |
| TAMP-02 | Uninstall attempt/success | Honest limit and removal flow; no hidden reinstall | P | 003 |
| TAMP-03 | Data clear | Unpaired; no reused identity/old bonus | P | 003/007 |
| TAMP-04 | Safe mode | Lack of consumer enforcement documented; no bypass circumvention | P | 003 |
| TAMP-05 | Guest/secondary user | No device-wide coverage claim; enrolled-user scope shown | P | 003 |
| TAMP-06 | Battery optimization/OEM restricted mode | Measure recovery/degradation, qualify supported configuration | P | 003 |
| TAMP-07 | Developer options/ADB | Boundary documented; credentials/logs not accidentally exposed | P | 003/007 |
| TAMP-08 | Root/unlocked bootloader | Unsupported, no attestation-as-proof claim | P/research | 003 |
| SAFE-01 | Block while dialler/emergency/TalkBack/IME/system permission dialog needed | Safe access/recovery confirmed; any unsafe trapping blocks launch | P | 003 |
| SAFE-02 | Parent locked child offline; local help/removal | Approved recovery route reachable without content access | P | 003/010 |

## Backend, privacy and UI

| ID | Given / when | Then / observable pass criterion | Level | Issue |
| --- | --- | --- | --- | --- |
| DB-01 | Correct tenant SELECT/RPC under real client role | Expected allowed operations succeed | I | 004 |
| DB-02 | Foreign/anon/direct private table access | All denied; RLS enabled, no accidental exposed view/helper | I | 004 |
| DB-03 | Quota exceeded concurrently | Atomic rate limit, 429 and bounded Retry-After; no extra control writes | I/F | 004/009 |
| DB-04 | Negative/overflow/fraction/unknown command | Rejected before mutation | U/I | 004/009 |
| DB-05 | Expired/stale/rotating credential, lost rotation response | No privilege gain; bounded recovery with policy retained | I/F | 007 |
| DB-06 | Revoked device then old credential used | No policy/control/state mutation; permitted removal response only | I/F | 007 |
| PRIV-01 | Inject sensitive strings into QR/API/provider errors | Tokens/content absent from logs and analytics | I | 005/009 |
| PRIV-02 | Backup/device transfer/restore | Device credentials/identity not cloned; explicit re-pair | I/P | 007 |
| PRIV-03 | Account/device deletion | Revoke first, live rows/push address purged per approved retention; offline limits visible | I/P | 006/007 |
| PRIV-04 | Inspect manifests, schemas, dependencies, logs and test traffic | No location, content, communications, media, keystroke, detailed app-history, advertising or surveillance data path exists | I | 002/004/007/009/010 |
| UI-01 | All required list/detail/pair/child states | Text+icon, timestamps, actionable error; accepted ≠ applied | U/I | 010 |
| UI-02 | Large fonts/TalkBack/contrast | No clipped controls; meaningful focus/labels; ≥48 dp target | I/P | 010 |
| UI-03 | Two intentional taps vs transport retry | Two grants vs one grant correctly distinguished | I/P | 009/010 |

## Evidence and physical device set

Known inventory: authorized Xiaomi Mi 8 / MIUI Global 12.0.3 / Android 10 API 29 with [bounded evidence](evidence/KR-003-MI8-2026-09-06.md), and
authorized Samsung SM-X400 / Android 16 API 36 / build `BP4A.251205.006` with [transport PASS and three calibration INVALID attempts](evidence/KR-003-SAMSUNG-TRANSPORT-CALIBRATION-2026-09-08.md).
The subsequent [runner-v2 calibration](evidence/KR-003-SAMSUNG-HOST-EXCEPTION-2026-09-08.md) separately passed permission verification and the
fixture positive control, then stopped INVALID in ARM before the blocked hold. The Samsung configuration establishes metadata, shell transport
and current permission-verifier compatibility only. The [runner-v3 invocation](evidence/KR-003-SAMSUNG-RUNNER-V3-STARTUP-2026-09-08.md) failed
inside PowerShell initialization before any device command. Four [runner-v4 attempts](evidence/KR-003-SAMSUNG-RUNNER-V4-HOST-EXCEPTIONS-2026-09-08.md)
then independently passed permission/positive controls and issued ARM, but the same host variable alias stopped each before attachment or blocked
hold; cleanup succeeded. Those attempts advance no device row. The fresh [runner-v5 calibration](evidence/KR-003-SAMSUNG-ORACLE-CALIBRATION-PASS-2026-09-08.md)
subsequently passed one excluded configuration-specific active-oracle sample: 127 ms attachment, 22,371 ms hold, 20 denied fixture taps, no focus
regain, explicit owner agreement and verified cleanup. This advances the Samsung calibration prerequisite only. Formal `TIME-04` remains open:
the first [qualification attempt](evidence/KR-003-SAMSUNG-QUALIFICATION-NETWORK-INVALID-2026-09-09.md) stopped `INVALID:ADB_REJECTED` during
mobile-data isolation after Wi-Fi disable/readback, before offline confirmation, ARM, checkpoints or cycle 1. There are zero qualification rows,
no offline result and no 100-sample p95. The subsequent [runner-v9 attempt](evidence/KR-003-SAMSUNG-QUALIFICATION-SCREEN-INVALID-2026-09-09.md)
did establish offline state and retain 100 automated active-oracle PASS rows (p50 221 ms, p95 317 ms, max 334 ms), plus checkpoints 1/2 PASS,
but it stopped `INVALID:SCREEN_OR_KEYGUARD` before a checkpoint-3 owner response. It remains one non-resumable INVALID: formal `TIME-04` does
not pass. Runner-v10 then retained a separate 100-row automated PASS set (p50 227 ms, p95 318 ms, max 341 ms), checkpoints 1/2 and final visibility
PASS, but stopped `FAIL:RESTRICTION_LOST` before a Home response after the overlay Settings control opened an allowed safe surface. Restriction
remained true, no Home action is established, and the run is neither poolable nor a Home escape result. Formal `TIME-04` still does not pass. The
two later [runner-v11 attempts](evidence/KR-003-SAMSUNG-QUALIFICATION-V11-ATTEMPTS-2026-09-09.md) each retained 100 automated PASS rows: RUN A
stopped INVALID during a final-visible candidate snapshot with unverified cleanup; RUN B retained final-visible PASS but no exercisable Home
control/action despite coarse `THREE_BUTTON` mode. Neither is resumable or poolable, neither establishes Home resistance/escape, and neither
advances a formal row. OD-39 now prospectively approves either an exercised physical Home action or owner-confirmed control unavailability plus
a separately fixture-calibrated host Home stimulus and independent no-escape evidence. This does not alter either run. The combined earlier eligibility signal does not
separately pass `TIME-02` or `TIME-03`. Permission-revocation, broader safety, lifecycle and production
gates do not advance.
Proposed minimum: one current Google reference device, one Samsung phone/tablet,
one target tablet/OEM with restrictive battery behaviour, oldest approved API and current supported OS.
Android 17/API 37 is the current documented platform; whether to add it to the approved physical support gate remains **UNSPECIFIED** and it does
not replace any existing API row. Device availability/selected support version must be verified, not assumed.
Emulators support deterministic/API tests but cannot certify OEM killing, safe mode, emergency handling, battery or push delivery.
No destructive wipe/root/bootloader tests on a personal device without its owner's authorization.
Each evidence set maps only to the exact rows its read metadata establishes. Mi 8 evidence is not Samsung evidence; Samsung evidence is not Pixel,
another OEM, another API/build or another battery/permission configuration.
