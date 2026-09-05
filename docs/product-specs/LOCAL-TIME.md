# Android persistent local time engine

- **Goal:** Measure total permitted screen use locally and enforce expiry without backend connectivity.
- **Context:** Provisional state semantics, ADR-0002/0005; native child; no implementation exists yet.
- **Constraints:** No wall-clock-only accounting, exact WorkManager countdown, app-history upload, or process immortality assumption.
- **Done when:** KR-008 passes deterministic fixtures and physical restart/reboot/offline tests within an approved support envelope.

## Signals and state

Current state comes from PowerManager.isInteractive() and KeyguardManager.isKeyguardLocked().
The latter concerns keyguard presentation, not whether credential-encrypted storage has been unlocked since boot.
Register screen/user-present signals while the connected service is alive, and resample to avoid relying solely on broadcasts.
[PowerManager](https://developer.android.com/reference/android/os/PowerManager),
[KeyguardManager](https://developer.android.com/reference/android/app/KeyguardManager).

UsageStatsManager.queryEvents is reconciliation, not a timer callback or blocking API.
Use SCREEN_INTERACTIVE/NON_INTERACTIVE and KEYGUARD_SHOWN/HIDDEN events, available from API 28.
Prefer event-type-filtered queries where the selected platform supports them; older fallback discards all other fields/events immediately.
System history is retained only a few days and timestamps are wall-clock based; it cannot be assumed complete, timely or tamper-proof.
Starting Android R, queries can return null before the Android user is unlocked since boot.
[UsageStatsManager](https://developer.android.com/reference/android/app/usage/UsageStatsManager),
[UsageEvents](https://developer.android.com/reference/android/app/usage/UsageEvents.Event).

Room persists one serialized engine record plus current/previous day aggregates, receipts and bounded reconciliation metadata.
Record policy_epoch/version, period_key, recurring allowance, absolute dated bonus, manual lock,
used_ms, last monotonic checkpoint, boot marker, last observed interactive/keyguard/enforcement states,
trusted UTC anchor, timezone/revision, reconciliation coverage and report_sequence.
Use a documented boot count/boot signal with monotonic regression detection; exact selected API and OEM reliability **UNSPECIFIED** pending spike.
Do not subtract elapsedRealtime values across boots.

## Live algorithm proposal

1. A single serialized reducer consumes screen/keyguard, sync, expiry, reset and health events.
2. Before changing state, settle the previous eligible interval using elapsedRealtime now − previous anchor.
3. Eligible = interactive AND keyguard hidden AND use permitted AND accounting known.
4. Persist transitions immediately; propose checkpoint each second while actively counting, subject to battery tests.
5. Schedule a near-term callback for remaining time while the service is connected. Each callback recomputes from the monotonic clock;
   ticks are not the accounting unit. Never assume callback dispatch at an exact time.
6. At zero persist desired restriction and call the enforcement adapter immediately, then persist observed application/health.
7. On screen off or keyguard show, close interval and cancel active countdown callbacks; no wake lock to count sleeping time.
8. On screen return/service reconnect, reconcile before allowing ordinary use and derive expiry from persistent state.

elapsedRealtime includes deep sleep, so blindly charging its entire delta would be wrong; eligibility intervals must gate it.
[SystemClock](https://developer.android.com/reference/android/os/SystemClock).
Room transactions are recommended for the coupled ledger/version/receipts; exact persistence library/version remains **UNSPECIFIED** until adoption.
[Room](https://developer.android.com/training/data-storage/room).

## Crash and reconciliation algorithm

At recovery, read durable checkpoint and detect same/new boot before integrating.
For a same-boot gap, query bounded screen/keyguard events from the last coverage cursor through current observation.
Reconstruct only the uncovered suffix; never sum full UsageStats totals on top of already measured local intervals.
Validate event order, bounds, predecessor state and clock mapping. Split at recorded clock-change anchors; uncertain wall-clock gaps are not silently converted to precise monotonic consumption.
At the coverage seam, deterministic interval merging consumes each millisecond at most once.
Use local aggregate/checkpoint as truth; repeated query ranges are harmless because the coverage cursor only advances atomically.
If signal coverage is missing/contradictory, retain known used time and mark accounting uncertain.
Proposed conservative restriction until reconciliation or authorized recovery requires OD-05; never award an unknown interval as free time.
Crash between persistence and adapter application resumes from persisted required restriction.
Crash after adapter application but before acknowledgement re-observes state and resends receipt; no command replay increments.

## Lifecycle and clock matrix

| Event | Required behaviour / test |
| --- | --- |
| Normal process death | Restore state, reconcile uncovered interval, resume adapter; no reset of used/version/bonus |
| Application restart/resume | Same algorithm; sync missed commands after local recovery, no backend dependency for existing block |
| Application update | Versioned Room migration retains policy/credential/cursors; rollback incompatible migration fails visibly, never reset as convenience |
| Reboot | Detect new monotonic origin; retain known state and pending ack; recover after first unlock; test exposed window |
| Reboot offline | Existing expired/manual block restored when service can run; preserve current balance; no untrusted new-day credit under proposed rule |
| Before first unlock | OS keyguard governs device; no claim of UsageStats availability or complete KidRemote enforcement |
| Deep sleep | No eligible-use charge during sleep; at wake reconcile boundary and reset day if trusted mapping permits |
| Screen off / keyguard | Stop eligible interval; ambient display and lock screen do not consume allowance |
| Wall clock forward/back | Same boot uses server/monotonic projection for day; no negative time or new allowance from RTC edits |
| Timezone change | Device-zone change does not change confirmed household policy zone |
| Midnight / DST | Split eligible interval at true zone midnight; one period per local date; 23/25-hour day gets one allowance |
| Offline midnight same boot | Downloaded recurring policy resets locally; bonus clears; manual lock persists |
| Missed/duplicate sync | Consumption continues; absolute bonus and version guard ensure idempotent merge |
| Credentials expired/revoked | Expiry does not erase local budget; authenticated revocation/removal follows lifecycle contract |
| Data clear/reinstall | Identity/ledger absent → unpaired; no enforcement guarantee; old cloud device becomes stale and must be revoked |

Direct Boot distinguishes device-encrypted from credential-encrypted storage.
Recommend no device secrets in device-encrypted storage; if spike proves a pre-unlock policy marker necessary, store only minimal non-secret flags,
make the component explicitly direct-boot-aware and test stale mirrored-state handling. This is not a guarantee that the service will run.
[Direct Boot](https://developer.android.com/privacy-and-security/direct-boot).

## Background execution and health

Candidate runtime is the system-bound AccessibilityService, not a continuously started ordinary background service.
Reconciliation and FCM sync use WorkManager as best-effort recoverable work; minimum periodic interval is 15 minutes and execution may be delayed.
Boot receiver is a short scheduling/recovery hook, not a long-running timer.
Use a separate foreground service only if the spike proves need and the documented type, notification and Play requirements are satisfied.
[Work requests](https://developer.android.com/develop/background-work/background-tasks/persistent/getting-started/define-work),
[bound/background limits](https://developer.android.com/about/versions/oreo/background),
[FGS constraints](https://developer.android.com/develop/background-work/services/fgs/restrictions-bg-start).

Force-stop is different from normal process death. Current Android stopped-package behaviour requires user interaction to recover;
pending intents can be cancelled. Reboot/push are not promised escape mechanisms.
[Android stopped state](https://developer.android.com/about/versions/15/behavior-changes-all).

## Minimum retained data and physical evidence

No per-package usage history saved; transient signals are reduced to total durations and coverage cursors.
Propose current and previous aggregate day locally; unresolved technical gap metadata purged after resolution or a 48-hour cap, then mark uncertainty rather than accumulating logs.
Persist command high-water version and active identity tombstones; old payload histories need not stay on child.
Measure p95 expiry transition, grant persistence latency, recovery overcount/undercount and battery/write cost.
Actual tolerable recovered-accounting error and battery threshold: **UNSPECIFIED**; propose ≤2 s error for ordinary same-boot recoverable gaps,
and require owner-approved conservative behaviour when exact recovery is impossible.
