# Planning publication status

- **Goal:** Record the GitHub planning state that was actually observed and changed.
- **Context:** Reconciled against the repository manifests and GitHub on 2026-09-05.
- **Constraints:** Planning evidence is not implementation, policy approval, database-test or physical-device evidence.
- **Done when:** Published artefacts are mapped, machine-set values are verified, and the UI-only remainder is explicit.

## Repository planning artefacts

All intended repository artefacts from the interrupted publisher were present before this reconciliation:

- all 17 planned labels exist; existing GitHub default labels were preserved;
- all six planned milestones exist with no due dates;
- all ten KR issues exist as issues #1–#10; KR-001/002 are closed and KR-003–010 remain open;
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
- all eight initial manifest-backed fields were populated for every issue; live execution now has KR-001/002 Done, KR-003 In Progress and KR-004–010 Backlog;
- Sprint 01 execution dates are populated: KR-001/002 each ran 2026-09-05; KR-003 starts 2026-09-05 with target 2026-09-11.
  Start/Target Date remain unset for KR-004–010 until those items are scheduled;
- pre-existing Size, Estimate and Phase fields and the `My items` view were preserved as compatible human configuration.

The other untitled Projects #1 (closed) and #2 (open) were not modified.

## Views and workflows

All five required named views exist. The Backlog view is now a table, already sorts by Priority, and exposes the requested fields while preserving compatible columns. Current Sprint is a Status board with `iteration:@current`. Architecture and Security & Policy are tables; Roadmap uses the roadmap layout.

GitHub's available API does not expose mutation inputs for view grouping/sorting or roadmap date-field mapping, and its workflow object exposes only name/enabled state—not trigger/action configuration. The exact UI-only verification and configuration steps are therefore listed in [PROJECT](PROJECT.md); they are not claimed complete.

## Evidence boundary

`node tools/validate.mjs` and `git diff --check` passed during reconciliation. PR #13 later added an isolated KR-003 harness whose
compile, 12 JVM tests, lint, debug APK assembly and merged-manifest audit passed in
[run 33996873306](https://github.com/felipebarbosa4/KidRemote/actions/runs/33996873306).
That 2026-09-05 checkpoint contained no Android runtime evidence. It is superseded for physical status by the
[Mi 8 evidence](../test-plans/evidence/KR-003-MI8-2026-09-06.md): one initial successful post-fix expiry and ten successful independent checkpoint
cycles. This does not provide the 100-sample qualification, other-device/lifecycle/safety evidence, Play approval, Supabase/RLS integration tests,
load tests, a production backend or store submission. KR-003 remains open/In Progress; KR-004 remains Backlog.

## KR-003 publication — 2026-09-06

[Draft PR #16](https://github.com/felipebarbosa4/KidRemote/pull/16) holds the bounded Mi 8 fix/evidence and qualification automation branch.
Only stale context/status/results paragraphs of issue #3 were updated; existing acceptance checkboxes and other content were preserved.
[The evidence progress comment](https://github.com/felipebarbosa4/KidRemote/issues/3#issuecomment-5557545359) was posted and read back.
Project #3 was re-read: KR-003 In Progress, KR-004 Backlog. No duplicate issue/Project, new sub-issue, closure, merge or KR-004 work occurred.

Both CI jobs passed at source/build `d81f19a` in [run 34017273906](https://github.com/felipebarbosa4/KidRemote/actions/runs/34017273906).
The [owner-run bundle](../test-plans/evidence/KR-003-BUNDLE-2026-09-06.md) was copied and hash-verified in mounted Windows storage; physical
preflight/calibration/100-sample qualification remain **Not run**. This is a tooling/evidence handoff, not a completed feasibility gate.

## Subsequent calibration incident — 2026-09-06

The historical d81f19a handoff above was executed by the owner. [Mounted evidence](../test-plans/evidence/KR-003-CALIBRATION-2026-09-06.md)
records one successful physical expiry plus same-session Home/Settings PASS, but an uncorroborated recovery oracle and zero-row reporting defect.
No qualification row began. Android-side disagreement and final radio state remain **UNSPECIFIED**. Q2 tooling repairs require a new immutable
calibration-only handoff; no issue closure, PR readiness, KR-004 implementation or policy acceptance follows from those repairs.

Q2 source `37ad70b177d84d21250887c4b75e33c1b6d328af` passed all three jobs in
[CI run 34048490604](https://github.com/felipebarbosa4/KidRemote/actions/runs/34048490604), including 65 Windows PowerShell 5.1 assertions with
stubbed device calls. The [new immutable bundle/hashes/operator command](../test-plans/evidence/KR-003-Q2-BUNDLE-2026-09-06.md) was independently
verified after packaging. Its new physical calibration is **Not run**; the old bundle/run were not overwritten.

Issue #3's Context/Results/Next paragraphs and
[progress comment](https://github.com/felipebarbosa4/KidRemote/issues/3#issuecomment-5560924249) were published and read back; all acceptance
checkboxes were preserved. KR-003 is Open/In Progress and KR-004 Open/Backlog. PR #16 remains draft/Open; no closure, merge or KR-004 change occurred.
