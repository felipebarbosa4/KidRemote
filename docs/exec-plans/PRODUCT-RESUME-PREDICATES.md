# OD-51 read-only resume predicate diagnosis

- **Goal:** Explain the source-07cf5e1 read-only INVALID as far as preserved evidence permits and make every future resume refusal actionable without weakening admission.
- **Context:** Attempt `e888975a-207a-473f-a442-2a2895f02347` stopped at `DEVICE_READONLY_PREFLIGHT` before tablet mutation. Historical attempt `d9157ae6-a6ff-4849-919f-c8f13fe08f7e` remains INVALID/UNVERIFIED.
- **Constraints:** No Samsung/ADB execution, content or credential reads, historical rewrite, unknown-file allowlisting, saved-device deletion, backend enrollment deletion, old-bundle rerun or physical acceptance. Only sanitized host/backend structure may be inspected.
- **Done when:** Every resolver prerequisite has an evidence status; every future refusal persists typed `failedChecks`; exact physical-state regressions pass under PS5.1/PS7 and CI; a bundle is frozen only if the historical blocker is established and safely handled.

