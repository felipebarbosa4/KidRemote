# KR-003 qualification contract v3 (KR003-Q7) — 2026-09-06

Portability note, 2026-09-08: the independent active-oracle semantics apply to any explicitly authorized candidate configuration, but the Q7
bundle and results below remain the Mi 8 specialization. A new device must first pass [generic fixture-only transport](KR-003-DEVICE-ONBOARDING.md),
then [generic bounded oracle calibration](KR-003-ACTIVE-ORACLE-CALIBRATION.md), before a fresh configuration-specific 100-cycle bundle is prepared.
No metadata, calibration or sample is transferable between Mi 8, Samsung, Pixel, another OEM or a changed build/power/permission configuration.

- **Goal:** Produce 100 valid offline expiry/latency cycles using an independently calibrated active fixture oracle and no more than three human checkpoint sessions per candidate configuration.
- **Context:** KR-003 AC-3, [physical protocol](KR-003-PHYSICAL.md), [matrix](MATRIX.md), [capacity target](CAPACITY.md), ADR-0002/0008, the Mi 8 ten-cycle checkpoint, and owner operating constraint OD-29.
- **Constraints:** Authorized lab; owner executes one Windows command; no destructive operations, screenshot/node/content inspection, hidden physical inference, result pooling or more than three human checkpoint sessions.
- **Done when:** One immutable run has 100 active-oracle cycles, three passing human checkpoints, zero detected enforcement failures, nearest-rank internal p95 ≤2,000 ms, and complete cleanup evidence. This is only AC-3 evidence for one configuration under the explicitly revised evidence model.

**Current gate:** [Q2](evidence/KR-003-Q2-SETTINGS-2026-09-06.md) and the
[Q3 diagnostic](evidence/KR-003-Q3-RECOVERY-2026-09-06.md) physically failed recovery; then
[Q4](evidence/KR-003-Q4-RECOVERY-2026-09-06.md) physically rejected `NEW_TASK | CLEAR_TOP` because recovery was transient. Do not rerun those
commands or pool their expiries into qualification.

The separately justified [Q5 Settings task reset](KR-003-RECOVERY-TASK-RESET.md) subsequently
[passed its focused physical calibration](evidence/KR-003-Q5-RECOVERY-2026-09-06.md) on the exact Mi 8 and candidate APK hash. This clears only
the prerequisite to prepare a new immutable qualification bundle. It does not start or reduce the 100 new samples, waive the fresh
calibration/safety checks below, establish another device, or approve production/Play release.

The resulting [Q6 specialization](KR-003-Q6-QUALIFICATION.md) was packaged but never physically run. OD-29 supersedes it with
[Q7](KR-003-Q7-AUTOMATED-QUALIFICATION.md): the candidate APK stays byte-identical to Q5 while a new disposable fixture supplies a real
input-layer/focus oracle. Preparation, synthetic tests, builds and hashes are not physical evidence. Q7 must first calibrate the oracle on the Mi 8;
if calibration fails, it stops before sample 1 and the three-checkpoint constraint is incompatible with the former 100-human-observation gate.

The separate Samsung path has now satisfied transport and the standalone [active-oracle calibration](evidence/KR-003-SAMSUNG-ORACLE-CALIBRATION-PASS-2026-09-08.md) on one exact configuration. Its first [configuration-bound runner-v8 attempt](evidence/KR-003-SAMSUNG-QUALIFICATION-NETWORK-INVALID-2026-09-09.md) stopped during network preflight before ARM or cycle 1. Runner-v9 retains this contract with capability-aware isolation; no Mi 8 identity or physical result transfers. The 100-cycle section remains unexecuted.

## Reconciled definitions

Q7 explicitly changes the former per-sample observer requirement. One automated sample is a new persisted 10-second allowance/revision, ordinary
interactive/unlocked fixture use through zero, a paired attachment measurement, a working pre-arm input positive control, and at least ten seconds
in which 20 real ADB input taps do not reach the independent fixture and it never regains focus. Multiple attachments, Home presses and Settings
visits never create samples. The result must be described as **100 active-oracle cycles plus three human checkpoints**, never 100 physical passes.

The original 100-sample paragraph did not define persistence duration. Apply the existing Mi 8 checkpoint's **at least 10 seconds continuously
visible after attachment**, without flicker, disappearance or ordinary use. This makes 'visibly perceived block' testable without shortening it.
The owner visually watches the excluded preflight expiry and the post-run sample-100 state; attempts 1–100 have no P prompt. Candidate telemetry
cannot create an oracle PASS by itself. The separate fixture counter/focus callbacks and real Android input command are the active oracle.

The numerical metric remains the physical protocol's mathematical monotonic zero → first successful overlay attachment, paired with the visual
result. Nearest-rank p50/p95 and maximum use exactly the 100 valid paired measurements. A slow valid observation is retained. The broader capacity
wording 'observed usable restriction' requires the physical outcome too; attachment latency alone does not measure independently timed visual onset.
Human reaction time/visual-onset latency is **UNSPECIFIED** and is not relabelled as that metric.

