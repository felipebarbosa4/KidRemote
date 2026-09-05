# Capacity and performance validation

- **Goal:** Support the stated six-month scale without speculative infrastructure.
- **Context:** Meaning of business “user” and hosting budget are **UNSPECIFIED**.
- **Constraints:** One PostgreSQL/Supabase system; production tier selected only after measurement.
- **Done when:** KR-004/009/010 evidence meets target metrics with no cross-tenant or duplicate failures.

## LOAD-TEST ASSUMPTION

1,000 active parent accounts × maximum planning assumption 5 enrolled child devices/account = 5,000 devices.
This is a synthetic upper-bound model, not a forecast or an approved product device cap.

Proposed stress traffic:
- 5,000 simultaneously active devices reporting/syncing every 60 s → ~83.3 requests/s.
- 1,000 simultaneously visible parent lists polling every 15 s → ~66.7 reads/s.
- 10 control writes/s plus 10 acknowledgements/s; occasional enrollment/revocation and jittered recovery → plan ~180 requests/s mixed steady load.
- 5,000 reconnects spread across 60 s → ~83.3 extra syncs/s; also test an unjittered burst to verify limiting.
- 24 hours at 83.3 device reports/s would be ~7.2 million daily reports; this is an intentionally severe active-use assumption and may be too expensive.
Measure realistic duty cycles before budgeting; do not turn the stress pattern into always-on production polling.

## Targets and measurement boundaries

| Target | Start / finish and conditions |
| --- | --- |
| Local expiry p95 ≤2 s | Measured eligible budget zero → observed usable restriction on each supported physical configuration |
| Local received grant persist ≤1 s | Complete validated sync response containing grant → durable transaction completion on supported device |
| Authenticated command write p95 ≤500 ms | Request arrival at backend → committed acceptance response under synthetic load, auth included; report cold/warm separately |
| Online command reflection aspirational p95 ≤5 s | Parent submit → child application/receipt under normal connectivity; not a hard push-delivery guarantee |
| Warm parent list ≤1.5 s | Tap/open warm list → useful populated render, defined regional network/device; record max and p95 |
| Duplicate double-apply zero | Replay accepted ID/push/snapshot/ack 100×; grant/bonus unchanged |
| Tenant authorization failure zero tolerated | Attack fixture suite alongside load; any foreign success fails release |
| Offline downloaded expiry | Disable Internet/backend before zero; same local behaviour |

Target geography/network profile, device inventory and exact latency-error budget definitions beyond these bounds are **UNSPECIFIED**.
Specify them in each evidence run. Do not claim a percentile without sample count.

## Execution

Seed synthetic tenants locally/staging with indexed membership/device/version and grant-period queries.
Use a chosen load tool (version **UNSPECIFIED**), 10-minute warmup, 30-minute mixed steady run, reconnect burst,
2-hour soak and targeted cold-function runs. Owner-authorized non-production environment only.
Collect server p50/p95/p99, errors, auth/DB/Edge timings, query plans, DB CPU/connections/locks,
outbox age, retries, response bytes, client render and battery metrics. Never log tokens or high-cardinality family labels.

RLS queries include realistic auth claims and indexes; testing as service role alone is invalid.
Exercise hot-device contention (two parents/intents), stale grants, malformed inputs, provider 429/5xx, backend outage and ack loss.
Inspect membership/device/version/period indexes and bounded query pages before considering more infrastructure.

## Scaling actions and operational budget

First reduce polling/write amplification, coalesce latest-state reports, batch sync/ack, index queries and tune connection usage.
Scale the single managed database/Edge capacity if measured load requires it; no queue platform or extra DB is justified now.
Current provider pricing/region/storage/egress budget is **UNSPECIFIED**; no free-tier sufficiency claim.
Retention pruning must preserve idempotency tombstones and latest state while avoiding a growing raw heartbeat history.
Performance evidence and capacity decision belong in a follow-up ADR if the simple baseline fails.
