# KR-003 remaining feasibility work and device strategy

- **Goal:** Complete the remaining engineering/policy gates without repetitive manual setup.
- **Context:** Mi 8 expiry evidence includes the initial/ten-cycle checkpoint and four later calibration expiries. Q2, Q3 and Q4 physically failed Settings/recovery; no 100-sample qualification ran.
- **Constraints:** KR-003 only; no production timer/sync/backend implementation; disruptive operations require separate owner execution approval.
- **Done when:** Every outstanding KR-003 matrix row has measured evidence or an explicit accepted unsupported boundary, required hardware evidence exists, and go/no-go is recorded.

## Classification and queue

A = fully automatable repository/local synthetic work; B = automatable on a device after one owner authorization/setup; C = physical human
observation; D = evidence from another Android/API/OEM configuration; E = external Google Play evidence. Multiple letters identify real dependencies,
not interchangeable evidence. `Prepared` is tooling; `Not run` remains the physical result.

| Row / gate | Class | Automation support / next bounded work | Remaining physical or approval boundary |
| --- | --- | --- | --- |
| New-device metadata / transport | A,B,D | [Samsung SM-X400 / Android 16 API 36 transport passed](evidence/KR-003-SAMSUNG-TRANSPORT-CALIBRATION-2026-09-08.md); exact metadata and one counter-correlated tap are preserved | Complete for transport only on that exact configuration; no enforcement inference |
| Active-oracle calibration | A,B,C,D | **PASS on exact Samsung SM-X400 configuration:** runner-v5 retained one excluded 127 ms attachment, 22,371 ms hold, 20 denied taps, zero focus regain, continuous service, explicit owner agreement and verified cleanup; all earlier INVALID runs remain unchanged | Complete only for this configuration prerequisite; no qualification/offline/safety transfer |
| AC-3 / TIME-04: 100 zero expiries | B,C,D | The first Samsung runner-v8 attempt stopped INVALID during mobile-data isolation before ARM/cycle 1; runner-v9 is capability-aware. Q7 remains the blocked Mi 8 specialization | 100 fresh offline active-oracle rows plus approved checkpoint sessions; no Mi 8/Samsung/calibration/INVALID pooling; zero qualification rows exist |
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
its transport and active-oracle calibration prerequisites only. One qualification attempt ran but stopped INVALID in network preflight with zero
cycles, so formal TIME-04 is not passed.
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
