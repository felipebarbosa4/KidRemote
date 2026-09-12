# Sprint 01 — Architecture and feasibility (one working week)

## KR-007 camera and identity-storage continuation — OD-45

### One owner-operated physical invalid-camera preparation

- **Goal:** prepare the existing verified child APK and nonsecret `{}` QR for one Samsung SM-X400 camera -> decode -> schema rejection check.
- **Context:** clean `6ab4ba0`; published focused camera evidence remains NOT_PASSED. OD-45 now explicitly permits owner-only physical execution, not agent operation.
- **Constraints:** no rebuild/new framework/backend/endpoint change; package already present means STOP, no update/data mutation. No KR-003 operation, media/log capture, real enrollment, physical acceptance closure or KR-008. Only manually granted camera access on a new installation.
- **Done when:** hashes/package/permissions/QR verified, bounded owner commands checked locally, existing decision extended, and handoff stops before all physical operations. [Owner checklist](../test-plans/KR-007-PHYSICAL-INVALID-CAMERA.md) separates observed UI/camera release from read-only identity-file checks and source-derived no-redemption reasoning.

### Focused invalid-camera boundary pass

- **Goal:** isolate camera open -> analyzer -> conversion -> decode -> schema rejection -> UI for the nonsecret `{}` QR only.
- **Context:** clean `ee4c997`, PR #20; historical 23 PASS/one failed attempt and APKs remain unchanged. OD-45 already authorizes this diagnosis; no new decision.
- **Constraints:** approximately 20 minutes of acquisition investigation excluding builds/CI, one owned AVD, no backend unless this control passes; memory-only debug counters, no frames/payload/exception retention, webcam, pose invention or capture analysis.
- **Done when:** a focused executed pass identifies the last established boundary and any reproduced defect is fixed/tested, or the unresolved boundary is retained with one proposed future physical check (not executed). No full storage rerun or wider scope.

