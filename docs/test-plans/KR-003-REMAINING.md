# KR-003 remaining feasibility work and device strategy

- **Goal:** Identify the shortest defensible path to a usable product, with an explicit next-stage owner decision rather than more visual tooling.
- **Context:** Critical-path reset at verified clean `2b35b5a7cfb31d890a01aa73a0384428921b4152`, branch `kr-003-mi8-overlay-stability`. Samsung Path B passed only its excluded diagnostic; historical 100-row runs remain FAIL/INVALID. No completed qualification or usable end-to-end product exists.
- **Constraints:** Documentation-only KR-003 reset; preserve all code/evidence/bundles. Pause capture/classifier/dedup/alignment development without revoking OD-41. No device operation, new bundle, deployment, KR-004 implementation or production enforcement in this task. Proposed gate changes are not accepted decisions.
- **Done when:** Exact blockers, their stage boundaries, one recommended owner action and the dependency-respecting product sequence are recorded and synchronized; repository validation passes; stop at owner approval. KR-003 completion still requires evidence/accepted boundaries and recorded go/no-go.

## Current priority and gate interpretation — 2026-09-10

**OWNER DIRECTIVE, accepted for this task:** prioritize a usable KidRemote application. Additional visual tooling and physical visual characterization are paused. Published source `760597e`, diagnostic bundle, tests and historical artifacts remain intact; capture permission remains valid. They are optional tooling, not prerequisites for implementing the product, and authorize no human-checkpoint replacement.

**OBSERVED:** exact Samsung `samsung / SM-X400 / Android 16 / API 36 / BP4A.251205.006 / patch 2026-07-05` has transport, bounded oracle calibration and excluded OD-39/40 Path-B PASS. Separately retained 100-row sets have automated PASS sub-evidence, not a passing whole run. The [Path-B evidence](evidence/KR-003-SAMSUNG-DUAL-HOME-DIAGNOSTIC-PASS-2026-09-10.md) explicitly excludes later recovery. No result transfers to Mi 8, another build/device, or a product binary.

