# Security and threat model

- **Goal:** Protect household control, device identity and private family relationships with minimal data.
- **Context:** Supabase parent Auth/RLS, scoped device gateway, local consumer Android agent, QR enrollment.
- **Constraints:** Standard TLS/random opaque secrets/Keystore; no surveillance, custom cryptographic handshake, or unbreakable claims.
- **Done when:** Negative tenant/device tests, pairing race tests and supported-device safety tests pass; residual risks are accepted.

## Assets and actors

Assets: parent sessions/recovery; household membership; control authorization; device secrets; pairing capability; policy/grant integrity;
local consumption/receipts; push addresses; server credentials; minimal audit state; safety of access to emergency/recovery surfaces.
Actors: authorized parent, child/device user, unrelated parent, QR observer, unauthenticated attacker, malicious app,
compromised/rooted device, backend operator and third-party auth/push providers.
An authorized account does not prove legal guardianship. Adult coercive monitoring or stealth enrollment is abuse.

## Trust boundaries

Parent JWT → membership-authorized API/RLS; opaque device secret → own-device gateway;
gateway elevated credentials → database; provider push → untrusted hint; OS → Android app; app storage → backups/root/ADB.
See ARCHITECTURE for diagram and BACKEND for exact row matrix.
Supabase elevated secret keys bypass RLS, so gateway checks and test roles matter.
[Supabase keys](https://supabase.com/docs/guides/getting-started/api-keys).

## Required invariants and negative proof

| Invariant | Enforcement / observable test |
| --- | --- |
| Parent A cannot access/control B | RLS + membership transaction; test all verbs, joins, RPCs and guessed IDs as A |
| Device A cannot control/read B | Gateway derives target; rejects foreign device path/body/receipt/address |
| Device cannot get parent privilege | Separate credential audience/routes; no parent Auth session exchange |
| No server secret in mobile binary | Build/dependency/config scan and decompiled test binary audit |
| Pairing single-use/replay-resistant | Row lock/atomic consume; 20 concurrent redemptions produce one identity |
| Commands authenticated/idempotent | Actor from JWT, unique ID + payload match, transactional grant and absolute sync |
| Stale commands cannot override | Monotonic version/epoch validation; stale unlock cannot replace current lock |
| Tokens not logged | Redaction tests for headers, bodies, QR UI, URLs and provider errors; no raw request dump |
| Local secrets protected | Keystore wrapping, app-private bytes, backup/device-transfer exclusions |
| No content/location logs | Allowlisted structured event fields; tests inject forbidden data and verify absence |
| API abuse bounded | Atomic quotas, body limits, 429/Retry-After, no high-cardinality secrets in metrics |
| Delete/revoke supported | Transactional revocation; real credentials fail afterwards; offline limitation explicit |

## Abuse cases and mitigation matrix

| Threat | Mitigation | Residual risk |
| --- | --- | --- |
| Stolen parent password/session | Verified login, secure session storage, reauthentication for removal, recovery; MFA decision required | Authorized attacker can control household until session/account recovery |
| QR photograph/front-running | Five-minute TTL, single use, visible enrollment and revoke | First valid redeemer can win; proximity/guardianship not proven |
| Tenant-ID substitution / privilege escalation | RLS, immutable ownership, checked FKs, strict endpoint/schema allowlists | Backend privileged-code bug remains high-impact |
| Device credential extraction | Keystore-backed wrapping and revocation/rotation | Compromised OS can use keys/credential and falsify own state |
| Replay / duplicate ADD_TIME | Server unique operation, payload digest, local absolute totals/version | Distinct authorized taps intentionally add multiple grants |
| Stale sync/ack race | Consistent snapshots, monotonic report sequence/version/epoch | Parent state is still a delayed report |
| Fake push / provider outage | Ignore payload state; authenticate sync; recover by resume/reconnect/work | No guaranteed remote delivery time |
| Clock manipulation | Same-boot monotonic trusted anchor, no new credit on uncertain reboot | Offline trusted calendar time cannot be proven on consumer device |
| Silent disable/uninstall | Visible child status and last-seen freshness; explicit support limits | Device may be unable to send a final health report |
| Coercive use / unsafe block | Visible enrollment, no stealth, least data, emergency/recovery testing | Technical identity checks cannot verify guardian relationship |
| Backend compromise/operator misuse | Least secret exposure, environment separation, redacted audit, migration review | Operator/database access can reveal/control retained state |

## Tamper matrix

These are required research/tests, not claimed results. All physical outcomes currently **UNSPECIFIED**.

| Scenario | Expected product handling | Guarantee boundary / evidence |
| --- | --- | --- |
| Usage Access revoked | Permission required; accounting uncertain; pending repair | Test revoke mid-session and restart; do not invent history |
| Accessibility disabled | Enforcement degraded; no false “locked applied” | Consumer enforcement unavailable until user restores service |
| Force-stop | Last report becomes stale/offline; user must reopen/repair | No enforcement guarantee while stopped |
| Uninstall attempt/success | Visible removal supported; cloud becomes stale/revocable | No consumer anti-uninstall promise |
| Application data cleared | Unpaired on relaunch; old identity revoked by parent | Cannot recover erased local ledger securely without re-enrollment |
| Normal reboot | Restore policy and measure unlock-window gap | Required supported-device test, not automatically excluded |
| Reboot while offline | Restore expired/manual restriction; mark clock uncertainty | New-day credit withheld under the approved rule |
| Battery optimization/OEM killing | Reconnect/reconcile; report degraded where observable | Test default and restricted OEM settings; exclude failing configs explicitly |
| Safe mode | Later stale/degraded report; no attempted OS bypass | Consumer third-party enforcement not guaranteed |
| Guest/secondary user | Scope clearly says enrolled Android user | Other users outside MVP boundary; test switching |
| Clock forward | Same-boot budget/reset follows monotonic projection | Test +24h; no additional allowance |
| Clock backward | No negative consumption or replayed day | Test −24h; preserve consumed time |
| Timezone changed | Device setting ignored for household day | Test date-line crossing and DST zones |
| Developer options/ADB | Diagnose on lab devices, no security claim | Adversarial debugging/control outside guarantee |
| Root | May forge state/disable/extract/use credentials | Unsupported; no detection-as-proof claim |
| Unlocked bootloader | System integrity untrusted | Unsupported; normal UI warning/diagnostic if supportable |
| Parent credential available to child | Parent-authorized actions indistinguishable | Outside child-tamper protection; account hygiene/recovery |

### KR-003 local visual-evidence exception

OD-41 permits capture only on an explicitly authorized local KR-003 lab configuration. Capture is host-orchestrated, adds no candidate permission or production code path, never requests secure-layer bypass, and remains paired with the independent fixture/input/focus oracle. Raw media and image-bearing derivatives stay under the owner-controlled local run directory and are prohibited from repository, GitHub, CI-artifact, cloud, external-API and assistant/tool-image paths. Machine output is allowlisted to hashes, dimensions, monotonic timing bounds, distances and typed classifications. Blank/protected/ambiguous capture fails closed. The production prohibition on screenshots, recording, surveillance and content collection is unchanged.

Current Android force-stop behaviour is intentionally persistent until user interaction.
[Android 15 package state](https://developer.android.com/about/versions/15/behavior-changes-all).
Device Owner/Lock Task boundaries differ; see ADR-0002, never transfer their guarantees to consumer mode.

## Permission-health model

Store raw flags plus last_checked_at, not a single overwritten enum:
usage_access, accessibility_enabled, service_connected, accounting_confident, clock_trusted,
supported_os, agent_supported, restriction_required/applied, local_store_ok, sync/auth status.
Parent derivation:
App update required when compatibility floor fails; Permission required when a needed grant is absent;
Enforcement degraded for failed/disconnected adapter, uncertain time/accounting or storage failure; Healthy only when all required evidence is current.
Offline/freshness is separate and may overlay any health. Display last-known health with its age; never assume silence is Healthy.
Local storage corruption must not silently reset allowance or enroll a new device.

## Rate-limit proposal

Parent control 30/min per parent + 20/min per device; pairing create 5/10 min per parent;
redemption 10/min per short-lived source bucket and 5 failed attempts/session;
device sync 120/min per credential with coalescing; ack 120/min; maximum sync page 100 and body 64 KiB.
Values are tunable recommendations, not verified Supabase defaults. Exact production values **UNSPECIFIED**.
Use DB atomic buckets to avoid adding Redis, and short retention for source-IP-derived rate keys.
Auth has its own documented limits; configure SMTP/abuse controls separately.
[Supabase Auth rate limits](https://supabase.com/docs/guides/auth/rate-limits).

## Revocation, logout, deletion and recovery

### KR-006 account deletion design (OD-44; not an implemented endpoint)

The parent account screen must eventually offer an in-app request and the published
privacy listing must link a web request path. Neither a public domain nor deployment
is approved; this local app deliberately has no pretend-working deletion button.
The web path requires account authentication/reauthentication, not an emailed account
identifier as authority. Both paths share the same server operation, with an operation
ID for retries and server-derived subject/household; no caller-selected actor/tenant.

Flow: explain consequences → explicit confirmation → Auth-supported reauthentication
→ server verifies identity and sufficiently recent proof → lock account/household
and recheck active sole-owner authorization → revoke devices/all credentials, invalidate
push/outbox and pairing → mark deletion pending → perform idempotent application-row
and Auth-account deletion. The Auth deletion boundary is separate from the database
transaction: a provider failure leaves revocation and deletion-pending durable, retries
do not restore authorization, and completion is not shown before all required steps
are verified. Retain only approved minimal tombstones during the bounded cleanup.

Before committing revocation, network/provider failure permits safe retry without a
false completion. After revocation commits, response loss returns the existing pending
operation on retry. Recheck authorization at commit; reject cross-household requests,
stale reauthentication and membership removed after initial request. Production proof
freshness policy/provider configuration remain **UNSPECIFIED**, not an invented local
password mechanism. Client cache cleanup must run even when logout/deletion contact fails.

Offline children cannot receive immediate revocation/removal. They continue enforcing
the last downloaded valid policy until the specified next-contact/removal or visible
local recovery path; account deletion is not a remote unlock guarantee. Live application
deletion target remains OD-14's seven days; provider backup purge is not promised.
After credential digest/tombstone purge, unknown credentials get generic unauthorized,
not fabricated signed removal instructions. KR-007 must implement/test the child UX
and safe recovery before real use. Tests still required for the deletion implementation:
reauth expiry, cross-tenant attempts, races, provider failure, response loss, retry,
offline child, retained-data cleanup and both request pathways.

KR-006's implemented local logout requests Auth **local-session** scope and deletes
the app's refresh-token file/key and in-memory presentation. Existing signed access
JWTs can remain accepted by PostgREST until expiry; actual local tests retain this
limitation. Removed membership nevertheless denies tenant access immediately through
RLS. Keystore/OEM backup, process recreation and physical link/TalkBack tests remain
unrun; source/unit tests are not physical storage evidence.

Logout clears parent session/cache and ends the chosen session scope; it does not cancel child policy.
Supabase access tokens can remain valid until expiry after signout; membership revocation must be checked server-side.
[Supabase sessions](https://supabase.com/docs/guides/auth/sessions).

Revoke a device: reauthenticate parent → mark revoked and revoke all credential generations atomically → remove push registrations → deny future control/auth.
A matching revoked credential may receive only an authenticated removal response; it cannot obtain policy, parent data or a replacement credential.
An offline device cannot receive removal immediately. UI says “Removed from account; local removal takes effect when the device reconnects.”
Recommend visible child local removal/recovery instructions as a safe consumer fallback; exact guardian confirmation method **UNSPECIFIED** (OD-07/20).
No remote wipe, passcode reset or policy lease that silently cancels offline expiry.

Delete account: recent reauthentication, visible device impact, revoke all owned-household devices, cancel QR sessions,
stop pushes, remove household/profile/data according to retention, then delete Auth identity.
MVP assumes a sole owner only provisionally; future co-owner deletion must not erase another guardian's household.
Design a web deletion request route as well as in-app flow when accounts can be created.
[Google Play deletion](https://support.google.com/googleplay/android-developer/answer/13327111).

## Residual risks and support policy

No enforcement guarantee outside the tested intact consumer installation and enrolled Android user.
Normal process death/update/reboot still require evidence; network loss alone must not disable an already downloaded restriction.
Push, clock/calendar trust after offline reboot, policy acceptance, physical OEM durability and credential compromise remain top risks.
Security reporting address, incident owner, recovery SLA and disclosure channel: **UNSPECIFIED**.
This is a technical threat model, not legal advice.