Home/Settings/re-entry have separate SAFE/TAMP obligations. The completed ten-cycle run already repeats them. Q7 performs one guided post-run
physical Home/Settings/Digital Wellbeing/recovery/re-entry route, plus an automated CLEAR/input check. This does not satisfy other SAFE rows.

## Eligibility, failure and interruption

- Exact APK/hash, source commit, target fixture, device build, permissions, power settings and network condition are fixed and recorded.
- Each attempt begins cleared, fixture foreground/focused, then is armed while the fixture is visible; the debug command does not open a window.
- State queries must be authenticated by Android's sender permission and return fresh correlated candidate schema-v2 telemetry (fixture schema v1). Missing/overflowed trace,
  process replacement, permission loss, stale service, clock discontinuity or a changed configuration cannot silently produce a valid sample.
- **FAIL:** a checkpoint observer sees flicker, disappearance, escape/no-block or unusable recovery; or automation observes fixture input/focus
  leakage, restriction removal, revision rollback/change, service reconnect/process replacement, or service/permission failure. Stop immediately.
- The operational no-attachment timeout is 10 seconds after expected zero, not a new maximum-latency target. Samples slower than 2 seconds but
  reaching a persistent block before timeout remain valid and count against p95. Final p95 >2,000 ms rejects that candidate run.
- **INVALID:** a checkpoint was missed, keyguard/screen interrupted eligibility, target failed to launch, the active input oracle was not proven,
  or transport/telemetry is unavailable.
  Preserve the row and stop for review. Do not silently replace the attempt or remove slow samples. A software-visible enforcement fault is FAIL,
  not INVALID. Invalid-versus-failure ambiguity is retained for review, never automatically excused.
- **INTERRUPTED:** operator quits; journal current attempt immediately, keep previous records, do not report qualification. An unexpected host
  exception is conservatively labelled INVALID with a sanitized code. A hard host/power kill leaves an incomplete journal, never a qualified run.
- No cross-process resume or pooling across runs in v2. Restarting creates a new directory/run and retains the incomplete one. Pauses between completed
  cycles are permitted in the same process; recheck health/configuration before the next arm. No attempt is resumed halfway through expiry.

## Operator workload and outputs

Automation installs/verifies both lab APKs; exports prior metrics; clears/re-arms; launches the fixture; injects and verifies input before and during
every attempt; measures each expiry; captures bounded typed evidence; and independently computes statistics. The owner performs exactly three
checkpoint sessions. Fixture focus/input is independent active evidence, not a physical-visible claim; attachment alone is never sufficient.

Q7 first runs an excluded visually observed expiry, then a controlled unblocked negative control proving the same injected tap reaches the fixture.
It resets timing metrics only after both pass. The candidate APK remains Q5-identical; only the disposable fixture/runner changes. Failure stops
before qualification.

### Recovery-phase corroboration and diagnostic calibration

The [stopped d81f19a calibration](evidence/KR-003-CALIBRATION-2026-09-06.md) had physical expiry/Home/Settings PASS but fresh telemetry continued
to report ORDINARY_APP/attached. Its Android-side cause is **UNSPECIFIED**; the trace does not establish a transient SAFE_SYSTEM event or a late
sample. The historical `FAIL:SETTINGS_RECOVERY` is an **uncorroborated oracle / incomplete calibration**, not a retroactive physical Settings failure.
Q2 fixes evidence collection/classification without changing enforcement semantics, safe packages, persistence duration or the 100-sample target.

- Create a recovery record before the physical prompt: revision, device `elapsedRealtime`, trace sequence floor and host UTC. Poll state/fixture
  during the prompt. Save the owner's P/F/I/Q result and UTC immediately, before post-response checks; never overwrite it with the oracle result.
- Require the existing Settings-button **request and successful startActivity dispatch return** in that phase/revision. Neither proves Settings
  appeared. Following dispatch, corroborate with either a fresh restricted + detached + SAFE_SYSTEM sample, or a correlated known-safe transition
  and safe-surface overlay removal in the bounded trace. Earlier/unrelated safe events do not qualify. Missing/gapped trace or changed revision stops.
- Latch corroboration observed **during the phase**; do not require SAFE_SYSTEM to remain the exact state at the later P timestamp. After P, retain
  the existing eight-second corroboration deadline, not a speculative increase. If absent, stop **INVALID:SETTINGS_RECOVERY_ORACLE_UNCORROBORATED**
  while preserving `PhysicalHomeAndSettings=OWNER_PASS`. The unresolved disagreement must be reviewed; it cannot silently pass calibration.
- Additional debug fields describe only the spike's own overlay View: `windowVisibility` (-1 absent, 0 visible, 4 invisible, 8 gone), `windowFocused`
  and `viewAttached`. They distinguish a held object reference from framework-visible state; they do not prove human visibility, occlusion or touch
  blocking. No other window, node, content, package history or screenshot is inspected. Release hooks remain no-op.
- After corroboration, ordinary re-entry must still be physically blocked; after Clear, a real touch must reach the ordinary fixture. Save each
  result as it happens, including partial checklists. Home/Settings/re-entry/Clear never add expiry samples.

