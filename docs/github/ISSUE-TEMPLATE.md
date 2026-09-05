# Implementation issue template

## Goal

Observable outcome and KR identifier.

## Context

Product problem, current evidence, source-of-truth files and why this work is needed.

## Scope

Bounded changes.

## Out of scope

Explicit exclusions.

## Dependencies

KR issues, approvals, tests and platform gates.

## Technical constraints

Architecture, API/platform, performance, migration and compatibility rules.

## Security/privacy

Assets, authorization, permissions, minimization, logs and deletion impact.

## Acceptance criteria

- [ ] Given … when … then observable …
- [ ] Duplicate/failure/denial paths produce the specified result.

## Unit test plan

Meaningful domain/validation cases; state “not applicable” with reason when appropriate.

## Integration test plan

Database/API/client boundaries; tenant allow/deny where relevant.

## Physical-device test plan

OS/model/settings, expected observation and sample count; do not substitute emulator evidence for device behaviour.

## Failure-injection test plan

Network/process/reboot/permission/storage/duplicate/order failure seams.

## Observability

Allowed fields, useful measurements and forbidden sensitive data.

## Definition of done

Relevant checks pass, evidence recorded, documentation/ADRs updated, unrun checks and risks explicit.

## Done when

The bounded outcome and acceptance criteria above are objectively met.

## Story points

1 / 2 / 3 / 5 / 8 / 13; relative, not hours.

## Planning fields

Priority: P0 / P1 / P2 / P3

Risk: Low / Medium / High

Milestone: UNSPECIFIED

Area / Platform / Work Type: UNSPECIFIED

Decision required: Yes / No

## Open / UNSPECIFIED questions

Use exactly UNSPECIFIED for unchosen/unverified facts.

## Links to ADR/spec

Repository links and relevant current official documentation.
