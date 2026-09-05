# KidRemote agent map

KidRemote is a working codename. This repository is in architecture/feasibility, not production.

- Start with [README](README.md), [PRODUCT](docs/PRODUCT.md), [ARCHITECTURE](docs/ARCHITECTURE.md), and [decision register](docs/DECISIONS.md).
- For every substantial task record **Goal**, **Context**, **Constraints**, **Done when** using [the task contract](docs/exec-plans/TASK-CONTRACT.md).
- Work on one bounded KR issue from [the backlog](docs/github/ISSUES.md). Read its dependencies, ADRs, and test requirements first.
- Security and data minimization: [SECURITY](docs/SECURITY.md), [PRIVACY](docs/PRIVACY.md), [RLS design](docs/product-specs/BACKEND.md).
- Product semantics: [state machine](docs/product-specs/STATE-MACHINE.md); wire contract: [protocol](packages/protocol/CONTRACT.md).
- Platform work: [enforcement ADR](docs/adr/0002-android-enforcement.md), [policy assessment](docs/POLICY.md), [timer](docs/product-specs/LOCAL-TIME.md).
- Evidence: [official references](docs/REFERENCES.md), [test matrix](docs/test-plans/MATRIX.md), [capacity plan](docs/test-plans/CAPACITY.md).
- UI: [design system](docs/design/DESIGN-SYSTEM.md), [wireframes](docs/design/wireframes.html).
- Verification for this scaffold: `node tools/validate.mjs` and `git diff --check`. These do not certify an app, RLS, or enforcement.
- Use current official documentation; cite significant platform/security claims. Unverified facts and unchosen product decisions are exactly **UNSPECIFIED**. Recommendations are not owner approval.
- Never ship backend secrets, upload app/content history, or log credentials. Preserve existing changes.
- Production enforcement requires KR-003's approved feasibility evidence; pairing requires the threat model; client database access requires RLS allow/deny tests.
- Do not deploy, publish store assets, or expand features as part of this architecture pass.
