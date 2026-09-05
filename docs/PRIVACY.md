# Privacy and data minimization

- **Goal:** Provide total screen-time control without surveillance.
- **Context:** Parent account plus paired child identity and minimal latest state; no advertising/payment/AI runtime.
- **Constraints:** No data collection merely because APIs expose it; technical design is not legal advice.
- **Done when:** Approved technical retention is implemented, audience/region/legal facts are resolved, SDK inspection confirms actual data flows, and deletion tests pass.

## Collection inventory

| Data | Purpose | Storage / access |
| --- | --- | --- |
| Parent email/authentication data | Account/login/recovery | Supabase Auth; password handling delegated to Auth |
| Parent profile ID and household membership | Tenant authorization | Supabase PostgreSQL; own parent RLS |
| Device nickname and opaque device ID | Identify controlled device | Cloud + enrolled device; nickname should avoid sensitive full names |
| Optional basic model, platform/OS major, agent/protocol version | Compatibility/support | Latest cloud/device state; no serial/IMEI/advertising ID |
| Daily limit, manual lock, dated grants | Deliver policy | Cloud canonical + local persistent copy |
| Current used/remaining total, current day, receipt and health | Parent UI and sync correctness | Latest cloud state + local aggregates |
| Push address (FID/current provider registration) | Wake/sync hint | Private cloud table + provider/device SDK; not parent-readable |
| Pairing token digest, scoped credential digest | Secure enrollment/authentication | Private cloud; raw device secret Keystore-wrapped locally |
| Minimal control/security audit | Abuse investigation/idempotency | Private cloud, no request bodies |
| Server receipt/last-seen time and bounded errors | Freshness/reliability | Cloud; no content/location fields |
| Ephemeral QR camera frames | User-initiated scanning | Memory only; no upload or media library permission |
| Transient screen/keyguard signals | Total local accounting | On device reduced immediately; no stored app history |

Hosting region, plan, legal controller/contact, legal basis, exact child ages/markets and processor agreements: **UNSPECIFIED**.
Supabase/Firebase are proposed processors; provider telemetry/security/network logs must be reviewed before real data.
Normal HTTPS/push providers may process network metadata; “no surveillance” does not mean zero technical data.

## Explicitly not collected

GPS/location/geofences; browsing history/URLs; SMS/calls/social communications; contacts; photos/media;
microphone/audio; camera monitoring; screenshots/screen recordings; keystrokes/typed text; web/content inspection;
per-app usage histories or uploaded activity analytics; advertising IDs; rewards/payment data.
Do not retain Android package identifiers incidentally returned in usage queries.
If an ephemeral package identifier becomes essential for emergency/system handling, document the local-only rationale and get explicit approval before retention.
No Google Analytics, Crashlytics, advertising SDK or detailed session replay by default.

## Retention concept — approved alpha technical baseline

The application-controlled live-data targets below were approved on 2026-09-05. Provider backup purge duration, hosting region,
legal basis and contractual requirements remain **UNSPECIFIED** and must be resolved before real family data.

| Dataset | Approved minimum retention approach |
| --- | --- |
| Account/household/device/policy | While active; delete from live application tables within 7 days after confirmed deletion |
| Cloud state | Overwrite latest state; no historical screen-time dashboard |
| Dated grants and detailed receipts | Current/previous day for routine sync; retain minimal control audit up to 30 days |
| Idempotency tombstones | Operation ID + actor/target/payload digest and result class while device identity is active; prevents old replay after payload pruning |
| Pairing | Secret never stored; expiry five minutes proposed; prune expired session metadata within 24 hours |
| Incomplete enrollment | Proposed 15-minute cleanup after failed first confirmation; parent-visible |
| Device credentials/push addresses | Revoke immediately on removal; purge secret digest/address on deletion after removal response needs are resolved |
| Security/control audit | Proposed 30 days, minimized/pseudonymous; no raw token or content |
| Rate limit / network diagnostic data | Proposed short buckets, ≤24h technical retention; provider configuration must be verified |
| Local accounting | Current/previous day aggregates; bounded cursor/gap metadata ≤48h; no package history |
| Backups/provider data | Provider-specific delayed purge; duration **UNSPECIFIED** until contracted configuration verified |

Tombstones must remain sufficient to reject a replay without reapplying ADD_TIME even after detailed command deletion.
Deletion removes household relationships; any retained security event must have a documented purpose and identity minimization.

## Deletion lifecycle

Parent gets in-app account/device deletion and a public web request option before Play release.
Reauthenticate, explain loss of remote control, revoke credentials, remove memberships/policies/push destinations and delete account data.
Backup expiry and provider deletion are disclosed rather than promised instantaneous.
Device-local clearing requires device contact or a visible local removal flow; a disconnected device cannot be remotely erased.
[Play account deletion](https://support.google.com/googleplay/android-developer/answer/13327111).

Firebase documents installation deletion and provider processing; current page describes removal across relevant live/backup systems within 180 days.
That is a provider statement, not KidRemote's live-row retention target, and must be rechecked at launch.
[Firebase installations](https://firebase.google.com/docs/projects/manage-installations).
No installation/auth token is a substitute for the KidRemote device credential.

## Audience, disclosures and release review

Exact Play target audience for each app: **UNSPECIFIED**. Parent app and child agent may have different classifications; adult purchaser does not determine child-app audience.
If children are included, Families data/SDK constraints must be evaluated, including identifiers and camera scanning.
No ads does not remove other Families requirements.
[Target audience](https://support.google.com/googleplay/android-developer/answer/9867159),
[Families](https://support.google.com/googleplay/android-developer/answer/9893335?hl=en).

Complete accurate Data safety and privacy policy disclosures covering SDK/provider behaviour.
Aggregate device usage/health shared with parents may require monitoring-app policy classification even without content surveillance; owner/policy review required.
[Data safety](https://support.google.com/googleplay/android-developer/answer/10787469),
[monitoring metadata](https://support.google.com/googleplay/android-developer/answer/12955211?hl=en).
Never infer legal compliance or consent sufficiency from this architecture.

## Verification

Inspect dependency manifests and merged permissions, outbound test traffic and cloud schemas.
Assert no forbidden fields in logs/events/API payloads and no QR frame persistence.
Test live deletion, stale JWT membership denial, provider registration invalidation, backup restoration exclusions and child offline-removal messaging.
