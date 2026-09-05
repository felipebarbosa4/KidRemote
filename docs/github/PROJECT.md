# GitHub Project — KidRemote MVP

- **Goal:** Mirror repository work in a small, navigable GitHub execution backlog.
- **Context:** Repository felipebarbosa4/KidRemote is public with Issues enabled; authenticated repository administration is available.
- **Constraints:** No false success reports; preserve existing labels; no Project scope escalation performed automatically.
- **Done when:** Ten issues, labels and milestones are created where authorized, and unavailable Project operations have exact repeatable setup.

## Capability and publication

Current gh token has repo/workflow scopes but lacks **read:project** and **project**.
The read-only Project-list check returned the explicit missing-scope error. Project creation is unavailable with current credentials.
No GitHub Project, fields, views, iterations or automation have been created by this pass.
See [PUBLISHED](PUBLISHED.md) for actual issue/milestone/source publication results.

Canonical configuration: [project.json](project.json). Canonical metadata/body manifest: [issues.json](issues.json).
Defaults: private Project (repository remains public), weekly seven-day iterations, start date **UNSPECIFIED**.
The owner confirms iteration dates before assigning a live sprint.

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
   Leave dates unset. Future research is in ADR-0007/milestones; no implementation dates or additional issues are invented.

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

## Exact human apply commands

From repository root:

```sh
node tools/validate.mjs
node tools/publish-planning.mjs
node tools/publish-planning.mjs --apply
gh auth refresh -h github.com -s read:project -s project
node tools/setup-project.mjs
node tools/setup-project.mjs --apply
```

The auth command requires the human's interactive authorization; it was not run.
The issue publisher is repeatable: creates missing labels/milestones/issues, preserves existing ones, reports actual URLs and refuses ambiguous IDs.
The Project helper checks access before mutation, creates/reuses title, creates missing supported fields, links the repo,
adds issues and sets available fields. It deliberately reports all manual remainder; no unsupported API syntax is invented.

Manual completion in Project settings (exact data in project.json):
- Edit existing Status options to the six values above; do not add a second Status field.
- Add Iteration, duration one week, owner-selected start; GitHub creates initial iterations. Name first “Sprint 01 — Feasibility”.
- Create the five views above and built-in workflows.
- Re-run helper to populate statuses once options exist.
- Assign KR-001–005 to Sprint 01 only if capacity/decisions permit; otherwise use the single-contributor scope in SPRINT-01.
- Verify all ten items, field values, milestone links and dependency bodies; record Project URL/settings evidence here.

CLI/API source:
[gh project](https://cli.github.com/manual/gh_project),
[Project API](https://docs.github.com/en/issues/planning-and-tracking-with-projects/automating-your-project/using-the-api-to-manage-projects).
Form syntax:
[GitHub Issue Forms](https://docs.github.com/en/communities/using-templates-to-encourage-useful-issues-and-pull-requests/syntax-for-issue-forms).
