# Decision and unknown register

- **Goal:** Prevent recommendations from becoming undocumented product assumptions.
- **Context:** Initial architecture pass, 2026-09-05.
- **Constraints:** Unchosen facts/requirements are **UNSPECIFIED**. Proposal text is not approval.
- **Done when:** Each gate has an owner outcome and linked ADR/test evidence before dependent production work.

Owner identity and approval date: **UNSPECIFIED**. Product owner is the requested approval role, not an assigned person.

| ID | Actual decision / fact | Recommendation or required resolution | Gate |
| --- | --- | --- | --- |
| OD-01 | Unlock and manual-lock reset semantics: **UNSPECIFIED** | Unlock only manual lock; manual lock survives midnight; +time does not unlock; ADR-0005 | KR-001 |
| OD-02 | Screen-time definition/exemptions: **UNSPECIFIED** | Interactive + keyguard hidden + permitted-use time, per device; minimal local-only events | KR-001/003 |
| OD-03 | Timezone/daily reset: **UNSPECIFIED** | Confirmed household IANA zone, local midnight, no bonus carry-over | KR-001 |
| OD-04 | Offline reboot clock uncertainty: **UNSPECIFIED** | Carry current balance, defer new-day credit until trusted time; explicit degraded UI | KR-001/003 |
| OD-05 | Missing accounting / conservative restriction: **UNSPECIFIED** | Restrict ordinary use if interval cannot be reconciled; retain emergency/recovery | KR-001/003 |
| OD-06 | Consumer enforcement risk acceptance: **UNSPECIFIED** | Evaluate consumer Accessibility route; no production go-ahead until physical/policy gates pass | KR-003 |
| OD-07 | Emergency/system allowances and recovery: **UNSPECIFIED** | Validate dialler/emergency/system accessibility and visible disable/re-pair recovery; no fake OS lock | KR-003 |
| OD-08 | Parent framework: **UNSPECIFIED** | Native Kotlin/Compose; Flutter gains no proven near-term benefit; ADR-0001 | KR-002 before app bootstrap |
| OD-09 | Device authentication: **UNSPECIFIED** | Independent opaque bearer, hashed server-side, Edge-only scope; ADR-0003 | KR-005/007 |
| OD-10 | Pairing TTL: **UNSPECIFIED** | Five minutes; single-use atomic redemption; explicit replacement on interruption | KR-005 |
| OD-11 | Parent login/recovery/MFA: **UNSPECIFIED** | Verified email/password + recovery for alpha; security review for production | KR-006 |
| OD-12 | Household sharing, multiple guardians: **UNSPECIFIED** | One creating owner, one household per parent in MVP; normalized membership leaves room for future invitations | KR-001/006 |
| OD-13 | Play audience/child ages/markets: **UNSPECIFIED** | Classify parent and child listings independently with owner policy review | Release |
| OD-14 | Retention/deletion times, region and processors: **UNSPECIFIED** | Proposed minima in PRIVACY, including provider backups; confirm before real accounts | Alpha with real data |
| OD-15 | Android minimum/target/compile SDK and supported OEMs: **UNSPECIFIED** | Candidate min API 28 because selected events exist; target current Play requirements verified at bootstrap; physical support list required | KR-002/003 |
| OD-16 | Budget and user definition: **UNSPECIFIED** | Load-test assumption only: 1,000 parents, 5,000 devices; no hosting tier chosen | Capacity/provisioning |
| OD-17 | Final brand, package IDs, domains: **UNSPECIFIED** | KidRemote remains codename; do not buy or publish names | Distribution |
| OD-18 | Dark mode: **UNSPECIFIED** | Light MVP; later native dark theme | KR-010 |
| OD-19 | Initial daily limit and maximum bonus: **UNSPECIFIED** | Require explicit parent limit; propose limit 0–86,400 s and total allowance cap 86,400 s with rejection at cap | KR-001 |
| OD-20 | Credential lifetime/rotation and offline revocation removal: **UNSPECIFIED** | 90-day credential, rotate by 30 days; downloaded policy survives auth expiry; next-sync revocation and visible local removal | KR-005/007 |
| OD-21 | Sprint date/team availability/device inventory: **UNSPECIFIED** | Five working days relative to kickoff; conditional capacity in sprint plan | Sprint commitment |
| OD-22 | Licence, CI approval/ruleset, secret owners: **UNSPECIFIED** | Confirm before accepting outside contributions or deploying | Repository/release |
| OD-23 | Future Apple remote capabilities: **UNSPECIFIED** | RESEARCH REQUIRED; entitlement is external dependency; no promise of Android parity | Apple Feasibility |
| OD-24 | Windows privilege/enforcement and Fire model support: **UNSPECIFIED** | Future-only research; ADR-0007 | Future milestones |
| OD-25 | Play review, FCM migration compatibility, physical metrics: **UNSPECIFIED** | Run KR-003/009 and measured tests; documentation alone cannot confirm | Alpha/release |

Exact Kotlin, Compose, Room, Gradle, AGP, Java toolchain, Android SDK, Flutter, Supabase CLI/client, Deno/Edge runtime and FCM SDK versions: **UNSPECIFIED**.
No app/bootstrap dependency versions are chosen in this pass. The verified Actions checkout pin is documented in TOOLING.

## Blockers and work that can proceed

Production consumer enforcement is blocked by the unproven safety/reliability boundary and policy tension in ADR-0002.
Final pairing is blocked until OD-09/10/20 and the threat model tests are resolved.
Client table exposure is blocked until RLS allow/deny tests exist and pass.
GitHub Project creation is blocked by missing Project OAuth scopes; repository Issues/labels/milestones are independently available.
Store submission is blocked by functioning UI/evidence, audience declarations, real screenshots, and launch decisions.

Ready now: product review, documentation/CI checks, physical feasibility spike design/execution on approved test devices,
local-only schema/RLS fixtures, pairing protocol review, deterministic domain fixtures using explicitly provisional semantics.
No physical devices, Play Console approval, or deployed backend are assumed.
