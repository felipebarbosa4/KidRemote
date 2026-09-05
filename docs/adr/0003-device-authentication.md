# ADR-0003 — Device-scoped authentication

Status: Accepted 2026-09-05 by owner directive; implementation and negative-test evidence remain required.

- **Goal:** Give each child only its own sync, acknowledgement, health and credential lifecycle.
- **Context:** Parents use Supabase Auth; child needs an identity after QR redemption.
- **Constraints:** No parent session on child, no client server key, no invented signing protocol.
- **Done when:** KR-005 threat model and KR-007 credential/negative endpoint tests pass.

## Alternatives evaluated

| Option | Benefits | Risks / operations |
| --- | --- | --- |
| Give child parent JWT | Easy SDK reuse | Rejected: household/parent privilege, shared recovery/logout, unacceptable blast radius |
| Separate Supabase Auth identity per device | Standard JWT lifecycle and possible device RLS | Must securely provision/tag device roles; authenticated role can accidentally inherit parent privileges; account/MAU lifecycle overhead |
| Custom device JWT accepted by database | Direct RLS access, fewer gateway calls | Signing/claim/key rotation complexity and unintended generic API reach; no requirement for it |
| Opaque per-device secret through Edge gateway | Simple revocation, no generic Data API reach, bounded permissions | Every route needs credential lookup and gateway authorization; service-key bypass means endpoint tests essential |

## Decision and reasons

Use securely generated 256-bit opaque bearer credentials over authenticated TLS, one device ID and independent credential record.
Server stores SHA-256 digest of high-entropy secret, credential ID, expiry and revocation; no parent password or JWT is involved.
Use standard platform randomness and constant-time verification; hashing random secrets is not password hashing.
No custom signing, encrypted QR, mutual-TLS deployment or attestation prerequisite is justified for MVP.
Attestation might later reduce some abuse, but cannot prove honest usage on a compromised OS.

Child calls dedicated routes only. Gateway derives device/household from credential record, never JSON target.
Disable the Supabase JWT gate only for routes using this custom authentication and implement handler verification before any data access.
Keep parent JWT routes verified with the supported current Supabase mechanism.
[Supabase Edge auth](https://supabase.com/docs/guides/functions/auth).

## Security/privacy implications

Keystore-generated wrapping key encrypts stored credential bytes; exclude credential/policy identity from cloud/device-transfer backup.
Keystore stores keys, not arbitrary strings; do not claim Room automatically encrypts.
[Keystore](https://developer.android.com/privacy-and-security/keystore),
[backup control](https://developer.android.com/identity/data/autobackup).
Own-device health can be fabricated by stolen credentials, but cannot grant time or read siblings.
No self-service household reassignment or issuance of parent tokens.

## Operational implications

Use 90-day server credential expiry and rotate after 30 days on online contact.
Persist both old/new rotation candidates before changing server state; a two-phase five-minute overlap prevents lost-response lockout.
Authenticate rotation with old credential; confirm new credential before revoking old; idempotent rotation ID returns same generation status, not a new secret repeatedly.
Long-offline expired credentials require explicit re-pair/recovery; already downloaded policy keeps enforcing locally.
Revoke checks occur every request, not just issuance. Revoked credentials return a typed removal response after verifying the secret matches a revoked record;
unknown secrets return generic unauthorized. No rate-limit bypass on this path.

## Risks and tests that invalidate the decision

Replay of a stolen bearer works until revocation/expiry; local OS compromise is outside guarantee.
Test sibling targeting, parent-route access, direct Data API denial, stale/revoked/expired credential, rotation response loss,
backup restore to another device, app data clear, server logs and rate limits.
Reconsider if the lookup cost cannot meet synthetic load targets or maintaining gateway authorization proves less safe than rigorously separated standard device Auth identities.
