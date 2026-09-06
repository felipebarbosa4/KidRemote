# GitHub Project — KidRemote MVP

- **Goal:** Mirror repository work in a small, navigable GitHub execution backlog.
- **Context:** Repository felipebarbosa4/KidRemote is public with Issues enabled; the owner's existing private Project #3 is linked.
- **Constraints:** No false success reports or duplicate Project; preserve compatible human configuration and existing labels.
- **Done when:** Ten issues, labels, milestones and supported field values are verified, with UI-only Project work stated exactly.

## Capability and publication

On 2026-09-05 the active `gh` credentials had repository administration and `project` scope.
[Existing Project #3](https://github.com/users/felipebarbosa4/projects/3) was positively identified and reused; no Project was created.
All ten issues and their supported manifest-backed fields are populated. See [PUBLISHED](PUBLISHED.md) for the observed state and evidence limits.

Canonical configuration: [project.json](project.json). Canonical metadata/body manifest: [issues.json](issues.json).
The Project is private (the repository remains public) and its Iteration field is seven days. Sprint 01 — Feasibility runs
2026-09-05 through 2026-09-11 with the approved single-agent scope KR-001/002/003.

## Fields

| Field | Type | Exact values |
| --- | --- | --- |
| Status | Single select, existing built-in | Backlog; Ready; In Progress; In Review; Blocked; Done |
| Priority | Single select | P0; P1; P2; P3 |
| Story Points | Number | Recommended Fibonacci 1,2,3,5,8,13; GitHub numeric field does not enforce this set |
| Iteration | Iteration | Seven days; start date UNSPECIFIED |
| Risk | Single select | Low; Medium; High |
| Area | Single select | Product; Parent; Child Android; Backend; Sync; Security; Policy; Design; QA; Infra |
| Platform | Single select | Shared; Android; Backend; Fire OS; iOS; Windows |
| Decision Required | Single select | Yes; No |
| Work Type | Single select | Specification; Spike; Implementation |
| Start Date / Target Date | Date | Unset until approved; support future roadmap |

Work Type avoids an extra architecture label. Dates allow a real roadmap without inventing platform release commitments.
[Projects](https://docs.github.com/en/issues/planning-and-tracking-with-projects/learning-about-projects/about-projects),
[iterations](https://docs.github.com/en/issues/planning-and-tracking-with-projects/understanding-fields/about-iteration-fields).

## Exact views

1. Backlog: Table, exclude Status=Done, sort Priority ascending (options ordered P0→P3). Show Title, Status, Priority, Story Points, Risk, Area, Platform, Decision Required, Milestone and dependencies.
2. Current Sprint: Board, group Status, filter `iteration:@current`. Use seven-day Iteration field.
3. Architecture: Table, filter Work Type is Specification OR Spike, sort Priority.
4. Security & Policy: Table, label filter includes security OR privacy OR policy (use UI filter builder); sort Priority.
5. Roadmap: Roadmap layout, group Platform, date fields Start Date/Target Date; conceptual sequence Android → Fire OS → Apple → Windows.
   Date only committed work. KR-001/002 actual dates and KR-003's current Sprint target are recorded; leave KR-004–010 and future-platform
   dates unset until scheduled. Future research is in ADR-0007/milestones; no implementation dates or additional issues are invented.

The object filters in project.json describe UI configuration, not an undocumented GitHub query language.
Use GitHub's view filter builder for fields containing spaces and OR label selection.
[Roadmap configuration](https://docs.github.com/en/issues/planning-and-tracking-with-projects/customizing-views-in-your-project/customizing-the-roadmap-layout).

## Labels and milestones

Lean labels are the exact list in project.json: security, privacy, policy, needs-owner-decision, needs-device-test,
breaking-change, blocked, good-first-agent-task, area:parent, area:child-android, area:backend, area:sync, area:design,
platform:android, platform:fire, platform:ios, platform:windows.
Existing repository defaults remain; documentation is reused.
Milestones: Architecture & Feasibility; Android Alpha; Android MVP; Fire OS Beta; Apple Feasibility; Windows V2.
No due dates assigned.
[Labels](https://docs.github.com/en/issues/using-labels-and-milestones-to-track-work/managing-labels),
[milestones](https://docs.github.com/en/issues/using-labels-and-milestones-to-track-work/creating-and-editing-milestones-for-issues-and-pull-requests).

## Automation

Built-in workflows: item added → Backlog; issue closed → Done; reopened → Backlog.
Ready requires human dependency/decision checks; a label alone does not approve an ADR.
Optionally auto-add open repository issues after Project configuration; check available plan limits.
Disable auto-archive during feasibility. Do not auto-close security/policy spikes merely because a document PR merges.
No scheduled autonomous agent feature is configured.
[Built-in automations](https://docs.github.com/en/issues/planning-and-tracking-with-projects/automating-your-project/using-the-built-in-automations).

## Repeatable commands

From repository root:

```sh
node tools/validate.mjs
node tools/publish-planning.mjs
node tools/publish-planning.mjs --apply
node tools/setup-project.mjs
node tools/setup-project.mjs --apply
```

The issue publisher is repeatable: creates missing labels/milestones/issues, preserves existing ones, reports actual URLs and refuses ambiguous IDs.
The Project helper checks access, requires an existing exact-title Project, creates missing supported fields, links the repo,
reuses/adds issues and fills missing initial values without overwriting live progress. It will not create a Project implicitly. If another token lacks access, a human can run
`gh auth refresh -h github.com -s read:project -s project` interactively.

Manual completion/verification in Project settings (exact intent in project.json):
- Backlog: set the filter to exclude Done. Its table layout, Priority sort and fields are already configured.
- Architecture: use the UI filter builder for Work Type = Specification OR Spike, then sort by Priority.
- Security & Policy: use the UI filter builder for labels security OR privacy OR policy, then sort by Priority.
- Roadmap: group by Platform and map Start Date/Target Date. Keep unscheduled KR-004–010/future-platform dates unset until commitments exist.
- Verify workflow actions—not only their enabled names—are item added → Backlog, issue closed → Done and reopened → Backlog.
  The API exposed enabled workflow names but not action configuration; configure the missing reopened rule if the UI supports it.
- Verify any enabled auto-add workflow is restricted to the intended repository/open-issue filter; keep auto-archive disabled during feasibility.
- Keep KR-004/005 outside Sprint 01 unless measured capacity allows the documented stretch scope.
- Verify all ten items, field values, milestone links and dependency bodies; record Project URL/settings evidence here.

CLI/API source:
[gh project](https://cli.github.com/manual/gh_project),
[Project API](https://docs.github.com/en/issues/planning-and-tracking-with-projects/automating-your-project/using-the-api-to-manage-projects).
Form syntax:
[GitHub Issue Forms](https://docs.github.com/en/communities/using-templates-to-encourage-useful-issues-and-pull-requests/syntax-for-issue-forms).
