# OD-51 native persistent laboratory runner

- **Goal:** Finish the PR #24 product oracle's Windows-native host path and reusable synthetic enrollment for one owner-operated Samsung slice.
- **Context:** OD-50 authorizes replacement of the exact obsolete child only; OD-51 authorizes retained lab backend state. Previous supervisor failure and all historical physical verdicts remain unchanged.
- **Constraints:** No physical execution, WSLInterop repair, sudo, FCM, merge, release change or alteration of disposable database semantics. Credentials stay in protected host state/pipes. Independent ordinary fixture input/focus decides PASS.
- **Done when:** Ownership/persistence, host pre-destructive gate, first-run/reuse, native tooling, journal and failure tests pass; required CI passes; an immutable complete bundle is frozen, or exact remaining blockers are recorded honestly.

Implementation: separate native Node/Docker lease, PowerShell protected state and exclusive runner lock, existing SQL migrations/Auth/gateway handlers and canonical callbacks. Stop retains data; teardown is explicit, identity-verified and separately journaled. Incompatible or partial state fails closed. The host/backend gate runs inside the final command before device mutation.
