# KidRemote

A working codename for simple parental screen-time control. Final product name: **UNSPECIFIED**.

Parent Android app → paired child Android devices → remaining time, +10 / +30 minutes, Lock, Unlock.
The child executes downloaded rules locally, including when offline.

## Current state

Architecture and planning scaffold, verified against official documentation on **2026-09-05**.
No production applications, backend deployment, database exposure, or device-test results exist.
Proposals requiring owner approval are recorded explicitly; this is not a claim that consumer enforcement is proven.

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

## Validate the planning scaffold

```sh
node tools/validate.mjs
git diff --check
node tools/publish-planning.mjs
```

The last command is a dry run. GitHub creation status and exact apply commands are in [Project setup](docs/github/PROJECT.md).
No Android, Supabase, Flutter, Kotlin, or Gradle versions are selected by these placeholders.
See [tooling](docs/TOOLING.md) for the one verified CI action version.

## Pick up a task

Read [AGENTS.md](AGENTS.md), select KR-001 or KR-002, and use the issue's Goal / Context / Constraints / Done when.
Record evidence in the repository. Never turn an unrun test or a proposed ADR into a passed launch gate.
