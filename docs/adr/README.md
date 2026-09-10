# Architecture decisions

Every ADR includes Goal, Context, Constraints, Done when, alternatives, security/privacy, operations, decision, reasons, risks and invalidation tests.
Accepted decisions are owner-approved architecture choices, not implementation or physical-feasibility evidence.

| ADR | Decision | Status |
| --- | --- | --- |
| [0001](0001-parent-framework.md) | Native Android parent and child, platform-neutral wire protocol | Accepted 2026-09-05 |
| [0002](0002-android-enforcement.md) | Consumer feasibility candidate; production gate | Spike authorized; feasibility/Play acceptance unproven |
| [0003](0003-device-authentication.md) | Opaque device identity behind Edge gateway | Accepted 2026-09-05 |
| [0004](0004-pairing.md) | Five-minute, single-use opaque QR pairing | Accepted 2026-09-05 |
| [0005](0005-state-and-time.md) | Independent lock reasons, daily local budget | Accepted 2026-09-05 |
| [0006](0006-backend-and-sync.md) | Supabase, transactional desired state and command audit | Accepted 2026-09-05 |
| [0007](0007-future-platforms.md) | Fire/iOS/Windows boundary and research gates | Future-only |
| [0008](0008-qualification-automation.md) | Debug qualification controls and observation oracle | Accepted; Q7 active-oracle redesign prepared, physical preflight pending |
