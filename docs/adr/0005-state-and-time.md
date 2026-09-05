# ADR-0005 — Allowance semantics and time basis

Status: Proposed; product choices **UNSPECIFIED**; OD-01–05/19 owner approval required.

- **Goal:** Match understandable daily total time with minimal data.
- **Context:** Parent Unlock, time grants, offline expiry/reset and local usage recovery.
- **Constraints:** Monotonic consumption, no uploaded app history, no hidden carry-over or cloud clock.
- **Done when:** KR-001 approves STATE-MACHINE and KR-008 validates domain and Android timing evidence.

## Alternatives evaluated

| Choice | Pros | Limitations |
| --- | --- | --- |
| Interactive + keyguard hidden time | Includes launcher/video/multi-window once; no app history required | Counts idle screen left on; essential surface exclusions need explicit decisions |
| Foreground app/use aggregation | Closer to app-focused usage reports | Package data, multi-window/double counting, transitions/retention gaps; unnecessary for total allowance |
| Screen-on only | Very simple signal set | Counts keyguard/ambient time against normal expectations |
| Self-reported app timer / server timer | Simple demo | Cannot measure device use or enforce existing rule while offline |

Recommend interactive + keyguard hidden while use is permitted; sample current PowerManager/KeyguardManager state and reconcile using UsageEvents.
Screen/keyguard events exist from API 28; UsageStats queries require Usage Access and do not enforce.
[Usage events](https://developer.android.com/reference/android/app/usage/UsageEvents.Event),
[UsageStatsManager](https://developer.android.com/reference/android/app/usage/UsageStatsManager).

Evaluate Unlock that adds temporary grace or disables expiration: one button may feel convenient but silently changes allowance.
Recommend independent manual lock and budget, explicit +10/+30 grants, manual lock surviving midnight.
Evaluate device-local timezone vs household fixed timezone: device travel is intuitive but gives easy reset manipulation.
Recommend parent-confirmed household zone and no timezone-edit feature in MVP.

## Decision and reasons

Use the exact transition contract in [STATE-MACHINE](../product-specs/STATE-MACHINE.md).
Consumption uses elapsedRealtime differences only within a boot, gated by interactive/unlocked/permitted intervals.
Use trusted server UTC + monotonic anchor for day progression within a boot; propose conservative offline-reboot handling.
SystemClock documents elapsedRealtime including deep sleep and resetting at boot, so a durable boot boundary is necessary.
[SystemClock](https://developer.android.com/reference/android/os/SystemClock).

## Security/privacy implications

No persisted per-app timelines. Keep local aggregates and tiny reconciliation cursors.
Clock edits must not mint bonus or reset a day twice. A consumer app cannot establish true calendar time after arbitrary offline reboot and RTC tampering.
Conservative missing-accounting restrictions may be frustrating and must preserve emergency/recovery surfaces.

## Operational implications

Room transactions hold state, version and receipts together; DataStore suits small preferences but not the relational accounting/receipt ledger.
[Room](https://developer.android.com/training/data-storage/room),
[DataStore](https://developer.android.com/topic/libraries/architecture/datastore).
Per-second active checkpoints are a proposed spike baseline, subject to measured battery/write cost; no indefinite wakelock.
Keep current and previous day's aggregate plus bounded receipt/cursor metadata; purge unnecessary intervals.

## Risks and invalidation tests

Parents may expect idle unlocked time not to count; validate with a small owner/usability review.
Tests: screen off/keyguard, split-screen/PiP, process loss, update/reboot, ±24h clock edits, DST and timezone changes,
zero/add race, duplicate snapshot, yesterday's grant and unreconcilable event history.
Invalidate if required accuracy needs retained/uploaded package history, if recovery can silently restore spent allowance,
or if offline-reboot restriction trade-off is rejected by owner.
