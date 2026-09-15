# OD-51 typed lease ACL initialization

- **Goal:** Diagnose the source-60fd897 host-only INVALID and make exact lab directory ACL setup idempotent, fail-closed and observable on PR #24.
- **Context:** Diagnostic c5c56ac0 / attempt 18240f7d; LEASE_STATE/HOST_PREREQUISITE before tablet mutation. Existing lease dates to source 3693034. No saved Windows ACL/exception proves the exact failing API.
- **Constraints:** No physical/ADB/interop repair; no secret decryption in diagnosis; no host state deletion or enrollment reset. Current user + SYSTEM, protected inheritance only; changes limited to exact task-owned physical-lab directory. Preserve old verdicts/bundles.
- **Done when:** Typed directory/ACL/lock/partial/conflict failures, actual PS5.1/PS7 ACL and DPAPI CI, existing regressions/full CI, new immutable bundle and one replacement command if ready. Never infer historical root cause from new tests.
