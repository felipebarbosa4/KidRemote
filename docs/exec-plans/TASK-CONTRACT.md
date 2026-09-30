# Task contract

- **Goal:** Advance the next approved, observable KidRemote product outcome with bounded agent autonomy and defensible evidence.
- **Context:** Repository implementation and accepted decisions govern work; GitHub Issues/PRs mirror execution. Initial architecture is not an instruction to remain in planning indefinitely.
- **Constraints:** One existing KR workstream at a time; smallest coherent change; preserve consent, privacy, independent observations, historical evidence and explicit approval boundaries.
- **Done when:** The scoped result and executed validation are recorded, remaining gates are explicit, and the next agent can continue without reconstructing historical permissions.

## Current execution

**Current handoff: BLOCKED_PENDING_INTERRUPTED_ENROLLMENT_REVIEW.** The owner scanned the source-de6a488 QR, stopped execution and supplied three refused repeats. The [durable interrupted-attempt review](../test-plans/evidence/PRODUCT-ENROLLMENT-INTERRUPTED-2026-09-30.md) records one unfinished journal, three independent refusals and a task-owned backend snapshot with zero devices. The source-de6a488 product command is retired from further execution; do not delete/finalize its journal, reset state or add a recovery exception to bypass the review. No new product-run command is published.

**Access and diagnosis:** repository/host-data access works. Nested callback creation lost constructor variables; callbacks are now created in the constructor scope and regression-tested. This demonstrates a concrete harness defect, but the original physical exception was not retained: its exact causal path remains INFERRED. The separate host-only pairing probe, synthetic callback chain and headless PNG result do not establish successful physical enrollment or enforcement.

Routing originally reconciled against implementation baseline `e066e87df50c03fa25a8df78f0135fe5b4505428`; the subsequently published 062fd59 handoff is now retired as described above. These are historical source references, not instructions to reset. Re-read live refs and intervening changes on resumption. A documentation commit does not rebuild or requalify an APK/bundle.

