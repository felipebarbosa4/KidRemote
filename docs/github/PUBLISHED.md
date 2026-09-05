# Planning publication status

- **Goal:** Record the GitHub planning state that was actually observed and changed.
- **Context:** Reconciled against the repository manifests and GitHub on 2026-09-05.
- **Constraints:** Planning evidence is not implementation, policy approval, database-test or physical-device evidence.
- **Done when:** Published artefacts are mapped, machine-set values are verified, and the UI-only remainder is explicit.

## Repository planning artefacts

All intended repository artefacts from the interrupted publisher were present before this reconciliation:

- all 17 planned labels exist; existing GitHub default labels were preserved;
- all six planned milestones exist with no due dates;
- all ten open KR issues exist as issues #1–#10;
- each issue title, milestone, label set and full body matches [issues.json](issues.json) and its local body after the publisher's expected branch-link rewriting.

| ID | GitHub issue |
| --- | --- |
| KR-001 | [#1](https://github.com/felipebarbosa4/KidRemote/issues/1) |
| KR-002 | [#2](https://github.com/felipebarbosa4/KidRemote/issues/2) |
| KR-003 | [#3](https://github.com/felipebarbosa4/KidRemote/issues/3) |
| KR-004 | [#4](https://github.com/felipebarbosa4/KidRemote/issues/4) |
| KR-005 | [#5](https://github.com/felipebarbosa4/KidRemote/issues/5) |
| KR-006 | [#6](https://github.com/felipebarbosa4/KidRemote/issues/6) |
| KR-007 | [#7](https://github.com/felipebarbosa4/KidRemote/issues/7) |
| KR-008 | [#8](https://github.com/felipebarbosa4/KidRemote/issues/8) |
| KR-009 | [#9](https://github.com/felipebarbosa4/KidRemote/issues/9) |
| KR-010 | [#10](https://github.com/felipebarbosa4/KidRemote/issues/10) |

## Existing GitHub Project reused

[KidRemote MVP, Project #3](https://github.com/users/felipebarbosa4/projects/3) was identified as the owner's intended Project from its linked repository, ten exact KR items, description and configured views. It was reused and normalized; no Project was created.

Verified state:

- owner: `felipebarbosa4`;
- visibility: private;
- repository link: `felipebarbosa4/KidRemote`;
- open, with ten items and no duplicate KR item;
- title normalized from `@felipebarbosa4's KidRemote MVP` to `KidRemote MVP`;
- every expected field exists: Status, Priority, Story Points, Iteration, Risk, Area, Platform, Decision Required, Work Type, Start Date and Target Date;
- Status has the exact six configured options; Work Type has Specification, Spike and Implementation;
- Iteration duration is seven days. Sprint 01 — Feasibility runs 2026-09-05 through 2026-09-11 with KR-001/002/003 assigned under the single-agent plan;
- all eight initial manifest-backed fields were populated for every issue; live execution now has KR-001/002 In Progress and KR-003–010 Backlog;
- Start Date and Target Date values remain unset; only the approved Sprint 01 Iteration is assigned to KR-001/002/003;
- pre-existing Size, Estimate and Phase fields and the `My items` view were preserved as compatible human configuration.

The other untitled Projects #1 (closed) and #2 (open) were not modified.

## Views and workflows

All five required named views exist. The Backlog view is now a table, already sorts by Priority, and exposes the requested fields while preserving compatible columns. Current Sprint is a Status board with `iteration:@current`. Architecture and Security & Policy are tables; Roadmap uses the roadmap layout.

GitHub's available API does not expose mutation inputs for view grouping/sorting or roadmap date-field mapping, and its workflow object exposes only name/enabled state—not trigger/action configuration. The exact UI-only verification and configuration steps are therefore listed in [PROJECT](PROJECT.md); they are not claimed complete.

## Evidence boundary

`node tools/validate.mjs` and `git diff --check` passed during reconciliation. No Android build, physical-device test, Play approval, Supabase/RLS integration test, load test, production backend or store submission exists.