**INFERRED:** local authorization/database work can be a useful first product step without pretending enforcement is approved. [KR-004's formal dependencies](../github/ISSUES.md) are KR-001/002, not KR-003; nevertheless the owner's explicit operational hold controls and has not been lifted. Starting KR-004 now is prohibited.

**UNKNOWN / UNSPECIFIED:** complete Samsung safety/lifecycle envelope, completed TIME-04 qualification, API 28/35 evidence, approved private distribution/support boundary, parent test-device selection, real-data provisioning decisions and external Play acceptance.

The current documents do **not** uniformly separate implementation, private use and public distribution. [PRODUCT delivery gates](../PRODUCT.md#delivery-gates) distinguish feasibility/alpha/MVP, and KR-003 AC-2 allows external approval status to remain UNSPECIFIED. However ADR-0002 keeps production enforcement closed, this remaining-work contract requires API 28/35/36 and external evidence before its full go/no-go, and the explicit owner hold also stops local KR-004. That coupling is not silently waived here. A limited development authorization and a narrower private-alpha boundary require explicit owner decisions; they are not KR-003 closure or Google acceptance.

Targeted official-source recheck on 2026-09-10: the [Android Accessibility guide](https://developer.android.com/guide/topics/ui/accessibility/service) still limits its intended service purpose to assistive tools; [Play's Accessibility declaration guidance](https://support.google.com/googleplay/android-developer/answer/10964491) describes conditional non-accessibility-tool use and disclosure. This preserves the documented policy tension, not a conclusion that private distribution exempts KidRemote from platform, safety, consent or privacy requirements. No store submission or external approval was obtained.

### Compact critical-path blocker table

Stages: **D** = permission to develop the next bounded implementation; **E** = permission to implement the product enforcement adapter; **U** = real private-alpha use; **P** = public distribution; **O** = optional tooling. The stage separation below is descriptive/proposed where the current contract couples gates, not an accepted exemption.

| Existing requirement / source; affected gate | Retained evidence | Missing fact or decision | Smallest resolving action | Needs |
| --- | --- | --- | --- | --- |
| KR-003 AC-7; explicit owner hold; KR-004 dependencies KR-001/002 ([issue](../github/issues/KR-003.md), [backlog](../github/ISSUES.md)); D/E | Architecture/state decisions and local spike exist; no product go-ahead | Limited development go vs full enforcement go | Owner explicitly authorizes only local KR-004 AC-1–4 first, preserving other gates; proposed below | Owner approval; no physical work for this decision |
| KR-003 AC-3 / TIME-04 / OD-29/39; [Q7 contract](KR-003-CONFIGURATION-ACTIVE-ORACLE-QUALIFICATION.md); E/U under current gate | Separate 100-row PASS sets, whole runs FAIL/INVALID; excluded Path B PASS | One complete fresh offline run, all 100 cycles and three checkpoints, p95 ≤2 s and verified cleanup | Only after recovery readiness is established, one fresh existing runner-v12 run; stop FAIL/INVALID, no replacement/resume/pooling | Physical + human; no new visual code |
| KR-003 AC-5 / SAFE-01/02 / OD-07; [matrix](MATRIX.md); E/U | Samsung Home Path B + CLEAR passed; Q5 recovery PASS was Mi 8-only | Samsung Settings/Digital Wellbeing/recovery/re-entry route; essential emergency/accessibility/IME/help surfaces and product local removal | First one bounded observed recovery-route check using existing recovery logic; then only missing relevant safety cases; no live emergency call | Physical human observation; minimal existing-runner wiring if separately approved; possibly other relevant hardware |
| KR-003 AC-4/5; TIME-05–11/13–16, PERM-01–03, TAMP-01–08; [remaining queue below](#classification-and-queue), ADR-0002; E/U | Domain/runner tests and runtime health checks; not the missing lifecycle trials | Normal restart/update, online/offline reboot, time edits, revoke/OEM recovery and accepted adversarial boundaries | Targeted per-case evidence on selected configuration; document supported/unsupported outcomes, never exclude normal reboot as tampering | Physical + some bounded code; owner approval for disruptive operations; no destructive test by default |
| Physical protocol device set / OD-15/32 / AC-7 ([protocol](KR-003-PHYSICAL.md)); E/U/P currently coupled | API 36 Samsung evidence; Mi 8 API 29 cannot satisfy API 28/35 | API 28/35 and proposed OEM variants, or prospective narrower support decision | Owner chooses: retain full current hardware gate, or explicitly limit initial private-alpha child support to exact Samsung and defer other variants until separately qualified | Owner support decision; other hardware if current gate retained |
| KR-003 AC-1/2/7 / [POLICY](../POLICY.md), [ADR-0002](../adr/0002-android-enforcement.md); E/U/P currently coupled | Four-option assessment/disclosure packet; no Play approval | Policy-purpose tension, owner residual-risk acceptance; public audience/declaration/review decisions | Explicitly decide whether external store acceptance gates public distribution rather than local development/private milestone; retain policy review and all safety/privacy constraints | Owner + policy review; external Play approval for public distribution, not fabricated by owner |
| KR-003 AC-6; KR-004/005/006/007/008/009/010, AUTH/PAIR/DB/CMD/NET/PRIV/UI and OD-14 ([matrix](MATRIX.md), [privacy](../PRIVACY.md)); U | Specs, domain fixtures, spike release-isolation tests; no product auth/RLS/pairing/offline-sync evidence | Executable secure vertical slice, private-use recovery, configuration/region/retention/provider facts and product-binary validation | Implement existing issues in dependency order; run negative authorization, pairing-race, persistence/offline, deletion and safety tests before real use | Code + local tests + selected-device observation; separate provisioning/real-data approval |
| OD-41 reference/video/dedup/alignment; O | Published characterization-only implementation, physically unrun; no substitution authorization | Nothing needed for the proposed local development decision | Preserve and pause; keep necessary human observation, not another capture experiment | No current work |

### Safety-route readiness before another long run

The full runner's `Invoke-QualificationSafetyCheckpoint` continues after Home to `Invoke-FocusedRecoveryDiagnostic`, ordinary re-entry and CLEAR. The short OD-40 mode passes `-HomeOnly` and **returns before recovery**. `Runner.Tests.ps1` explicitly checks `RecoveryReason=UNRECORDED` in the excluded mode. The required later route is Settings root usable → Digital Wellbeing attempt blocked → one overlay recovery-button action → Settings stable for ten seconds → ordinary fixture blocked again → CLEAR/input restored. This is implemented logic, not Samsung physical readiness.

Do **not** recommend another 75–90-minute qualification now. There is no currently supported Samsung full-recovery-only entrypoint: the top-level `-RecoveryDiagnostic` parameter is rejected by the configuration-bound full mode (`INVALID:OFFLINE_QUALIFICATION_MODE_REQUIRED`), and the approved short Home bundle deliberately stops earlier. Historical Q5's Mi 8 bundle is not a substitute. A future, separately authorized short recovery check should expose/reuse the existing function and fixture oracle with minimal wiring, not create another diagnostic framework or repeat Home calibration merely for tooling. No such code or bundle is prepared in this reset.

One future recovery-only observation session is estimated at 5–10 owner minutes (unmeasured; not authorized now). The eventual fresh qualification still has at most three human **sessions**, including multiple prompts at checkpoint 3, not 100 confirmations. SAFE-01, permission changes, reboot and other remaining project safety tests require additional sessions/authorizations; they are not promised to fit that three-session limit.

### PROPOSED first milestone and ONE next action

**PROPOSED, NOT APPROVED:** an owner-only private alpha, initially one authorized Samsung SM-X400 child on the exact captured configuration above, plus one owner-selected Android parent device whose model/OS must be recorded before use. No Mi 8 or general Android support; no public invite, Play launch, daily unsupervised reliance or production-readiness claim. Private use still needs authentication/authorization, consent, recovery, safe-device access, offline persistence, data minimization and product-binary tests. Lab ADB CLEAR is not the product's offline parent recovery mechanism.

**ONE recommended next action: owner approval of a limited development go.** Proposed authorization: “Prioritize the owner-only private-alpha milestone; lift the KR-004 operational hold only for local schema/RLS work using synthetic identities, beginning AC-1–4. Do not close KR-003, authorize production enforcement, deploy a backend or begin real family use. Decide the narrower support/store-gate amendments explicitly before dependent enforcement work.” This is a brief review/response, **zero device minutes**; no physical command is supplied. Until accepted and recorded, KR-004 stays untouched.

Consequences: the first security foundation can progress without paying for missing hardware or waiting for store review, while the child enforcement gate remains closed. This does **not** reduce the 100-cycle count, transfer earlier rows, accept trapping, exempt restart/reboot, or waive policy/real-data obligations. To authorize enforcement later, retain the current full gate or explicitly amend it to the exact private device boundary and public-store separation, then satisfy the remaining technical evidence on that boundary and record the owner go/no-go. If scope change is declined, the original API 28/35/36 and full KR-003 gate remain in force.

The dependency-respecting implementation sequence is maintained in [SPRINT-01](../exec-plans/SPRINT-01.md#critical-path-reset--2026-09-10); this proposal creates no new issue or parallel app.

## Classification and queue

A = fully automatable repository/local synthetic work; B = automatable on a device after one owner authorization/setup; C = physical human
observation; D = evidence from another Android/API/OEM configuration; E = external Google Play evidence. Multiple letters identify real dependencies,
not interchangeable evidence. `Prepared` is tooling; `Not run` remains the physical result.

| Row / gate | Class | Automation support / next bounded work | Remaining physical or approval boundary |
| --- | --- | --- | --- |
| New-device metadata / transport | A,B,D | [Samsung SM-X400 / Android 16 API 36 transport passed](evidence/KR-003-SAMSUNG-TRANSPORT-CALIBRATION-2026-09-08.md); exact metadata and one counter-correlated tap are preserved | Complete for transport only on that exact configuration; no enforcement inference |
| Active-oracle calibration | A,B,C,D | **PASS on exact Samsung SM-X400 configuration:** runner-v5 retained one excluded 127 ms attachment, 22,371 ms hold, 20 denied taps, zero focus regain, continuous service, explicit owner agreement and verified cleanup; all earlier INVALID runs remain unchanged | Complete only for this configuration prerequisite; no qualification/offline/safety transfer |
| AC-3 / TIME-04: 100 zero expiries | B,C,D | Samsung runner-v9 retained 100 automated PASS rows (p95 317 ms) then checkpoint-3 INVALID. Runner-v10 separately retained 100 automated PASS rows (p95 318 ms) then a Home-phase FAIL with no Home action. Runner-v11 RUN A retained 100 PASS rows (p95 299 ms) then final-visible `ADB_REJECTED` with unverified cleanup; RUN B retained 100 PASS rows (p95 304 ms) and final-visible PASS but no exercisable Home control/action. Q7 remains blocked on Mi 8. OD-39's excluded Path-B diagnostic subsequently passed on Samsung, but contributes no qualification row | One entirely fresh offline run must complete all 100 rows and all three checkpoints through OD-39 Path A or Path B; no stopped run can be resumed, replaced or pooled. OD-41's visual calibration is not yet physical evidence and does not alter the immutable runner-v12 contract |
| TIME-01 eligible total / TIME-02 screen off / TIME-03 keyguard | A,B,C | Pure monotonic cases pass; future phase runner can journal state before/after | Owner physically toggles screen/keyguard and observes eligibility; no automated unlock |
| TIME-05 process death | B,C | Prepare a journal-before/after debug self-termination phase after qualification | Verify the candidate process actually changes; do not substitute fixture kill or force-stop |
| TIME-06 app/service restart | B,C | Snapshot/revision/heartbeat controls exist | Physical restriction recovery remains observed evidence |
| TIME-07 reboot online / TIME-08 reboot offline | B,C | Prepare snapshot → approved reboot → bounded reconnect → snapshot/diff workflow | Reboot/network authorization and owner unlock/observation required; pre-unlock gap stays measured |
| TIME-09/10 wall clock +/-24h / TIME-11 timezone | A,B,C | Domain monotonic rollback cases pass; prepare reversible initial-value journal | Global setting edits/restoration need owner action where shell is denied; production household-day semantics remain KR-008 |
| TIME-13 deep sleep / TIME-14 update | B,C,D | State/hash/heartbeat capture exists; package update remains in-place only | Physical sleep/OEM and installed-update recovery evidence required |
| TIME-15 missing UsageEvents | A,B | Current UsageEvents feature is explicitly diagnostic; pure timer uncertainty/rollback cases exist | A production reconciliation design is outside this spike; device absence case remains unrun |
| TIME-16 multi-window/PiP/launcher/video | B,C,D | Reuse typed candidate/fixture snapshots without content capture | Human validates visible/safe behaviour; focus alone is insufficient |
| TIME-18 storage write failure | A,B | Current store fail path marks accounting uncertain in memory; a deterministic storage-failure adapter would require a separate bounded refactor | No on-device data corruption/clear; observable degradation remains unrun |
| NET-01 network lost before expiry | B,C | Existing offline calibration evidence and Q2 radio restore/readback stay configuration-specific | Mid-session loss/recovery and actual connectivity remain unrun; flags are not connectivity proof |
| PERM-01 Usage Access / PERM-02 Accessibility removal | B,C | Read-only permission/state parsing, heartbeat and health assertions exist | Owner changes and restores settings manually; never overwrite another service list |
| PERM-03 incomplete setup/refusal | B,C | Preflight refuses unhealthy setup | Human verifies explanation/refusal UI; do not clear data merely to manufacture a state |
| TAMP-01 force-stop | B,C | Treat as a separate unsupported-boundary test | Explicit disruptive authorization; never relabel normal process death |
| TAMP-02 uninstall / TAMP-03 clear data | C | Documented consumer bypass; no runner command is enabled | Destructive execution needs separate explicit approval and is outside qualification cleanup |
| TAMP-04 safe mode / TAMP-08 root/bootloader | C,D | Unsupported-boundary plans only | Authorized disposable hardware/human procedure; no root/unlock/flash is planned |
| TAMP-05 secondary user/guest | B,C,D | Read-only user-scope capture can be prepared after a target supports the mode | Owner switches users; primary-user result never transfers |
| TAMP-06 battery/OEM survival | B,C,D | Generic flags are collected; candidate heartbeat/state soak can be automated | Exact OEM setting and physical survival/recovery are configuration-specific |
| TAMP-07 ADB/developer options | A,B | Protected receiver, typed export, manifest/DEX isolation and source rejection pass | Runtime unauthorized-sender boundary remains an owner-authorized device test |
| SAFE-01 emergency/dialler/TalkBack/IME/permission UI | C,D | Technical state can be correlated without content collection | Human-only safety/usability; never call a live emergency service |
| SAFE-02 local help/removal/recovery | B,C,D | Q2/Q3/Q4 failures and one Q5 exact-route PASS remain preserved | Repeat and expand safe-surface observation per configuration; no broad Settings/OEM inference |
| Missing package / interruption / lost screen signal | A,B | Pure missing/unknown fail-open and health regressions exist | Device lifecycle behavior remains unrun and fail-open is not an enforcement pass |
| AC-6 least privilege | A,B | Source, permission, debug/release manifest, DEX, typed-schema and new identifier/raw-output rejection tests pass | Runtime sender denial/traffic audit remains; static absence of INTERNET is only static evidence |
| AC-1/2 policy packet | A,E | ADR/disclosure/refusal/declaration packet exists and stays synced | Current Play review/target-audience/declaration acceptance requires external account evidence |
| AC-7 go/no-go | C,E | Assemble exact configuration and unsupported-boundary results | Owner accepts support boundary after technical and external policy evidence |

TIME-12/17/19 and backend/command/identity rows remain their own KR-001/007/008/009 work; the spike cannot claim production daily reset,
UsageEvents reconciliation, grants, pairing, cloud outage sync or deletion coverage. KR-004 remains untouched.

## Device matrix

Apply the exact [device-to-matrix mapping](KR-003-DEVICE-MATRIX-MAPPING.md) to each validated onboarding record.

The physical protocol requires **API 28**, **Android 15/API 35**, **Android 16/API 36**, and each proposed OEM support variant. These are hard
physical gates under the current contract. The Samsung record establishes an Android 16/API 36 plus exact Samsung-variant configuration and passes
its transport and active-oracle calibration prerequisites only. One qualification stopped INVALID in network preflight; a second retained 100
automated PASS rows and p95 317 ms but stopped INVALID before checkpoint-3 physical agreement. Three later 100-row sets also stopped during
checkpoint 3: runner-v10 before an established Home action, runner-v11 RUN A before final-visible completion, and runner-v11 RUN B because no
Home control/action was exercisable. Formal TIME-04 is not passed and none is resumable or poolable.
API 28 and 35 remain unavailable/unrun.
Android 17/API 37 is now an official platform. Adding it to the required support set remains **UNSPECIFIED**; any API 37 result is supplemental
until that owner decision and cannot satisfy the existing API 36 row.
The broader matrix proposes a current Google reference, Samsung phone/tablet and restrictive tablet/OEM; exact approved support variants remain
**UNSPECIFIED**. Do not convert that proposal into a promise of support.

Lowest incremental-cost route is existing/borrowed authorized lab hardware with the required OS already installed. Do not flash/reset the Mi 8 to
simulate missing configurations. Use emulators for deterministic APIs, debug receiver denial, lifecycle and integration development;
they cannot qualify OEM killing, physical emergency/recovery, touch/visual behaviour or battery.

For missing hardware, evaluate [Android Device Streaming](https://developer.android.com/studio/run/android-device-streaming) for interactive
physical observation and [Firebase Test Lab inventory](https://firebase.google.com/docs/test-lab/android/available-testing-devices) for automated
physical suites. Verify the actual model/API, manual Accessibility consent, stream visibility/latency and authorized ADB access before relying on
either service. A batch instrumentation result does not supply 100 human-visible observations. Remote streaming also cannot establish precise
local visual-onset timing; keep the monotonic metric boundary explicit.

Review the account's [current quotas and pricing](https://firebase.google.com/docs/test-lab/usage-quotas-pricing) before provisioning. Hosting/testing
budget, device availability and exact expenditure are **UNSPECIFIED**. No purchase, paid run or external account creation occurred.
Official device/testing sources reviewed 2026-09-06.

## Three separate gates

1. **Technical evidence:** completed Mi 8 checkpoint, Q2/Q3/Q4 **physical Settings/recovery failures**, then one focused
   [Q5 task-reset recovery PASS](evidence/KR-003-Q5-RECOVERY-2026-09-06.md). Q5 has zero qualification samples; Q6 was prepared but never run and is
   superseded by [Q7](KR-003-Q7-AUTOMATED-QUALIFICATION.md) under OD-29. Its 100-cycle active-oracle run, three checkpoints, remaining matrix and other device
   configurations are outstanding.
2. **Policy design assessment:** ADR-0002 and POLICY document a conditional design and unresolved Android/Play purpose tension.
3. **Actual Play review/acceptance:** no submission/review/approval evidence exists. Remains **UNSPECIFIED** and external.

No successful timer run or release-isolation check substitutes for gates 2 or 3. Do not close KR-003 or open production enforcement.