**Development branch:** `kr-product-enforcement-integration`. **Existing PR:** [#24](https://github.com/felipebarbosa4/KidRemote/pull/24), draft, targeting `kr-010-local-parent-controls`. Existing product issues remain #3/#10; scaffold maintenance belongs to #2, without reopening its completed original acceptance. `main` is a bootstrap checkout, not the current local product stack.

**Product outcome:** advance the existing connected parent/child product toward authenticated controls and independently demonstrated local restriction/recovery. Continue the [pairing-cleanup callback recovery workstream](PRODUCT-PAIRING-CLEANUP-CALLBACK-RECOVERY.md) at the newer attempt-review blocker above, not a new diagnostic framework, a repeat of the initial architecture pass, or optional visual automation.

**Latest ingested physical-attempt record (unfinished; not a verdict):** [Latest physical record](../test-plans/evidence/PRODUCT-ENROLLMENT-INTERRUPTED-2026-09-30.json).
Attempt `685624ea-8f7d-4d0f-8235-5b9a79bd261b`, source `de6a4882488f9dd19b5ad7b7470bcd76754345fd`, has four complete chained rows ending at ENROLLMENT_ADMITTED. Primary status, reason and cleanup are each `NOT_RECORDED`: no VERDICT/CLEANUP/result.txt exists. The three subsequent diagnostic INVALID results do not replace the original missing verdict. Backend metadata showed zero devices and one new unconsumed/uncancelled session, expired at review time; Android identity/pending metadata and current tunnel cleanup remain UNKNOWN. The earlier [236b1c2b review](../test-plans/evidence/PRODUCT-PAIRING-SESSION-REVIEW-2026-09-30.json) remains unchanged.

The former b541595 READY_FOR_ONE_OWNER_RUN / NOT_RUN handoff remains superseded. Do not republish it. Replacement-bundle readiness must be established from an exact immutable manifest, source/APK identities, required validation, reviewed current history and live preflight; this summary supplies no replacement command or physical-run authorization of its own.

**Next action:** one owner-operated execution of the existing immutable read-only metadata probe identified in the interrupted-attempt review and PR #24. Its source is `8ebcc89e0b483af1f5d3cf3a081fca640da37e10`, manifest `e4d8ab75d9b6c44ca08d3c5cb3958e3992afa4a254518f4fdebb450ba0cc29ee`; all 489 listed file hashes were reverified. This is not a product-run retry, enrollment, QR regeneration or reset. The agent must not execute physical ADB. Preserve any reverse/provenance failure; no automatic tunnel removal or rerun. Review the resulting local structural metadata before choosing recovery.

**Still open:** KR-003 full qualification and safety/lifecycle/support boundary; product-binary physical acceptance; real-family-use and deployment/distribution decisions; external Play acceptance. The Samsung evidence is for the recorded SM-X400 configuration only. Mi 8 evidence is separate. A lab integration slice does not close these gates.

## Authority and supersession

[DECISIONS](../DECISIONS.md) is the current decision index; its preserved ledger contains the detailed accepted scopes. Code/tests determine what exists and what was actually exercised. They cannot authorize a device operation or accept a product risk. A plan or agent statement cannot supply an owner approval.

The accepted OD-42 through OD-49 exceptions allow their specified local development despite open KR-003 acceptance. OD-50/51 and their explicit extensions govern only their stated synthetic lab resources and actions. They do not create blanket permission for other devices, resets, host repair, real data, release or merge. Later explicit amendments supersede only named restrictions; a date alone does not resolve incompatible authority.

Dated Sprint 01 entries, the September 10 KR-003 remaining-work reset, old tooling inventories, historical handoffs and external CURRENT_STATUS/chat summaries are historical context. Their old “do not start KR-004” or “prepare then stop” statements do not revoke subsequent explicit scoped approvals. Their unresolved safety/acceptance requirements remain open unless explicitly amended. Preserve history rather than rewriting results.

This summary is a routing index, not a new ADR, owner go/no-go, or machine policy engine. Update it in the same change that changes the active task/authority; never silently infer a broader grant.

## Operating loop

Record Goal / Context / Constraints / Done when in the existing task plan or PR. Include the product dependency advanced, approved resources/actions, exact validation and genuine stopping point. A small fix does not need a new plan, issue or ADR when the existing workstream already covers it.

Inspect -> implement the smallest coherent change -> run relevant tests -> review the diff -> record classified evidence -> commit/push when authorized -> synchronize the existing Issue/PR. Preserve dirty work and use bounded recoverable commits. Do not merge existing draft PRs, rewrite their history, or close acceptance issues merely because local tests pass.

Continue routine safe repository-local work within approved architecture without asking the owner to choose already-resolved engineering details. For a failure, preserve the attempt and stop that experiment; perform only already-authorized non-destructive diagnosis. Do not automatically repeat a physical trial, replace failed rows, pool observations or widen scope. Before adding tooling, name the unresolved product dependency and why existing tools cannot resolve it. A frozen handoff is an intermediate result, not the product definition of done.

Stop for a real consent/observation boundary, unavailable required execution environment, unapproved destructive/external action, genuine architecture/product choice, or evidence rejecting the approach. Report completed work, what the evidence proves, what remains unknown, and one exact next action with expected result and failure condition. Specify Windows PowerShell, WSL, or device context for commands. Do not repair WSLInterop or request sudo/passwords.

## Verification routing

Run commands from the checkout root in a repository-local shell. Use the existing pinned tools; select new versions only when a change requires verification. Check the actual host instead of treating a dated inventory as permanent capability.

| Change | Required validation route; evidence limit |
| --- | --- |
| Guidance/planning | `node --test tools/validate-guidance.test.mjs`, `node tools/validate.mjs`, `git diff --check`; routing/contracts only |
| Backend/RLS/pairing | [Local database checks](../../tools/kr004/check-local.mjs), [database tests](../../supabase/tests/README.md); execute only against verified task-owned synthetic resources, never a real-data reset |
| Parent/child app | [Parent build/runtime](../../apps/parent-mobile/README.md), [child](../../apps/child-android/README.md), component tests and release-isolation audits; compiled instrumentation is not executed Android evidence |
| Accounting/sync/controls | [KR-008](../../tools/kr008/README.md), [KR-009](../../tools/kr009/README.md), [KR-010](../../tools/kr010/README.md); keep JVM, actual DB/HTTP, emulator and physical results separate |
| Windows host/runner | [Product oracle](../../tools/enforcement/product-oracle/README.md) and current recovery contract; required native PowerShell 5.1/7, backend and privacy/isolation regressions before bundle freezing |
| Physical enforcement | Exact authorized immutable runner, target, live preflight, independent fixture/input/focus and required human observations; no acceptance inferred from source/ACK/build |

The [existing CI](../../.github/workflows/planning.yml) remains intact. This reconciliation does not remove historical regression suites or lower required gates. The additional guidance check is path-filtered. CI success is not physical acceptance, and historical successful CI is not a result for a new commit.

## Evidence and diagnostics

Separate specified, implemented, executed and approved. Classify observations as OBSERVED, INFERRED or UNKNOWN / UNSPECIFIED. Retain original FAIL/INVALID outcomes and cleanup status independently. Use synthetic identifiers in shared evidence; never log JWTs, credentials, QR payloads, raw sensitive stderr, device serials, content or broad app history.

Host stages must retain bounded, nonsecret failure-stage/code and cleanup information sufficient for diagnosis. Add negative tests at process/callback boundaries. Do not replace typed diagnostics with one generic sanitized exception, or weaken privacy to recover missing historical details. Existing missing evidence stays unknown.

External project prompts and optional tool adapters should point to AGENTS and this current summary rather than copy devices, commits or changing task permissions. GitHub edits cannot update an external chat's settings or Project attachments.
