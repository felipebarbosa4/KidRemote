# Task contract

- **Goal:** Advance the next approved, observable KidRemote product outcome with bounded agent autonomy and defensible evidence.
- **Context:** Repository implementation and accepted decisions govern work; GitHub Issues/PRs mirror execution. Initial architecture is not an instruction to remain in planning indefinitely.
- **Constraints:** One existing KR workstream at a time; smallest coherent change; preserve consent, privacy, independent observations, historical evidence and explicit approval boundaries.
- **Done when:** The scoped result and executed validation are recorded, remaining gates are explicit, and the next agent can continue without reconstructing historical permissions.

## Current execution

**Current handoff: RETAINED_SYNC_OBSERVER_IMPLEMENTED; FINAL_VALIDATION_PENDING.** The existing host harness now has a distinct retained-enrollment synchronization observation, not another product trial or generic inventory. It composes exact history/device/APK/retry checks, retained-only backend startup, one fixed reverse and normal app resume, and authenticated parent report reads. The original 30-second finding remains separate from a maximum six-minute diagnostic window. No new target policy, enrollment, permission change or retry-state write is available. Normal app synchronization may persist and enforce the already-configured policy, so this is not a read-only device experiment.

**Access and diagnosis:** the exact top-activity launch produced another resume and sync in the tested emulator, including the service-enabled real backend case. A controlled 45-second retained deadline exceeded the 30-second initial window, then automatically converged without clearing retry state. This proves a possible timeout condition, not the cause of the original Samsung attempt. Both real connected runs observed policy/report version 1 and local ACK confirmation; neither tests physical input denial. Original Samsung enrollment/policy and all historical outcomes remain unchanged. The existing emulator is stopped; new synthetic backend leases were removed without touching the original lease.

Routing originally reconciled against implementation baseline `e066e87df50c03fa25a8df78f0135fe5b4505428`; the subsequently published 062fd59 handoff is now retired as described above. These are historical source references, not instructions to reset. Re-read live refs and intervening changes on resumption. A documentation commit does not rebuild or requalify an APK/bundle.

**Development branch:** `kr-product-enforcement-integration`. **Existing PR:** [#24](https://github.com/felipebarbosa4/KidRemote/pull/24), draft, targeting `kr-010-local-parent-controls`. Existing product issues remain #3/#10; scaffold maintenance belongs to #2, without reopening its completed original acceptance. `main` is a bootstrap checkout, not the current local product stack.

**Product outcome:** advance the existing connected parent/child product toward authenticated controls and independently demonstrated local restriction/recovery. Continue the [pairing-cleanup callback recovery workstream](PRODUCT-PAIRING-CLEANUP-CALLBACK-RECOVERY.md) at the newer attempt-review blocker above, not a new diagnostic framework, a repeat of the initial architecture pass, or optional visual automation.

**Latest ingested physical-attempt record:** [Latest physical record](../test-plans/evidence/PRODUCT-INITIAL-REPORT-TIMEOUT-2026-09-30.json).
Attempt `8e407e8b-eddb-4d65-b1bc-1819155b1d52`, source `452396d834dd76410a72094bd1e3e27e3c2954df`, has eight valid chained rows including SETUP_ADMITTED and POLICY_ADMITTED, then `INVALID` / `INITIAL_REPORT_TIMEOUT` / slice cleanup `NOT_REQUIRED`. No Lock/Unlock or independent positive/blocked/restored observation was recorded. The configured initial allowance is still retained; NOT_REQUIRED is not a state reset or independent unlock proof. The result's preparation flags refer to pre-enrollment, and expectedVersion=0 is not the observed backend version. Earlier unfinished/INVALID records remain unchanged.

The former b541595 READY_FOR_ONE_OWNER_RUN / NOT_RUN handoff remains superseded. Do not republish it. Replacement-bundle readiness must be established from an exact immutable manifest, source/APK identities, required validation, reviewed current history and live preflight; this summary supplies no replacement command or physical-run authorization of its own.

**Next action:** complete exact-source CI and immutable freezing for `Observe-SyncReadiness.ps1` using the existing physical-lab freezer's `--sync-readiness` mode. Do not pass this observer to the product-slice runner, add a configured-state recovery exception, recreate a missing lease or clear data. First require the pinned original timeout inventory and unchanged prior history; compare the saved/backend device, epoch, version and pairing sessions. Read only the approved bounded retry projection before connecting. A fresh report must advance sequence from the pre-connection baseline, match the existing version/current period and pass server-time freshness. Its result is OBSERVED or INCOMPLETE/INVALID, never physical enforcement PASS. Physical ADB remains owner-operated; publish one exact command only after final source validation and all-file bundle verification. Safe host work remains autonomous.

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