**Focused result:** [retained two-attempt record](../test-plans/evidence/KR-007-CAMERA-STORAGE-2026-09-11.md#focused-follow-up--2026-09-12-utc): the byte-verified PNG passes separate synthetic decode/schema control; actual camera opens and delivers/converts 922 frames, but decodes zero QR. Model/schema/UI rejection was never reached; COMPOSE_TIMEOUT with scanning UI remains NOT_PASSED. Poster-in-view is UNSPECIFIED; official default-pose/framing guidance supports a stimulus-placement hypothesis, not an app-defect conclusion. A new isolated PNG-precheck binary-stdin truncation was corrected using nonsecret staging plus exact-byte verification; historical evidence unchanged. No backend or valid-camera redemption started. AVD/data/posters/staging cleanup verified. Stop emulator investigation here; one proposed future explicitly authorized brief physical invalid-QR check, not automatic installation or another framework.

- **Goal:** execute actual virtual-camera/permission and Keystore failure tests; fix reproduced defects only.
- **Context:** clean `c9843000e8ec0586a20a532e3c9e70a972a1b64e`, existing draft PR #20 stacked on #19; preserve exercised `fb52936` APKs and all prior results. Initial-read gateway uses real DB storage.
- **Constraints:** same owned Windows AVD and synthetic local services; no webcam/physical target, frame retention/upload, general camera simulator, enforcement, rotation/removal expansion or next issue. Generated scene images remain local. Original APKs untouched.
- **Done when:** available camera path and permission/storage failures have executed evidence, focused regressions/build/lint/isolation/CI pass, resources cleaned, and camera/OEM/physical gaps remain explicit. If virtual camera is unavailable, retain the precise limitation and finish independent permission/storage tests.

**Bounded result:** [camera/storage evidence](../test-plans/evidence/KR-007-CAMERA-STORAGE-2026-09-11.md) records 23 passing actual Android invocations and one failed virtual-scene invalid-QR control; the valid camera QR path remains unrun, not substituted by decoder injection. Real permission denial/grant, cancellation/background/recreation, OS revocation/restart, ciphertext corruption/missing key/clean reinstall and real gateway-outage preservation passed. Fixed reproduced missing-key read mutation (no replacement key on read); actual auth/read gates unchanged. All backend regressions and source `01c6264` CI passed; overall camera runtime remains NOT_PASSED. Cleanup verified and owned AVD stopped. Earlier failures and `fb52936` APKs preserved. AC-2/3/4 remain partial, AC-6/7/physical/OEM pending. Next bounded step is review of these results and the unresolved native virtual-scene acquisition boundary, not another framework, physical installation, rotation/removal expansion or KR-008.

## KR-007 first local enrollment — OD-45, 2026-09-11

- **Goal:** authenticated parent QR -> real child redemption -> persisted independent identity -> own initial read -> actual parent list.
- **Context:** clean `a4d6beb58368318ada2d3f9d505d9e404f789e85`; new `kr-007-local-enrollment` stacked on unmerged PR #19. Reuse KR-005 transactions/handler and KR-006 Auth/Windows AVD/runtime infrastructure. OD-45 is separate from OD-44.
- **Constraints:** synthetic local resources only; explicit emulator target; no enforcement/privileges, physical install, deployment, real use, next issues or visual work. No raw secrets/media in logs/arguments/artifacts. Unknown/unconfigured is not zero allowance or healthy/protected. Camera decoding tests are distinct from camera scanning.
- **Done when:** two actual apps sequentially exercise connected local enrollment with real gateway persistence and scoped read, regressions/build/lint/security/runtime evidence retained; or exact genuine blocker. Remaining camera/physical, rotation, removal/transfer acceptance stays partial.

Implement only initial unconfigured-policy projection; configured/sync-engine operations
remain unavailable rather than synthesized. Parent Auth routes use actual verified JWT
and existing membership-scoped RPCs. Device adapter holds credential/device/policy locks
through handler authorization/read in one actual PostgreSQL transaction. Reuse local
debug endpoints and capture only sanitized results. Stop after this connected slice.

**Executed result:** [KR-007 local enrollment evidence](../test-plans/evidence/KR-007-LOCAL-ENROLLMENT-2026-09-11.md): real parent UI -> QR -> child decoder/redemption -> Keystore identity -> initial scoped read -> real parent list passed, then committed interruption/revoke/fresh-QR recovery. Fifteen instrumentation invocations passed on one owned Windows API-36 emulator, sequential app identities; 496 SQL, 44 Auth and 28 new enrollment HTTP/DB assertions passed alongside existing pairing regressions. The initial install failure and two manifest-audit CI failures are preserved separately. Actual APK source is `fb52936`, host source `b6087c3`; prior KR-006 APKs unchanged. Cleanup verified, AVD stopped. AC-1/5 demonstrated locally; remaining camera/physical, transfer, permission/removal and rotation criteria stay open. PR #20 stays draft/stacked on PR #19. Next bounded step: review this slice, then plan the remaining KR-007 camera/identity lifecycle acceptance within explicit authorization; no automatic KR-008/009/010 or enforcement.

- **Goal:** Establish an approved product contract and evidence-based Android/backend/pairing path.
- **Context:** Architecture baseline merged in PR #11; owner directed execution to start on 2026-09-05; production enforcement is unproven.
- **Constraints:** Seven calendar days ending 2026-09-11, no full MVP promise. One active coding agent; physical-device inventory and availability remain **UNSPECIFIED**.
- **Done when:** Product gates reviewed, repository checks pass, feasibility evidence has a go/no-go, RLS and pairing designs are testable.

## KR-004 AC-1–4 limited GO — 2026-09-10

- **Goal:** implement versioned local schema migrations and actual database isolation tests for KR-004 AC-1–4 only.
- **Context:** OD-42 records the explicit prospective owner exception. Verified starting HEAD `2f5be2fb8d62eae3aeaf8a8662b0e976844db904`, clean worktree. No existing KR-004 branch/PR was found. Work is isolated on `kr-004-local-schema-rls`, stacked on `kr-003-mi8-overlay-stability` at that commit; its PR diff excludes inherited KR-003 changes. PR #16 is not merged or rewritten.
- **Constraints:** task-owned disposable local DB and synthetic identities only; no remote DB, unrelated container/volume, host privilege/service change, cloud setup, deployment, real user data, ADB or capture. No new product semantics, control/gateway implementation, KR-005/006, private-use approval or production enforcement. AC-5–7 remain outside the approved slice.
- **Done when:** empty-DB migrations enforce keys/tenant constraints/indexes, RLS/minimum grants/private isolation, and real local authenticated/anonymous-role tests cover own/foreign access, writes/joins/existing RPCs, self-promotion, null auth, missing policy and removed membership; executed evidence and CI are recorded. If no local DB runtime is available, report the precise prerequisite and leave AC-1–4 unchecked.

**Historical result (2026-09-10): BLOCKED before migration implementation/execution.** WSL has no `psql`, `postgres`, `initdb` or Supabase CLI; its Docker shim reports missing WSL integration. The existing Windows Docker client is available (29.6.2), but `docker.exe version --format '{{.Client.Version}} {{.Server.Version}}'` fails: local `dockerDesktopLinuxEngine` named pipe is absent. Windows command discovery also finds no PostgreSQL server/client or Supabase CLI. No engine was started, integration enabled, privilege changed, container inspected/mutated, DB reset or mock database used. See [KR-004](../github/issues/KR-004.md#local-prerequisite-evidence--2026-09-10).

Required unblock: owner makes the existing local Docker Desktop **Linux engine** available (or supplies an already available authorized local PostgreSQL toolchain). The native Windows Docker client can be checked without requiring WSL integration changes. Do not start shared infrastructure automatically, since it may resume unrelated containers. Once available, reverify local endpoint and allocate only a uniquely named task-owned disposable target; do not reset any pre-existing database/container. Continue this same slice, not another roadmap task. No database PASS or AC completion is recorded.

The earlier reset's proposed hold-lifting language below is superseded **only for AC-1–4** by OD-42. Its private-alpha/support proposal and all later issue gates remain unapproved.

### Execution resumed — 2026-09-11

The owner started Docker Desktop. The agent independently executed the native Windows client with explicit `--host npipe:////./pipe/dockerDesktopLinuxEngine`: `info --format '{{.OSType}}'` returned `linux` (exit 0). This supersedes the runtime blocker above, not historical evidence. HEAD/worktree verified at `8fe80eb`, clean; existing draft PR #17 retains its KR-003 branch base.

Continue OD-42 AC-1–4 now: pin the official Supabase PostgreSQL image, allocate a uniquely labelled disposable container with no network/host ports, verify its ID/label/image/database and empty application schema before migrations, and run SQL allow/deny tests as actual anon/authenticated roles with synthetic claims. No Auth HTTP server, gateway, control RPC or production exposure is introduced. Record actual results separately from this execution plan. Cleanup may remove only the newly allocated, verified task container and its own ephemeral data.

**Executed result:** versioned schema/RLS migration passed on the pinned Supabase PostgreSQL 17.6 image, then 243 real-role RLS/grant and 45 structural assertions passed with no skips. Ten Node orchestration guard tests passed. Exact disposable identity and cleanup plus corrected development failures are in [KR-004 execution evidence](../test-plans/evidence/KR-004-LOCAL-DB-2026-09-11.md). This supersedes the historical runtime-blocker statements above. AC-1–4 are locally complete; KR-004 stays In Progress with AC-5–7 open. Required CI includes a new actual DB job and unchanged existing jobs. Stop at the OD-42 boundary: the next bounded proposal is KR-004 AC-5 gateway authorization tests/implementation, only after owner approval; do not start KR-005/006 or production enforcement.

### KR-004 AC-5–7 authorized continuation — 2026-09-11

- **Goal:** finish local AC-5 gateway authorization, AC-6 atomic control and AC-7 reproducible validation, in that order.
- **Context:** OD-42 extension is explicit and prospective. Clean HEAD `80c68faa3df07b9977ed423845037bd1e886a52e`, existing stacked draft PR #17 verified; native Windows client independently returned `linux` from the explicit local named pipe. AC-1–4 migrations/tests/evidence are retained.
- **Constraints:** task-owned local DB and synthetic identities only; no remote DB, real accounts, deployment, paid/host privilege changes, shared reset, device/capture work, KR-005/006 or production enforcement. HTTP test listeners bind loopback only. Label repository/transport stubs separately from actual handler decisions and SQL evidence.
- **Done when:** own-device and sibling/foreign/credential/privilege HTTP cases pass through the actual handler; real SQL proves authorization, rollback, idempotency and concurrency; original RLS regressions pass; guarded fresh-db/reset instructions and required CI pass, with executed/unrun boundaries explicit.

Implement bounded commits for gateway, transaction and final validation/publication. Earlier stop-at-AC-4 wording is historical and superseded only by this extension. No new roadmap or approval between AC-5/6/7 is needed; stop after KR-004 local acceptance, without merge or real-use claim.

**Executed local completion:** [AC-5–7 evidence](../test-plans/evidence/KR-004-GATEWAY-CONTROL-2026-09-11.md) records 60 Node entries including 42 actual HTTP scenarios with explicit storage stubs, plus 389 real SQL assertions across unchanged RLS/constraints and new atomic/concurrent control suites. Full checker and exact-target cleanup passed. AC-1–7 are locally complete/In Review, not merged or deployed; required CI status is synchronized in PR #17. No production/real-family gate is implied. Stop here; propose the existing KR-005 pairing threat-model/local redemption slice only as a separately directed next issue. KR-003 and visual tooling remain untouched/paused.

## KR-005 local pairing — 2026-09-11

- **Goal:** executable local single-use pairing, focused threat model, persistence/race/protocol security evidence.
- **Context:** OD-43 independently authorizes this slice. Clean verified baseline `bc6e36508b27b39b8805f10f048be97a990947ff`; branch `kr-005-local-pairing` stacked on unmerged `kr-004-local-schema-rls` / draft PR #17. Native Windows Docker client returned `linux` on the explicit local named pipe.
- **Constraints:** synthetic task-owned DB only; preserve KR-004 migrations/evidence, KR-003 and all bundles. No deployment, real users, UI/scanner, Auth stack, Android secure storage, KR-006/007 or visual work. Protocol/HTTP dependency stubs are not database-backed API evidence.
- **Done when:** real SQL proves expiry/cancel/replay, twenty concurrent claims, atomic rollback and response-loss recovery; actual protocol/gateway authorization and secret-minimization tests pass; required regression/CI results and remaining integration boundaries are recorded.

Use the existing disposable runner. The existing recommended rate limits are explicit local test parameters (5 creates/10 minutes, 10 redemptions/source-minute, 5 failed tokens/session), not newly approved production quotas. OD-09/10/20 are already accepted and will not be reopened. Stop after this issue; no merge or downstream implementation is authorized.

**Executed local result:** [KR-005 evidence](../test-plans/evidence/KR-005-LOCAL-PAIRING-2026-09-11.md)
records 68 Node entries, 487 real SQL assertions and 28 pairing/database/HTTP assertions.
Twenty simultaneously blocked sessions produced exactly one device/credential.
AC-1–7 are locally complete/In Review; required CI is tracked on the stacked PR.
Auth/PostgREST/Edge, trusted ingress/TLS, mobile storage, credential rotation and
scheduled retention integration remain unrun; gateway operation storage remains
stubbed. The next product-facing issue is KR-006 after separate authorization and
dependency review; do not start it automatically. KR-003 remains open.

## KR-006 local parent foundation — 2026-09-11

- **Goal:** executable native signup/verification/login/recovery/logout and idempotent own household/empty list against actual local Auth and PostgreSQL.
- **Context:** OD-44 is a new prospective authorization. Clean verified baseline `6de53806d68ac151c57d2667e09c351272ea0b83`; new branch `kr-006-local-parent-auth` stacked on unmerged KR-005 PR #18. Native Windows Docker explicitly returned `linux`; no Android SDK/emulator has yet been established locally.
- **Constraints:** only synthetic task-owned local services, local email capture and loopback development endpoints. No physical device, deployment, child enforcement, real users, distribution, KR-007 or visual work. No privileged key in APK; release denies local cleartext/callback exceptions. Preserve all prior migrations/evidence and unmerged PRs.
- **Done when:** debug APK builds and actual Auth/HTTP/database boundaries, household races/RLS and targeted UI/session tests execute, or a precise unavailable prerequisite blocks them; remaining emulator/physical checks and deletion design-only scope remain explicit.

First verify/pin existing compatible Android and official Auth/PostgREST/local-mail tools. Reuse the disposable DB runner and established architecture. Do not disable confirmation or forge authentication to claim success. Production identifiers, deployment/SMTP/region and distribution remain unapproved. Stop after this slice.

**Executed progress:** [KR-006 evidence](../test-plans/evidence/KR-006-LOCAL-PARENT-2026-09-11.md)
records real Auth/mail/PostgREST bootstrap/isolation/recovery/logout tests and unchanged
KR-004/005 regressions. Parent debug/release build, four JVM tests and lint executed in
CI after correcting compile SDK to 37; final release audit/CI status is tracked on
draft PR #19. Provisional app ID is not a distribution identity. AC-1/3/4/6/7 have local
evidence; AC-2/5 remain partial pending APK runtime/session/secure-storage evidence.
Initial execution did not establish a local SDK/emulator. The native Windows follow-up
below refines that prerequisite evidence; no Linux/CI result proves Windows unavailable.

## KR-006 native Windows runtime follow-up — 2026-09-11

**Resumed after owner SDK setup:** clean baseline `a5811617a08f4103d3650d5a3872c3f005ccb7cd`.
Native Emulator 37.1.11 `-accel-check` now returns exit 0, WHPX 10.0.26200 usable.
Platform Tools 37.0.1 and command-line tools 23.0 are installed; initially no image/AVD.
Proceed within existing OD-44 with one dedicated API 36 AOSP x86_64 AVD, actual Compose
instrumentation and unchanged local Auth/mail. Required package licence text is compared
with the installed/accepted SDK licence before download; never answer a new licence prompt.
The earlier prerequisite failure below remains historical, not the current acceleration verdict.

**Executed runtime result:** four real Compose instrumentation methods / 13 checkpoint
codes passed on the dedicated API 36 AOSP Windows emulator using source `f017474`.
Actual signup/email verification/login/household/empty list, same-process Activity
recreation, different-process session restoration, logout file/key clearing, recovery
and same-process recovery from a real task-owned REST outage passed. Exactly one runtime
household membership persisted; all task backend/app data cleanup and emulator stop
verified. [Sanitized result](../test-plans/evidence/KR-006-ANDROID-RUNTIME-2026-09-11.json).
No additional owner action is required for this completed emulator slice. Remaining
KR-006 work is physical/OEM storage, deployed link UX and accessibility acceptance,
subject to appropriate authorization; AC-2/5 remain partial, not an invitation to KR-007.

- **Goal:** execute the real parent UI against existing local services, including verification/recovery, activity versus process restoration, logout storage clearing and network recovery; no new features.
- **Context:** clean `4b0a218ed6b38fcb31c76c47b16af71841b2c4b7`, same branch/draft PR #19 stacked on #18; OD-44 now explicitly permits one dedicated Windows AVD and licensed user-owned tooling downloads.
- **Constraints:** no physical target, global ADB reset, new licence acceptance, host configuration/privilege changes, deployment or KR-007. Synthetic emails/credentials stay local and out of command arguments/logs. Existing backend loopback/release isolation remains intact.
- **Done when:** actual app runtime tests pass with sanitized results, or a demonstrated prerequisite requiring owner action stops execution without substituting backend/unit/build evidence.

**Historical observed stop (resolved by owner SDK setup):** native PowerShell executes successfully. SDK environment variables and
tool PATH entries are absent; standard Windows SDK/Studio/AVD paths and SDK registry
entries checked are absent. Windows reports a present hypervisor and firmware virtualization,
but usable emulator acceleration is **UNSPECIFIED** without the emulator executable.
About 268 GiB is free on C:. No existing accepted SDK licence installation was established;
downloads are conditional on that acceptance and the agent may not accept terms.
See the [retained diagnostics](../test-plans/evidence/KR-006-LOCAL-PARENT-2026-09-11.md#native-windows-runtime-follow-up--blocked-before-android-execution).

**Historical owner action (completed before the resumed run):** complete the official Android SDK's initial Windows setup in
`C:\Users\3feli\AppData\Local\Android\Sdk`, personally reviewing/accepting its licence
prompts. Do not enable Windows features or create an AVD for this step. Then resume
native acceleration verification and the single task-owned AVD within OD-44; any new
package licence remains an owner boundary. No app/device/services were operated in
this follow-up; all requested Android runtime flows and AC-2/5 remain unrun/partial.

## Critical-path reset — 2026-09-10

This section supersedes the historical daily scheduling below, not its uncompleted acceptance gates. The owner now prioritizes a usable product; visual/capture/classifier/dedup/alignment work is paused and preserved. The [current blocker table and limited-go proposal](../test-plans/KR-003-REMAINING.md) is authoritative for the immediate stop boundary. No launch date or sprint completion is inferred from the old calendar.

- **Goal:** reach one usable owner-only private-alpha vertical slice through existing issues, after explicit bounded approvals.
- **Context:** clean reset baseline `2b35b5a`; exact Samsung excluded Home Path B passed, full qualification/safety/lifecycle/support go remains open.
- **Constraints:** proposed private distribution/support is not approved. KR-004 remains held until the owner explicitly authorizes it; production enforcement remains held under KR-003/ADR-0002. No new framework/provider selection, deployment, bundle or device action in this documentation task.
- **Done when:** next approval and first bounded implementation issue are clear, historical evidence is unchanged, appropriate validation/CI passes, and work stops at that approval.

Recommended sequence, conditional on the limited owner go (not an automatic Ready/status change):

1. **KR-004 first:** local-only migrations and real-client-role two-household allow/deny fixtures, starting AC-1–4; then finish gateway/atomic transaction AC-5–7. Verify local tooling versions when authorized; no remote exposure or provisioning. These are the existing issue's boundaries, not a new backend project.
2. **KR-005 and KR-006 after their dependencies:** pairing threat model/atomic single-use/race/replay/response-loss tests (005 depends on 004); authenticated parent signup/login/recovery, sole-owner household and own empty list (006 depends on 004). OD-08 Kotlin/Compose, OD-09/10 device/QR semantics, OD-11 email/password and OD-12 sole owner are already accepted; stale issue “UNSPECIFIED” boilerplate does not reopen them. Exact versions, provider environment/region/SMTP and real-data facts remain unchosen and need verification/authorization, not an opportunistic replacement provider.
3. **Before KR-007/008 product enforcement:** record KR-003 technical/support/policy go under the retained contract or an explicitly amended private-alpha gate. Resolve Samsung recovery readiness before a long run; retain fresh 100-cycle/three-session qualification and required lifecycle/safety evidence. No capture automation prerequisite. Local database work does not grant this separate approval.
4. **KR-007** after 003/005/006: authenticated parent enrolls one consenting child with its own scoped identity, separate permission health, revocation and safe recovery. Pairing success is not enforcement readiness. **KR-008** after 001/002/003: persistent monotonic accounting, independent offline expiry of downloaded policy, uncertainty/reboot/update recovery, no uploaded app history. Complete both dependencies before 009.
5. **KR-009** after 004/007/008: authenticated +10/+30, Lock/Unlock and explicit daily limit; ordered idempotent snapshots/receipts, pending versus applied status, reconnect convergence and non-authoritative push hints. Lost Internet never cancels the latest valid downloaded policy; a new remote command remains pending offline. Unlock clears only manual lock, and +time does not clear manual lock.
6. **KR-010** after 003/006/009: the single existing parent/child experience—device remaining-time report with timestamp and current reported health, +10/+30/Lock/Unlock, setup/pending/degraded states, child restriction/help. No parallel shell app or extra features. Validate the product binaries, offline recovery, identity isolation and deletion before a separate owner acceptance for real private-alpha use; public distribution remains another milestone with its full evidence/declarations.

First unlocked task **after the proposed limited approval is recorded**: KR-004 local schema/RLS AC-1–4. First parent-facing slice after KR-004: KR-006, not premature child enforcement. Other issue statuses and acceptance criteria remain unchanged. All work proceeds one bounded task at a time.

## Historical scope and capacity

The full recommended candidate set remains KR-001 (3), KR-002 (2), KR-003 (8), KR-004 (5), KR-005 (3): **21 relative points**.
Points express uncertainty/relative effort, not hours or known team velocity.
This is conditional on two contributors (Android feasibility and backend/design) plus timely owner review and test devices.
Committed single-agent scope: KR-001/002/003. KR-004/005 remain stretch and cannot be reported complete without migrations/tests.
The architecture-pass documents provide a starting point but do not satisfy physical-test acceptance.

## Dependency-based daily plan

| Day | Focus | Reviewable output |
| --- | --- | --- |
| 1 | KR-001 owner decisions; KR-002 docs/checks | Signed/recorded state semantics or explicit blockers; working validation; tooling decisions only if bootstrapping |
| 2 | KR-003 permission/runtime/safe blocking spike; KR-004 schema | Native disposable spike on authorized lab device; two-tenant data/RLS fixtures |
| 3 | KR-003 restart/offline/clock/emergency tests; KR-004 deny tests | Measured failures and supported-boundary draft; local migration + allow/deny evidence |
| 4 | KR-005 pairing transaction/security tests; KR-003 policy packet | QR race/replay/interruption evidence or blocked result; disclosure/least-privilege review |
| 5 | Resolve contradictions and review go/no-go | Updated ADR status, residual risks, next ready issues; no premature production enforcement |

Sprint 01 runs 2026-09-05 through 2026-09-11. No personal assignee is invented; holiday handling remains **UNSPECIFIED**.

## Exit criteria

- OD-01–05/09/10 either approved with rationale or marked blocking dependent implementation.
- KR-002 scaffold validation and CI configuration reviewed; actual remote CI result distinguished from local checks.
- KR-003 reports observed enforcement/boot/offline safety and policy conclusion; unsupported claims removed.
- If devices unavailable, KR-003 remains Blocked; documentation alone cannot close it.
- KR-004 includes reviewed RLS matrix and, for full completion, executable local allow/deny tests under client roles.
- KR-005 includes threat model, atomic redemption/idempotency and interrupted-response recovery tests for full completion.
- No production table exposure, main enforcement build, store submission or final pairing before respective gates.
- KR-006–010 become Ready only as prerequisites and owner decisions allow.

Next sprint may pursue parent Auth, child identity and domain engine after feasibility gates. Full Android MVP remains a separate milestone.
