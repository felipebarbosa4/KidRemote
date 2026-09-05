# ADR-0004 — Secure QR enrollment

Status: Proposed; TTL **UNSPECIFIED**, recommend five minutes (OD-10); device-auth approval also required.

- **Goal:** Bind one consenting installation to the authenticated parent's household once.
- **Context:** QR is visible on parent device, scanned by child, redeemed over TLS.
- **Constraints:** No reusable parent JWT in QR/logs, one-time token, household isolation.
- **Done when:** KR-005 includes race/replay/interruption tests and KR-007 proves scoped identity storage.

## Alternatives evaluated

Long-lived enrollment code: simpler sharing but excessive exposure.
Short numeric code: accessible fallback, but brute-force resistance/rate limits require more work; not MVP.
Opaque random QR capability: adequate entropy, small protocol and no parent identity disclosure. Recommended.
Parent-device public-key cryptographic ceremony: unnecessary complexity for this requirement.

## Protocol and sequence

Token is 32 securely random bytes encoded base64url; store digest only with session ID, creator, household, server expiry and consumed/cancelled status.
QR payload is version + opaque session ID + token. It contains no email, household data or parent JWT.
Backend environment is selected by trusted build configuration; scanner rejects arbitrary hosts/deep-link redirects from QR.
Send secret in HTTPS request body, never query string. Cache-Control no-store on secret responses; scrub request/body/Authorization logs.

```mermaid
sequenceDiagram
  actor Parent
  participant P as Parent app
  participant E as Edge API
  participant D as PostgreSQL
  participant C as Child app
  Parent->>P: Sign in; Pair a device
  P->>E: Create session with parent JWT
  E->>D: Verify membership; store token digest + expiry
  E-->>P: Opaque QR payload (secret returned once)
  P-->>C: Display and scan QR with consent
  C->>E: Redeem(session ID, token, installation metadata)
  E->>D: Transaction: lock row, check expiry/unused/household
  D->>D: Create device + scoped credential digest; consume challenge
  D-->>E: Commit device identity
  E-->>C: Device ID + scoped secret (one-time return)
  C->>C: Keystore-wrap secret; persist identity
  C->>E: Authenticated first sync / confirmation
  E-->>P: Own-session completion status / device appeared
  P-->>Parent: Paired; permission/policy setup status
```

The session household is authoritative; child household/parent IDs are not accepted.
Two simultaneous redemptions: one commits; other fails as used. Expired, cancelled and replayed token fail.
Server timestamp decides TTL; client clock does not.
Parent sees enrolled device and can immediately revoke unexpected enrollment before enabling a policy.
Pairing success does not claim permissions or active enforcement.

## Interruption semantics

Before commit: no device; same still-valid token may be submitted.
After commit but before secret persisted: token remains consumed; do not return a fresh secret for a replay.
Parent sees incomplete device, revokes it and creates a fresh QR. This intentionally favours one-time security over invisible retry.
A first sync with a successfully stored credential is independently retryable.
Propose pruning incomplete enrollment after 15 minutes with parent-visible status; duration **UNSPECIFIED** pending retention review.
Parent may cancel/regenerate; old challenge is invalidated. If a redemption raced cancellation and already committed, offer revoke explicitly.

## Security/privacy implications

Anyone photographing a valid QR can race enrollment. TTL limits exposure but does not prove physical ownership.
Do not send QR in analytics/crash reports; parent display should discourage sharing.
Propose suppressing screenshots for the QR activity and clearing secret on expiry/navigation; capability must be verified at implementation.
Cross-household tests reject foreign session polling/cancellation and an attacker-provided household ID.
Do not claim that same-household authorization verifies legal guardianship; consent/age process **UNSPECIFIED**.

## Operational implications

Five minutes balances setup delay with exposure; two minutes risks repeated expiry for permission/onboarding delays, ten increases capture window.
Perform permission setup independently so it does not require token extensions.
Propose creation 5 sessions/10 min per parent; redemption 10/min per short-lived source-IP bucket and 5 invalid attempts/session, with accessible retry.
Limits and TTL are application proposals, not Supabase built-in behaviour. Use atomic DB limits and generic errors.

## Decision, reasons, risks and invalidation tests

Choose single-use opaque token + transaction + scoped identity for simplicity and replay resistance.
Invalidate if retry races produce two devices, secret appears in normal logs, wrong-household actions succeed, or token possession can grant parent privilege.
Test expired/replayed/cancelled/interrupted QR, 20 concurrent redemptions, unauthorized session inspection,
malformed/huge QR, arbitrary backend URL, stolen QR front-running and parent revocation.
