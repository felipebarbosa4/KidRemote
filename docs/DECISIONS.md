# Decision and unknown register

- **Goal:** Prevent recommendations from becoming undocumented product assumptions.
- **Context:** Initial architecture accepted and execution started 2026-09-05.
- **Constraints:** Unchosen or externally unverified facts remain **UNSPECIFIED**. Owner approval is not implementation or test evidence.
- **Done when:** Each gate has an owner outcome and linked ADR/test evidence before dependent production work.

Owner directive: repository owner `felipebarbosa4`, 2026-09-05 — adopt the documented recommendations and proceed without waiting for further choice.
This approves concrete recommended product/architecture choices. It does not fabricate Play approval, device results, legal facts, credentials,
budgets, package names or provider configuration; those remain **UNSPECIFIED** until actually resolved.

| ID | Actual decision / fact | Recommendation or required resolution | Gate |
| --- | --- | --- | --- |
| OD-01 | **APPROVED 2026-09-05:** Unlock clears only manual lock; manual lock survives midnight; +time does not unlock | Implement/test ADR-0005 exactly | KR-001 |
| OD-02 | **APPROVED 2026-09-05:** count interactive + keyguard-hidden + permitted-use time independently per device | Keep event reduction local; KR-003 validates exemptions/safe surfaces | KR-001/003 |
| OD-03 | **APPROVED 2026-09-05:** confirmed household IANA zone, local midnight, no bonus carry-over | Device timezone never changes the period | KR-001 |
| OD-04 | **APPROVED 2026-09-05:** retain current balance and defer new-day credit after offline reboot until trusted time | Show degraded clock state; validate on device | KR-001/003 |
| OD-05 | **APPROVED 2026-09-05:** unreconcilable accounting restricts ordinary use | Emergency/accessibility/recovery must remain available and be proven in KR-003 | KR-001/003 |
| OD-06 | **APPROVED FOR FEASIBILITY 2026-09-05:** evaluate the consumer Accessibility candidate | Production acceptance and Play approval remain **UNSPECIFIED** pending KR-003 evidence | KR-003 |
| OD-07 | **APPROVED SAFETY GATE 2026-09-05:** validate dialler/emergency/system accessibility and visible recovery; no fake OS lock | Exact supported surfaces remain **UNSPECIFIED** until physical validation | KR-003 |
| OD-08 | **APPROVED 2026-09-05:** native Kotlin/Compose parent and native Kotlin child | Exact toolchain versions are selected only when verified for bootstrap; ADR-0001 | KR-002/bootstrap |
| OD-09 | **APPROVED 2026-09-05:** independent opaque device bearer, digest server-side, dedicated Edge routes only | Threat model and negative tests remain mandatory; ADR-0003 | KR-005/007 |
| OD-10 | **APPROVED 2026-09-05:** five-minute, single-use pairing token with atomic redemption | Post-commit response loss requires revoke/new QR | KR-005 |
| OD-11 | **APPROVED FOR ALPHA 2026-09-05:** verified email/password plus recovery | Production MFA/recovery escalation remains **UNSPECIFIED** pending security review | KR-006 |
| OD-12 | **APPROVED 2026-09-05:** one creating owner and one household per parent in MVP | Keep normalized membership for later invitations | KR-001/006 |
| OD-13 | Independent parent/child listing classification is approved as a release gate | Exact ages, markets and Play target audiences remain **UNSPECIFIED** | Release |
| OD-14 | Proposed live-data retention minima in PRIVACY are approved as the alpha technical baseline | Region, legal basis, processors/contracts and backup purge duration remain **UNSPECIFIED** | Alpha with real data |
| OD-15 | **APPROVED FOR SPIKE 2026-09-05:** candidate minimum API 28 | Target/compile SDK and supported OEM list remain **UNSPECIFIED** until current tooling/device evidence is recorded | KR-002/003 |
| OD-16 | LOAD-TEST ASSUMPTION approved: 1,000 active parents and up to 5,000 enrolled devices | Business meaning of user, forecast, hosting budget/tier remain **UNSPECIFIED** | Capacity/provisioning |
| OD-17 | Final brand, package IDs, domains: **UNSPECIFIED** | KidRemote remains codename; do not buy or publish names | Distribution |
| OD-18 | **APPROVED 2026-09-05:** light-mode MVP; dark mode deferred | Revisit after Android MVP, not in KR-010 scope | KR-010 |
| OD-19 | **APPROVED 2026-09-05:** no default; parent explicitly sets 0–86,400 s; total daily allowance capped at 86,400 s; reject excess | Use checked integer seconds and visible errors | KR-001 |
| OD-20 | **APPROVED 2026-09-05:** 90-day device credential; rotate by day 30 with five-minute overlap; downloaded policy survives expiry; revocation applies on next contact | Validate lost-response, long-offline and visible local removal paths | KR-005/007 |
| OD-21 | **STARTED 2026-09-05:** Sprint 01 ends 2026-09-11; single-agent committed scope KR-001/002/003 | Physical-device inventory remains **UNSPECIFIED**; KR-003 blocks if unavailable | Sprint 01 |
| OD-22 | Planning CI baseline approved by merged PR #11 | Licence, branch rules, deployment secret owners and outside-contribution policy remain **UNSPECIFIED** | Repository/release |
| OD-23 | Future Apple remote capabilities: **UNSPECIFIED** | RESEARCH REQUIRED; entitlement is external dependency; no promise of Android parity | Apple Feasibility |
| OD-24 | Windows privilege/enforcement and Fire model support: **UNSPECIFIED** | Future-only research; ADR-0007 | Future milestones |
| OD-25 | Play review, FCM migration compatibility, physical metrics: **UNSPECIFIED** | Run KR-003/009 and measured tests; documentation alone cannot confirm | Alpha/release |
| OD-26 | **SPIKE DECISION 2026-09-06:** Q4 physically rejects `NEW_TASK | CLEAR_TOP`; test `NEW_TASK | CLEAR_TASK` once as the final flag-only recovery candidate | Q5 must pass the exact failed route; failure returns consumer recovery to architecture/go-no-go review | KR-003 |
| OD-27 | **SPIKE EVIDENCE 2026-09-06:** Q5 passed the exact focused Mi 8 recovery route with `NEW_TASK | CLEAR_TASK` | Permit a new immutable 100-sample qualification bundle using the exact candidate APK; do not infer broader safety, support or Play acceptance | KR-003 |
| OD-28 | **QUALIFICATION CONTRACT 2026-09-06:** Q6 uses the exact Q5 APK pair, mandatory reversible offline mode, fresh calibration, two safety checkpoints and 100 new physical expiry observations | Execute once owner-side; failure/invalid stops with no replacement/resume/pooling; Q6 cannot close other KR-003 gates | KR-003 |
| OD-29 | **OWNER OPERATING CONSTRAINT / REVISED EVIDENCE CONTRACT 2026-09-06:** do not execute Q6; Q7 may use 100 independently active fixture-oracle cycles with at most three human checkpoint sessions | Q7 must physically calibrate real input delivery/denial before sample 1; report 100 automated cycles + three checkpoints, never 100 physical passes; if calibration fails, stop for go/no-go/scope decision | KR-003 |
| OD-30 | **OWNER-AUTHORIZED TRANSPORT EXPERIMENT 2026-09-06:** after Mi 8 shell input denial, test one coordinate touch through separate self-targeted UiAutomation instrumentation with unchanged developer settings | Fixture counter remains the independent oracle; physical success and candidate-service non-interference are **UNSPECIFIED**; evaluate bounded Monkey only if this fails; no Q7 rerun or KR-004 | KR-003 |
| OD-31 | **OWNER-AUTHORIZED NEXT-DEVICE PATH 2026-09-08:** prepare a generic transport-first evaluation for an expected authorized Samsung tablet; exact model/Android/API/build/power state remain **UNSPECIFIED** until sanitized discovery | Install only the independent fixture first; stop after one counter-correlated shell tap. Candidate installation requires transport PASS and a separate bounded oracle calibration; no Mi 8/Samsung/other-OEM evidence transfer | KR-003 |
| OD-32 | **CURRENT PLATFORM FACT 2026-09-08:** Android 17 is API 37; current mobile Play submission floor remains API 36+ from 2026-08-31 | Existing KR-003 API 28/35/36 gates remain; whether API 37 is added to the supported-device gate and the production compile/target migration are **UNSPECIFIED** owner decisions | KR-003/release |
| OD-33 | **SPIKE EVIDENCE 2026-09-08:** shell-input transport passed on the exact Samsung SM-X400 / Android 16 API 36 / build `BP4A.251205.006` configuration; three subsequent calibration attempts stopped INVALID because runner Accessibility verification disagreed with healthy candidate/service telemetry | Preserve all INVALID runs; correct only version-compatible fail-closed verification, then permit one fresh calibration rerun. No 100 samples, enforcement support or cross-device transfer is inferred | KR-003 |
| OD-34 | **SPIKE EVIDENCE 2026-09-08:** the fresh Samsung runner-v2 calibration independently passed Usage Access, Accessibility, fresh heartbeat, healthy candidate and the fixture positive control, then stopped `INVALID:HOST_EXCEPTION` in the ARM stage before attachment/blocked-hold evidence | Preserve the INVALID and its completed controls; add only typed host-stage/exception/cleanup/finalization diagnostics, then permit one fresh calibration rerun. The discarded v2 exception class/cause is **UNSPECIFIED**; no enforcement failure or PASS is inferred | KR-003 |
| OD-35 | **SPIKE EVIDENCE 2026-09-08:** runner-v5 passed one bounded active-oracle calibration on `samsung` / `SM-X400` / Android 16 API 36 / build `BP4A.251205.006`: exact permission/health controls, fixture positive control, revision 23 attachment, 127 ms excluded latency, 22,371 ms blocked hold, 20 denied taps, no focus regain, explicit owner agreement and verified CLEAR | Permit preparation of one immutable configuration-bound offline 100-cycle bundle. The calibration contributes zero qualification rows and transfers no Mi 8/other-Samsung/Android guarantee; TIME-04 p95, lifecycle/tamper/safety, support boundary and Play approval remain open | KR-003 |
| OD-36 | **SPIKE EVIDENCE 2026-09-09:** the first Samsung qualification attempt stopped `INVALID:ADB_REJECTED` in mobile-data isolation after Wi-Fi disable/readback, before offline confirmation, ARM or cycle 1. Runner-v8 captured no per-operation exit/stderr and no telephony feature, so the exact rejected command and device-reported mobile capability remain **UNSPECIFIED**; the exact SM-X400 SKU is manufacturer-labelled Wi-Fi | Replace the global-setting-as-capability assumption with fail-closed Android Wi-Fi/telephony-data feature probes. Absent paths are `NOT_APPLICABLE`; present paths still require disable/readback/restoration. Preserve the INVALID, zero rows and unverified mobile setting; no enforcement or matrix result advances | KR-003 |
| OD-37 | **SPIKE EVIDENCE 2026-09-09:** runner-v9 completed 100 valid automated active-oracle cycles on the exact Samsung configuration (p95 317 ms), but checkpoint 3 stopped `INVALID:SCREEN_OR_KEYGUARD` after about five minutes awaiting the owner with no physical response retained. The combined eligibility signal does not distinguish display-off from keyguard | Preserve the entire run as one non-resumable INVALID. Runner-v10 may temporarily use Android Stay awake while plugged in after confirming initial eligibility and external power; retain only coarse power/setting state, verify throughout, restore exact original state, and fail closed. This is lab orchestration only and changes no enforcement or lock-security semantics | KR-003 |

