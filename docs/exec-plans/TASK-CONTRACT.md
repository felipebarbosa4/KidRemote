# Task contract

- **Goal:** Make every substantial task bounded, reviewable, and objectively complete.
- **Context:** Repository documents are technical source of truth; GitHub mirrors execution status.
- **Constraints:** One issue at a time; explicit unknowns; no broad production implementation in this pass.
- **Done when:** A new agent can identify the inputs, constraints, outputs, tests, and stopping point.

## Required task shape

```text
Goal: Observable outcome and KR identifier.
Context: Relevant spec, ADR, files, current evidence, dependencies.
Constraints: Scope, non-features, permission/privacy limits, decisions not yet approved.
Done when: Acceptance criteria, exact validation, evidence path, unresolved limitations.
```

For a change: inspect → update a small execution plan → implement within scope → run appropriate checks → record evidence → hand off.
For a spike: define a falsifiable hypothesis and stop on evidence of failure; do not conceal an infeasible requirement.
For a decision: record alternatives, security/privacy implications, operations, decision, reasons, risks, and invalidation tests in an ADR.
For an owner decision: preserve **UNSPECIFIED**, name the owner approval gate, and state the recommendation.

Evidence must distinguish **specified**, **implemented**, **tested**, and **approved**. They are not interchangeable.
A documentation check does not pass physical-device tests or database authorization tests.
Use synthetic households, devices, QR tokens, and command IDs in shared evidence.

OpenAI recommends clear task goals/context/constraints/completion criteria and durable repository guidance.
This repository uses those practices with a short map and detailed local specifications:
[best practices](https://learn.chatgpt.com/guides/best-practices),
[AGENTS.md](https://learn.chatgpt.com/docs/agent-configuration/agents-md),
[prompting](https://learn.chatgpt.com/docs/prompting). Verified 2026-09-05.
