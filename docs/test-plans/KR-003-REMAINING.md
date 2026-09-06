# KR-003 remaining feasibility work and device strategy

- **Goal:** Complete the remaining engineering/policy gates without repetitive manual setup.
- **Context:** Mi 8 expiry evidence includes the initial/ten-cycle checkpoint and three later calibration expiries. Q2 and Q3 physically failed Settings/recovery; no 100-sample qualification ran.
- **Constraints:** KR-003 only; no production timer/sync/backend implementation; disruptive operations require separate owner execution approval.
- **Done when:** Every outstanding KR-003 matrix row has measured evidence or an explicit accepted unsupported boundary, required hardware evidence exists, and go/no-go is recorded.

## Classification and queue

A = fully automatable checks; B = mostly automated with physical observation; C = human judgement; D = additional physical configuration; E = external policy evidence.
Multiple letters identify dependencies. 'Prepared' is tooling, not execution.

| Row / gate | Class | Automation support / next bounded work | Remaining physical or approval boundary |
| --- | --- | --- | --- |
| AC-3 / TIME-04: 100 zero expiries | B,D | Debug clear/arm, fixed fixture, metric export, revision pairing, direct trace, CSV/JSON/statistics and failure journal prepared | One visual P/F/I/Q per expiry; calibration/recovery checklist; required physical versions |
| TIME-01 eligible total / TIME-02 screen off / TIME-03 keyguard | A,B | Pure monotonic tests exist; use debug snapshots before/after screen changes; add phase runner after qualification | Physically toggle screen/keyguard; verify only eligible time falls; no automated unlock |
| TIME-05 process death | B | Queue approved debug self-process-termination hook with journal-before-crash; relaunch/query and compare balance/revision | Do not substitute force-stop or killing the fixture. System-bound process may survive `am kill`; verify actual process transition |
| TIME-06 app/service restart | A,B | Snapshot/revision/heartbeat controls prepared; explicit activity relaunch is supported | Relaunch alone does not prove process death; physically check recovered restriction |
| TIME-07 reboot online | B | Queue snapshot → approved reboot → bounded device wait → snapshot/diff, boot-gap timestamps | Separate reboot approval and owner keyguard unlock; do not waive pre-unlock coverage |
| TIME-08 reboot offline | B | Same sequence with recorded offline condition and unchanged durable expired balance | Separate reboot/network-change approval; restored uncertainty/restriction and gap observed |
| TIME-09/10 wall clock +/-24h | A,B | Domain monotonic tests exist; snapshot comparison ready; queue reversible settings phase with exact initial-value journal | Shell cannot be assumed allowed to set time on MIUI; owner Settings step if denied; restore approved original configuration |
| TIME-11 timezone | A,B | Compare monotonic balance and state snapshots around a reversible timezone change | Approval before global settings change; household-day production semantics remain KR-008 |
| TIME-13 deep sleep | B,D | Queue idle/awake phase with monotonic before/after and heartbeat | Screen/Doze/OEM behaviour needs physical run; no invented exact sleep timer |
| TIME-14 app update | A,B | Runner verifies installed APK by pulling/hash; queue old → new in-place install with durable snapshot comparison | Snapshot actual update recovery; don't uninstall on signing mismatch |
| TIME-15 missing UsageEvents | A,B | Queue synthetic reconciliation/diagnostic fixtures with explicit uncertainty | Current UsageEvents code is only a probe; no claim production reconciliation is implemented |
| TIME-16 multi-window/PiP/launcher/video | B,C,D | Reuse fixture and technical snapshots around each surface | Human validates safe visible behaviour; app focus is insufficient |
| TIME-18 storage write failure | A,B | Queue injected persistence failure in disposable tests; no clear-data/corruption command on device | Separate isolated test design before touching durable state; report degradation |
| NET-01 network lost before expiry | B | Offline calibration expiries observed; Q2 radio restore/readback verified; full qualification still blocked by Settings failure | Mid-session network-loss/recovery not isolated; flags alone do not prove connectivity; no backend-recovery claim |
| PERM-01 Usage Access remove/regrant | B | Read-only Usage Access query prepared; queue original AppOps state capture → approved change → restore | Explicit execution approval; no automatic grant to conceal refusal |
| PERM-02 Accessibility disable/re-enable | B,C | Service/permission freshness checks prepared; direct snapshots can observe loss | Explicit execution approval; use Settings rather than overwriting enabled-services lists and affecting other services |
| PERM-03 incomplete setup/refusal | B,C | Debug preflight refuses unhealthy setup; queue clean consent/refusal UI test | Observe actual explanation/refusal; do not clear data to manufacture a fresh install |
| TAMP-01 force-stop | B | Queue as separate unsupported-boundary test, not normal process death | Explicit disruptive execution approval; no guarantee after force-stop |
| TAMP-02 uninstall / TAMP-03 clear data | C | Document unsupported consequence; no enabled runner commands | Explicit destructive approval required; never part of qualification cleanup |
| TAMP-04 safe mode | C,D | Research/record unsupported consumer boundary | Explicit approval and disposable hardware; no automatic safe-mode action |
| TAMP-05 secondary user/guest | B,D | Queue read-only user-scope snapshot and separately approved user-switch procedure | No enrolled-primary-user result generalized to another user |
| TAMP-06 battery/OEM survival | B,D | Heartbeat/state export ready; queue timed screen-off/awake soak and power-setting manifest | Owner-approved reversible OEM setting changes; measure actual recovery, don't generalize |
| TAMP-07 ADB/developer options | A,B | Protected debug receiver/release audit and allowlisted evidence export prepared | Privileged ADB is outside consumer protection; sender-denial runtime test still queued |
| TAMP-08 root/bootloader | C,D | Explicit unsupported boundary from ADR-0002 | No root/unlock/flash operation; physical testing only if separately authorized |
| SAFE-01 emergency/dialler/TalkBack/IME/permission UI | C,D | Record technical state while an operator follows approved safety script | Settings success does not prove these; never dial a live emergency service for a test |
| SAFE-02 offline local help/removal and other recovery | B,C,D | Q2 **physical FAIL**; [Q3 labelled diagnostic](evidence/KR-003-Q3-RECOVERY-2026-09-06.md) reproduced Digital Wellbeing ORDINARY_APP reattachment and recovery FAIL; lab bailout verified | Implement only a bounded recovery repair, rerun the focused route, then retest known-failed paths; prior top-level successes do not satisfy this gate; other safety surfaces outstanding |
| Missing package, interruption, lost screen signal | A,B | Pure fail-open regression exists; queue service/lifecycle injections and observations | Unknown/safe fail-open is deliberate but not an enforcement pass |
| AC-6 least privilege | A,B | Recursive source/permission checks, debug/release manifest and DEX audit, typed schema rejection tests | Runtime sender-denial/traffic audit still required; static absence of INTERNET is only static evidence |
| AC-1/2 policy design packet | A,E | Existing ADR/disclosure/refusal/declaration docs; keep packet synced with actual code | Policy review/target-audience/account choices cannot be inferred from builds |
| AC-7 go/no-go | C,E | Assemble completed run manifests and unsupported boundary matrix | Owner accepts tested support boundary; policy tension resolved with evidence |

TIME-12/17/19 and backend/command/identity rows remain their own KR-001/007/008/009 work; the spike cannot claim production daily reset,
UsageEvents reconciliation, grants, pairing, cloud outage sync or deletion coverage. KR-004 remains untouched.

## Device matrix

The physical protocol requires **API 28**, **Android 15/API 35**, **Android 16/API 36**, and each proposed OEM support variant. These are hard
physical gates under the current contract. Available: Mi 8/API 29 only. Required 28/35/36 configurations remain unavailable/unrun.
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

1. **Technical evidence:** completed Mi 8 checkpoint, followed by Q2 and Q3 **physical Settings/recovery failures**. Current build cannot qualify;
   [focused evidence](evidence/KR-003-Q3-RECOVERY-2026-09-06.md), a bounded repair, the remaining physical matrix and 100 samples are outstanding.
2. **Policy design assessment:** ADR-0002 and POLICY document a conditional design and unresolved Android/Play purpose tension.
3. **Actual Play review/acceptance:** no submission/review/approval evidence exists. Remains **UNSPECIFIED** and external.

No successful timer run or release-isolation check substitutes for gates 2 or 3. Do not close KR-003 or open production enforcement.
