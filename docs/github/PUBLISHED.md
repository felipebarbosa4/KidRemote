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

## Q2 physical Settings/recovery failure — 2026-09-06

The earlier Q2 NOT_RUN handoff is now historical. The owner executed the immutable `37ad70b` bundle; the finalized run is a
**physical Settings/recovery FAIL:OBSERVER_4**, not an oracle-only INVALID. Expiry and Home PASS remain separate; no 100-sample qualification
began. Sixteen original artefacts were read directly and hash/size verified; both zero-row summaries exist, finalization errors are empty and
Wi-Fi/mobile flags were restored/read back 1/0. This does not establish connectivity or retroactively verify Q1 restoration.

The [preserved Q2 evidence and proposed diagnostic](../test-plans/evidence/KR-003-Q2-SETTINGS-2026-09-06.md) was committed/pushed as
`bd5aa37b032ee6ae683e9f7f6eb6f7ce43cc73d3`. Issue #3's Context/Results/Incident/Next paragraphs, PR #16's incident/handoff paragraphs and
[the new evidence comment](https://github.com/felipebarbosa4/KidRemote/issues/3#issuecomment-5561492498) were updated and read back exactly.
All issue acceptance checkboxes and unrelated content were preserved. Project status was verified: KR-003 Open/In Progress, KR-004 Open/Backlog;
PR #16 Open/draft. No closure, merge, new issue/Project, KR-004 work or production policy change occurred.

The current candidate cannot qualify. Labelled per-destination/per-button diagnostics with existing coarse telemetry and a verified lab-only
CLEAR bailout are **proposed**, not implemented or run. Any new identity collection requires narrow review; no guessed OEM allowlist or
lowered SAFE requirement is authorized. The existing APKs, runner, bundle and original physical artefacts remain unchanged.

Evidence commit `bd5aa37` passed all three jobs in [CI run 34053924704](https://github.com/felipebarbosa4/KidRemote/actions/runs/34053924704):
repository/Node/synthetic runner checks, Windows PowerShell runner checks with device calls stubbed, and Android JVM tests/debug-release
lint/build/manifest/DEX audit. These automated results do not change the physical Settings FAIL or provide Play acceptance.

## Q3 focused recovery diagnostic handoff — 2026-09-06

Source `53327c50afb97c66620dd15780114b6f1a13ec33` implements the diagnostic-only, four-phase Settings/Digital Wellbeing/recovery checkpoint and
lab-only CLEAR bailout without changing Android enforcement policy. It passed all three jobs in
[CI run 34056094159](https://github.com/felipebarbosa4/KidRemote/actions/runs/34056094159), including native Windows PowerShell 5.1 synthetic tests,
Android debug/release isolation checks and repository validation. Device calls were stubbed; this is not physical evidence.

The [immutable Q3 bundle, hashes and exact owner command](../test-plans/evidence/KR-003-Q3-DIAGNOSTIC-BUNDLE-2026-09-06.md) were independently
verified in mounted Windows storage. Issue #3's stale Next paragraph, PR #16's handoff and
[the Q3 progress comment](https://github.com/felipebarbosa4/KidRemote/issues/3#issuecomment-5561778844) were published and read back while preserving
all seven acceptance checkboxes. Physical execution is **Not run**. KR-003 remains Open/In Progress, PR #16 remains Open/draft and KR-004 remains
Open/Backlog. No qualification, enforcement-policy change, OEM allowlist or Play acceptance is claimed.

## Q3 physical recovery result — 2026-09-06

The owner executed the immutable Q3 bundle. [Preserved evidence](../test-plans/evidence/KR-003-Q3-RECOVERY-2026-09-06.md) records one expiry PASS,
top-level Settings PASS, Digital Wellbeing FAIL with phase-local ORDINARY_APP reattachment, and recovery-button physical FAIL. Two handler
activations make the single-attempt software oracle invalid; they do not erase the physical failure. The automatic lab CLEAR released the
restriction and preserved both latency samples. Zero qualification rows began, and no Home result was added.

Existing coarse telemetry answered the disposition question, so no equality/identity diagnostic or package allowlist was added. Exact task and
component behaviour remains **UNSPECIFIED**. KR-003 remains Open/In Progress, PR #16 remains draft and KR-004 remains untouched.

## Q4 bounded recovery-repair handoff — 2026-09-06

Exact source `768aaa039ac4c774896f708591ac30d218405e39` adds only `FLAG_ACTIVITY_CLEAR_TOP` to the existing top-level Settings launch after Q3
established transient NEW_TASK-only recovery. It does not change surface classification, allowlists, permissions or Accessibility collection.
[CI run 34057645951](https://github.com/felipebarbosa4/KidRemote/actions/runs/34057645951) passed all three jobs, including native Windows
PowerShell 5.1 and Android debug/release isolation checks; device calls were stubbed.

The [immutable Q4 bundle, hashes, protocol and exact command](../test-plans/evidence/KR-003-Q4-BUNDLE-2026-09-06.md) were independently verified
in mounted Windows storage. Physical execution is **Not run**. The repair remains unproven, 100 samples remain blocked, KR-003 remains Open/In
Progress, PR #16 remains draft and KR-004 remains untouched. Issue #3 and PR #16 were read back after publication; all seven issue acceptance
checkboxes remain present. The [Q3 ingestion/Q4 handoff comment](https://github.com/felipebarbosa4/KidRemote/issues/3#issuecomment-5561946765)
records the same evidence boundary. Current-head [CI run 34057870919](https://github.com/felipebarbosa4/KidRemote/actions/runs/34057870919)
passed all three jobs; its device calls were stubbed and do not constitute physical Q4 evidence.

## Q4 physical recovery failure — 2026-09-06

The owner executed the immutable Q4 bundle. [Preserved evidence](../test-plans/evidence/KR-003-Q4-RECOVERY-2026-09-06.md) records expiry/root PASS,
expected Digital Wellbeing blocking and a single recovery-button physical FAIL. The safe transition lasted only 681 ms before `ORDINARY_APP`
returned and the overlay reattached, matching the observed approximately one-second Settings flash. Zero qualification rows began; lab CLEAR
passed and network state was not changed. `NEW_TASK | CLEAR_TOP` is rejected for this Mi 8 route. Publication to issue #3/PR #16 is pending.