Exact Kotlin, Compose, Room, Gradle, AGP, Java toolchain, Android SDK, Flutter, Supabase CLI/client, Deno/Edge runtime and FCM SDK versions: **UNSPECIFIED**.
No app/bootstrap dependency versions are chosen in this pass. The verified Actions checkout pin is documented in TOOLING.

## Blockers and work that can proceed

**2026-09-09 KR-003 device status:** [shell input, UiAutomation and bounded Monkey were all denied on the Mi 8](test-plans/evidence/KR-003-MONKEY-DENIAL-2026-09-07.md), so OD-29's independent input prerequisite remains unmet there. On the exact Samsung configuration, transport and the bounded runner-v5 calibration passed. The first [qualification attempt](test-plans/evidence/KR-003-SAMSUNG-QUALIFICATION-NETWORK-INVALID-2026-09-09.md) stopped INVALID in network preflight. The next [runner-v9 attempt](test-plans/evidence/KR-003-SAMSUNG-QUALIFICATION-SCREEN-INVALID-2026-09-09.md) retained 100 automated PASS rows and p95 317 ms but stopped INVALID before any checkpoint-3 physical response; cleanup/network restoration passed. The required complete fresh run, remaining matrix, support decision and Play gate remain open; do not run automatically, change the Mi 8, reduce the gate or start KR-004.
OD-30's experiment has now failed input delivery; service non-interference remains **UNSPECIFIED**.

Production consumer enforcement is blocked by the unproven safety/reliability boundary and policy tension in ADR-0002.
Final pairing is blocked until OD-09/10/20 and the threat model tests are resolved.
Client table exposure is blocked until RLS allow/deny tests exist and pass.
GitHub planning publication is complete for machine-supported fields; UI-only view/workflow checks remain in docs/github/PROJECT.md.
Store submission is blocked by functioning UI/evidence, audience declarations, real screenshots, and launch decisions.

Ready now: product review, documentation/CI checks, generic transport-first physical feasibility execution on the approved next device,
local-only schema/RLS fixtures, pairing protocol review, deterministic domain fixtures using explicitly provisional semantics.
No physical devices, Play Console approval, or deployed backend are assumed.
