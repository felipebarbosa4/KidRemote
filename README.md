# KidRemote

A working codename for simple parental screen-time control. Final product name: **UNSPECIFIED**.

Parent Android app → paired child Android devices → remaining time, +10 / +30 minutes, Lock, Unlock.
The child executes downloaded rules locally, including when offline.

## Current state

Architecture and planning scaffold, verified against official documentation on **2026-09-05**.
KR-001/002 are complete and KR-003 now has an isolated, disposable Android enforcement test harness.
Bounded [Mi 8 physical evidence](docs/test-plans/evidence/KR-003-MI8-2026-09-06.md) exists; that configuration's active-oracle transport is blocked.
The authorized [Samsung SM-X400 / Android 16 transport passed](docs/test-plans/evidence/KR-003-SAMSUNG-TRANSPORT-CALIBRATION-2026-09-08.md). Three v1 calibrations remain INVALID at runner-side Accessibility verification; the [runner-v2 attempt](docs/test-plans/evidence/KR-003-SAMSUNG-HOST-EXCEPTION-2026-09-08.md) proved that correction passed, then stopped INVALID during the ARM host stage before any blocked hold. The [runner-v3 invocation](docs/test-plans/evidence/KR-003-SAMSUNG-RUNNER-V3-STARTUP-2026-09-08.md) then failed on a reserved PowerShell variable before any device command. Four independent [runner-v4 attempts](docs/test-plans/evidence/KR-003-SAMSUNG-RUNNER-V4-HOST-EXCEPTIONS-2026-09-08.md) passed permission/positive controls and issued ARM, then stopped on the same deterministic host variable-alias defect before attachment or blocked hold; cleanup succeeded each time. The immutable [runner-v5 replacement](docs/test-plans/evidence/KR-003-SAMSUNG-CALIBRATION-V5-BUNDLE-2026-09-08.md) is prepared but Not run. No Samsung enforcement sample exists. The KR-003 qualification gate remains open.
No production application, backend deployment, database exposure or Play approval exists.

Read [the architecture-pass report](docs/REPORT.md) in the requested A–I order, then:

| Need | Source of truth |
| --- | --- |
| MVP and unknowns | [Product](docs/PRODUCT.md), [decisions](docs/DECISIONS.md) |
| Components and boundaries | [Architecture](docs/ARCHITECTURE.md) |
| State, time, backend | [State machine](docs/product-specs/STATE-MACHINE.md), [local time](docs/product-specs/LOCAL-TIME.md), [backend](docs/product-specs/BACKEND.md) |
| High-risk decisions | [ADRs](docs/adr/README.md), [Play assessment](docs/POLICY.md) |
| Threats and data | [Security](docs/SECURITY.md), [privacy](docs/PRIVACY.md) |
| Wire contract | [Protocol](packages/protocol/CONTRACT.md) |
| UI concepts | [Design system](docs/design/DESIGN-SYSTEM.md), [five wireframes](docs/design/wireframes.html), [three store concepts](docs/design/STORE-CONCEPTS.md) |
| Bounded work | [Ten issues](docs/github/ISSUES.md), [Project setup](docs/github/PROJECT.md), [first sprint](docs/exec-plans/SPRINT-01.md) |
| Evidence and validation | [References](docs/REFERENCES.md), [test matrix](docs/test-plans/MATRIX.md), [capacity](docs/test-plans/CAPACITY.md) |
| Current feasibility spike | [Android enforcement spike](spikes/android-enforcement/README.md), [KR-003 physical protocol](docs/test-plans/KR-003-PHYSICAL.md) |

## Validate the planning scaffold

```sh
node tools/validate.mjs
git diff --check
node tools/publish-planning.mjs
```

The last command is a dry run. GitHub creation status and exact apply commands are in [Project setup](docs/github/PROJECT.md).
Production application/library versions remain **UNSPECIFIED**. KR-003 alone pins its disposable compatible Android toolchain;
see [tooling](docs/TOOLING.md).

## Pick up a task

Read [AGENTS.md](AGENTS.md), continue the active KR-003 feasibility issue, and use its Goal / Context / Constraints / Done when.
Record evidence in the repository. Never turn an unrun test or a proposed ADR into a passed launch gate.
