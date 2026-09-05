# MVP product specification

- **Goal:** Test a minimal Android parental screen-time product with local expiry and understandable remote controls.
- **Context:** Parent Android app and native child Android agent; KidRemote is a working codename.
- **Constraints:** Data minimization, offline execution, explicit owner decisions, no production features in this pass.
- **Done when:** KR-001 approves semantics and every MVP behaviour has an observable acceptance test.

## Product contract

A parent signs up, signs in, sees enrolled devices, pairs through QR, sets a daily total allowance, and issues Lock, Unlock, +10 min, or +30 min.
A child receives an independent device identity, measures total permitted interactive use, persists policy/accounting, expires locally, and acknowledges applied state.

Remote delivery and offline execution are different: a disconnected child follows the latest rule it has received.
A newly accepted server command remains pending until the child can authenticate and sync.
The server is authoritative for authorization, ordering, policy, and grants; the child is authoritative for locally observed use.
A displayed remaining value is a timestamped report, never proof of current offline enforcement.

## Flows and acceptance

| Flow | Observable result |
| --- | --- |
| Create account | Account verification and error/retry states are explicit; household creation is idempotent; no child is enrolled implicitly |
| Login / logout | Parent can sign in and out; parent session never enters QR or child storage; logout clears local sensitive cache; child policy continues |
| Empty list | MY DEVICES explains no devices and offers Pair a device |
| Pair | Authenticated parent generates QR, child consents/scans, single-use redemption produces scoped identity; expired/replayed/failed states are clear |
| Setup | Child sees separate Usage Access and enforcement consent/setup, plus live health; pairing success is distinct from enforcement readiness |
| Daily limit | Parent explicitly chooses initial limit before enforcement is activated; no invented default allowance |
| View devices | Nickname, optional model, last reported time/lock reason, freshness and health are visible |
| Control | One tap submits a unique operation; accepted, pending and acknowledged outcomes are distinct; retry reuses the same ID |
| Expiry | Under supported healthy conditions, zero causes local restriction p95 ≤ 2 s; Internet is not required |
| Reconnect | Missed push or command produces the same latest state as an uninterrupted sync; bonus never applies twice |
| Removal | Parent can revoke/remove a device; account deletion and offline removal limitations are explained in SECURITY and PRIVACY |

Recommended parent authentication method: verified email and password with password recovery, avoiding SMS cost and extra social providers.
Actual method: **UNSPECIFIED**; owner approval required. MFA/recovery escalation requirements: **UNSPECIFIED**.
Supabase documents supported authentication methods; SMTP configuration and delivery testing remain implementation work.
[Supabase Auth](https://supabase.com/docs/guides/auth).

## Proposed semantics — owner approval required

Actual screen-time definition, Unlock semantics and day rule: **UNSPECIFIED**.
Recommend the following, specified completely in [STATE-MACHINE](product-specs/STATE-MACHINE.md) and [ADR-0005](adr/0005-state-and-time.md):

- Screen time is time when the enrolled Android user's screen is interactive and keyguard is not showing, while KidRemote permits use. Launcher and multi-window count once; screen-off audio does not. KidRemote's effective blocked screen does not consume allowance.
- Each enrolled device has an independent daily allowance. A household-wide pooled budget is out of scope.
- Remaining = max(0, daily allowance + today's bonus − used time).
- Manual lock and time-expired lock are independent reasons. Effective policy block = manual lock OR remaining ≤ 0.
- Unlock clears only manual lock. Zero still requires +10 or +30. Adding time never clears manual lock.
- Daily reset clears used time and that day's bonus; manual lock survives; no carry-over.
- Daily limit changes take effect when received, retaining consumed time and today's bonus. They also become the recurring limit.
- ADD_TIME is for the explicitly named current household day, not “whenever delivered.” A late grant is expired, not applied to tomorrow.
- Parent confirms a household IANA timezone; the device timezone does not change the budget day. Day starts at local midnight in that zone, including 23/25-hour DST days.
- Offline, same-boot daily resets use the downloaded rule and a trusted server-time/monotonic anchor. After an offline reboot, preserve current-period balance and withhold a new daily allowance until time is trusted again. This anti-tamper/usability trade-off requires owner approval.
- A missing/unreconcilable usage interval marks degraded health and conservatively restricts ordinary use, with safe recovery routes. Approval required; this is separate from the two policy lock reasons.

A consumer app cannot promise persistence of enforcement after force-stop, uninstall, safe mode, or compromise.
If that guarantee is mandatory, a managed-device product must be considered explicitly.
[Android package stopped state](https://developer.android.com/about/versions/15/behavior-changes-all).

## Required UI states

Parent list/detail: loading; empty; online; stale/offline; server-accepted pending command; applied; manually locked; expired; permission required; enforcement degraded; app update required; backend error.
Child: onboarding/pairing; permission setup; enrolled/healthy; time expired; parent lock; degraded; revoked/re-enrol.
Status carries text and icon; online and health are separate dimensions. Unknown last-seen never renders Online.
A request to Lock is “Lock requested” until enforcement acknowledgement. If both lock reasons exist, show both.
At zero, helper text says “Add time to allow use”; do not imply Unlock replenishes time.

Recommend no -10/-30 primary actions: unclear accidental subtraction and more controls for no specified use case.
Daily limit editing handles future recurring limits. Negative bonus operations are out of scope.
Light mode first; dark mode: **UNSPECIFIED**, recommend defer to preserve feasibility focus.

## Safety and consent

The parent-app role is for an authorized parent/guardian; age verification and jurisdiction-specific consent: **UNSPECIFIED**.
Enrollment is visible on the child; no stealth mode or concealed icon.
Never prevent emergency communication or accessibility needed to operate the device.
Exact allowed system surfaces and parent recovery flow: **UNSPECIFIED**; KR-003 must prove a safe supported set before launch.
QR camera access is user-initiated scanning only: no monitoring, retention, upload, background capture, or photo permission.

## Out of scope

GPS/location; geofencing; browsing history; URLs/web activity; VPN/web filtering; calls; SMS; social media; contacts; media/photo scanning;
microphone or camera monitoring; screenshots/recording; typed text; content inspection; AI monitoring; uploaded detailed app history;
ads; per-app limits; bedtime/schedules; rewards/chores; subscriptions/payments; iOS, Fire OS and Windows implementation.
Do not add analytics SDKs merely for convenience. OpenAI is a development aid, not part of the product runtime.

## Delivery gates

1. **Architecture & Feasibility:** product decisions recorded; Android enforcement and Play assessments complete; physical spike evidence defines viable support boundary; backend/RLS and pairing threat models reviewed.
2. **Android Alpha:** internal/test-device vertical slice, RLS negative tests, pairing race tests, reboot/offline tests, recovery routes. Not store launch.
3. **Android MVP:** all required functional/security/device/capacity tests pass; audience/data/retention/store declarations and deletion verified; owner approves residual risks.

Every unchosen item is in [DECISIONS](DECISIONS.md). See [test matrix](test-plans/MATRIX.md) for test IDs and objective observations.
