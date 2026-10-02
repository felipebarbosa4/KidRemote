# KidRemote agent map

Deliver a minimal parental screen-time product: enrolled devices, remaining time, +10 / +30 minutes, Lock and Unlock, with local execution of downloaded policy while offline. Do not turn KidRemote into a surveillance product.

## Start here

- Read the [current execution and authority summary](https://github.com/felipebarbosa4/KidRemote/blob/kr-product-enforcement-integration/docs/exec-plans/TASK-CONTRACT.md#current-execution) before selecting work. `main` still contains the bootstrap implementation; active local product integration is on `kr-product-enforcement-integration` / draft PR #24. Verify the live refs; do not reset, switch a dirty worktree, merge the stack, or treat a source revision as a runnable bundle.
- In the active checkout, use [TASK-CONTRACT](docs/exec-plans/TASK-CONTRACT.md), [PRODUCT](docs/PRODUCT.md), [ARCHITECTURE](docs/ARCHITECTURE.md), and [DECISIONS](docs/DECISIONS.md). On an older checkout, follow the current summary first: dated plans, inventories, and old “next task” instructions are not the current scheduler.
- Code and executed tests establish implementation facts, not permission. Accepted owner decisions establish authorization, not test results. Later explicit scoped amendments replace only the restrictions they name; ambiguity outside that scope requires an owner decision.

## Work and evidence

Work on one bounded existing KR workstream. Record Goal / Context / Constraints / Done when; reuse existing plans, code and tests. Complete safe, authorized repository-local implementation, diagnosis, validation and evidence updates without routine permission requests. Prefer the earliest unresolved product dependency over optional tooling. A prepared bundle is an intermediate deliverable, not a working product.

Keep OBSERVED, INFERRED and UNKNOWN / UNSPECIFIED distinct. Never promote a build, emulator result, attachment, ACK, or internal counter into physical acceptance. Preserve every failed/invalid attempt and immutable bundle; independent fixture input/focus and required human observations remain separate from product telemetry.

Physical execution follows the exact current task and device authorization and stops for genuine consent/observation, unsafe state, FAIL/INVALID, or out-of-scope destruction. No blanket ADB permission follows from this map. No WSLInterop repair, host privilege change, sudo/password request, or unapproved state-damaging operation.

## Focused references

- Security/privacy: [SECURITY](docs/SECURITY.md), [PRIVACY](docs/PRIVACY.md), [backend/RLS](docs/product-specs/BACKEND.md). No secrets, content capture, or app-history surveillance in release.
- Semantics: [state machine](docs/product-specs/STATE-MACHINE.md), [local time](docs/product-specs/LOCAL-TIME.md), [protocol](packages/protocol/CONTRACT.md). Push is a sync hint; interval accounting is monotonic.
- Enforcement: [ADR-0002](docs/adr/0002-android-enforcement.md), [POLICY](docs/POLICY.md), [test matrix](docs/test-plans/MATRIX.md). KR-003 acceptance remains open; local development exceptions do not authorize real-family use, deployment, distribution, Play acceptance, or merging existing draft PRs.
- Verification: follow the current task contract's component-specific checks, plus `node tools/validate.mjs` and `git diff --check`. Planning checks alone do not validate the product. Verify official APIs/versions when changing them; do not reselect pinned dependencies for routine work.

Keep external prompts and tool-specific adapters as pointers to this map, not additional copies of changing task state.
