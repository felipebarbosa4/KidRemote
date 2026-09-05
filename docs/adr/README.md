# Architecture decisions

Every ADR includes Goal, Context, Constraints, Done when, alternatives, security/privacy, operations, decision, reasons, risks and invalidation tests.
Status “Proposed” is not owner approval. “Research complete” does not imply physical feasibility.

| ADR | Decision | Status |
| --- | --- | --- |
| [0001](0001-parent-framework.md) | Native Android parent and child, platform-neutral wire protocol | Proposed; OD-08 |
| [0002](0002-android-enforcement.md) | Consumer feasibility candidate; production gate | Research assessment complete; feasibility unproven |
| [0003](0003-device-authentication.md) | Opaque device identity behind Edge gateway | Proposed; OD-09/20 |
| [0004](0004-pairing.md) | Five-minute, single-use opaque QR pairing | Proposed; OD-10 |
| [0005](0005-state-and-time.md) | Independent lock reasons, daily local budget | Proposed; OD-01–05 |
| [0006](0006-backend-and-sync.md) | Supabase, transactional desired state and command audit | Recommended technical baseline |
| [0007](0007-future-platforms.md) | Fire/iOS/Windows boundary and research gates | Future-only |