A latched safe transition is phase-existence evidence, **not broad Settings usability or proof of the latest button attempt**. Q2 captured this
distinction: earlier SAFE evidence coexisted with a later physical recovery failure. Physical F must remain FAIL. Opening only top-level Settings
does not satisfy designated recovery if required destinations are blocked or return-to-Settings becomes unusable. The newly identified failing
paths are regression cases; no OEM package is declared safe merely because a Settings link opens it. Separate Home, destination and recovery
observations in the next diagnostic; do not manufacture separate machine observations from the old combined field.

Historical Q2 used **`-CalibrationOnly`** and exposed the physical recovery failure. Q3 then used the diagnostic-only
`-RecoveryDiagnostic` contract and started no qualification row. It established top-level Settings PASS, Digital Wellbeing FAIL with ordinary
reattachment, recovery FAIL and a verified lab bailout. A repaired build must pass a fresh focused calibration before a separately authorized full
run. This boundary does not lower or increase AC-3's 100 independent samples.

The runner creates an exclusive timestamped directory with bundle/installed APK hashes, source and runner/protocol hashes, start/end time, owner
device class, automatically observable build/settings, calibration, pre-reset metric export, per-attempt JSON/CSV, typed trace JSONL, checkpoints
and Markdown summary. Every observer result and software invariant has separate fields. Raw shell/dumpsys/logcat content is never saved.
Reports leave missing fields **UNSPECIFIED**. The agent later ingests these directly from mounted Windows storage.

`attempts.json` and CSV retain completed calibration, completed qualification rows and the partial current row, with their phases distinguished.
Zero qualification rows yield `Count=0` and null p50/p95/max. Calibration is preserved separately in `calibration.json` and excluded from those
statistics. `safety-calibration.json` is written at phase start and after each observation/poll, including an uncorroborated owner PASS.

Normal exceptions/quit use independently guarded finalization: radio recovery first; per-radio readback; network report; manifest; attempts;
partial safety record; statistics; JSON and Markdown summary. Failure of one does not skip the others or replace the original status/reason.
Summary writers have independent fallback paths. `FinalizationErrors` reports secondary failures and blocks qualification/exit success; it never
turns an observed PASS into a physical failure. No software can guarantee writes on a full/unwritable filesystem or cleanup after a hard host kill.
Existing stopped run directories are never rewritten to fabricate missing reports.

Fixture focus/resume/tap counters are stored separately in `fixture.jsonl`. They corroborate state and can expose a failure, but do not prove
visual occlusion or touch interception. Global radio/clock/power flags are checked before each arm; full device metadata and installed hashes
are checked at both ends. This is sampled configuration continuity, not proof that an unobserved transient setting never changed.
The runner allows up to three seconds for an asynchronous fixture focus callback before starting the ten-second hold. Failure to establish this
oracle is INVALID, not proof of a physical no-block. This wait does not change or subtract from the measured expiry-to-attachment latency.

## Offline and device gates

The no-INTERNET manifest is useful static evidence but does not itself execute TIME-04/NET-01. Record radio/settings state. An offline active-oracle
run remains outstanding for AC-3. Q7 requires `-OfflineNetwork`; invoking it explicitly authorizes
temporary Wi-Fi/mobile-data disabling on this lab device. It records original flags before modification, verifies disabled flags and restores only
the flags it changed in `finally`. Wi-Fi and mobile recovery/readback are independently guarded; both recorded original flags are verified, even
when only one was changed. `network-restoration.json` contains per-radio original/changed/observed/status fields and UTC. No airplane-mode, SIM,
Bluetooth, account, permission or host settings are changed. The owner confirms no other
Internet connection once; radio flags alone cannot establish connectivity. Failed restoration is recorded and requires owner recovery from
`network-original.json`; a hard host/power kill cannot guarantee automatic restoration. Without that opt-in, Q7 refuses to run and radios are
never changed.

The target-specific commands are verified against Android 10 AOSP [Wi-Fi svc](https://android.googlesource.com/platform/frameworks/base/+/android-10.0.0_r47/cmds/svc/src/com/android/commands/svc/WifiCommand.java)
and [data svc](https://android.googlesource.com/platform/frameworks/base/+/android-10.0.0_r47/cmds/svc/src/com/android/commands/svc/DataCommand.java),
reviewed 2026-09-06. The d81f19a run verified Wi-Fi disabling on this Mi 8; final restoration was not captured. New Q2 restoration/readback still
requires owner-run validation; a denial stops without privilege escalation.
API 28, Android 15/API 35, Android 16/API 36 and each proposed OEM configuration require physical evidence under the parent protocol. Mi 8/API 29
cannot substitute. Other matrix rows and policy/go-no-go remain open even after this run succeeds.

Debug window semantics: [Android View](https://developer.android.com/reference/android/view/View#getWindowVisibility()),
[window focus](https://developer.android.com/reference/android/view/View#hasWindowFocus()),
[attachment](https://developer.android.com/reference/android/view/View#isAttachedToWindow()), reviewed 2026-09-06. These APIs are diagnostics, not an independent physical oracle.
