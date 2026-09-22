# KidRemote

Simple parental screen-time control without surveillance.

Parent Android app -> enrolled child devices -> remaining time, +10 / +30 minutes, Lock, Unlock. The child executes already-downloaded policy locally, including offline. A new remote command still needs connectivity.

## Current development

**Start with the [current execution and authority summary](https://github.com/felipebarbosa4/KidRemote/blob/kr-product-enforcement-integration/docs/exec-plans/TASK-CONTRACT.md#current-execution).**

The local product implementation is on `kr-product-enforcement-integration`, in [draft PR #24](https://github.com/felipebarbosa4/KidRemote/pull/24), stacked on `kr-010-local-parent-controls`. `main` remains the bootstrap implementation; this routing update does not merge the development stack. Check live refs before working and preserve any existing worktree changes.

The stack includes local parent authentication/controls, child enrollment/accounting/sync, and candidate enforcement integration. Implementation, automated validation, physical observation, and approval are different states. KR-003 and remaining physical acceptance are open; no production readiness, general Android support, real-family-use, deployment or Play approval is claimed.

The latest classified physical attempt in the audited implementation baseline is documented in the [pairing-cleanup callback review](https://github.com/felipebarbosa4/KidRemote/blob/kr-product-enforcement-integration/docs/test-plans/evidence/PRODUCT-PAIRING-CLEANUP-CALLBACK-2026-09-17.md). The earlier `b541595` handoff was subsequently executed and failed; do not reuse its old READY/NOT_RUN description or command. Current source, a frozen bundle, and an executed physical attempt must each be identified separately.

## Work on KidRemote

Read [AGENTS.md](AGENTS.md), then the current execution summary and the relevant existing KR issue. Continue the approved bounded product work; do not restart the initial architecture pass or default to optional KR-003 visual tooling. The original [Sprint 01](docs/exec-plans/SPRINT-01.md) and [architecture report](docs/REPORT.md) are dated history, not instructions to replay their former next steps.

| Need | Repository reference |
| --- | --- |
| Product and approved choices | [PRODUCT](docs/PRODUCT.md), [DECISIONS](docs/DECISIONS.md) |
| Architecture and wire semantics | [ARCHITECTURE](docs/ARCHITECTURE.md), [state machine](docs/product-specs/STATE-MACHINE.md), [protocol](packages/protocol/CONTRACT.md) |
| Security, privacy and platform gates | [SECURITY](docs/SECURITY.md), [PRIVACY](docs/PRIVACY.md), [POLICY](docs/POLICY.md), [ADRs](docs/adr/README.md) |
| Acceptance and existing backlog | [Test matrix](docs/test-plans/MATRIX.md), [issues](docs/github/ISSUES.md) |
| Component validation and environment | [Tooling](docs/TOOLING.md), current task contract |

These local links describe the checked-out revision. For current implementation work, use the active branch rather than treating older `main` documents as its current status.

## Validation

Repository-local shell, from the checkout root:

```sh
node tools/validate.mjs
git diff --check
```

These check repository contracts and hygiene, not physical enforcement. Run the component-specific tests required by the current task as well. Do not install to a device, provision infrastructure, accept licences, or change host configuration merely to make a documentation check pass.

Final brand and public distribution configuration remain separate owner decisions. KidRemote is a working codename.
