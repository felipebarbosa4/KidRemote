# KR-003 Android physical feasibility protocol

- **Goal:** Generate reproducible evidence that either supports or rejects the consumer Accessibility candidate.
- **Context:** Desktop build/unit/static results cannot establish enforcement, emergency safety, lifecycle recovery or OEM behaviour.
- **Constraints:** Authorized sanitized lab devices only; no destructive personal-device tests; one evidence set per exact model/OS/build/user/battery configuration.
- **Done when:** Every required matrix row has actual evidence or an explicit unsupported boundary, each candidate meets its explicitly approved expiry evidence contract, and owner go/no-go is recorded.

## Candidate record

For a new device, first use the [generic onboarding protocol](KR-003-DEVICE-ONBOARDING.md). It records only manufacturer/model, Android/API,
security patch/build ID, readable battery-management flags and required permission state; it does not install the candidate before transport PASS.

After transport PASS and before candidate testing, extend that record with: evidence ID, date/timezone, observer, git commit/APK SHA-256, app version,
Android version/API/security patch/build fingerprint, primary/secondary user, Google Play system status, launcher,
battery optimization and OEM power settings, Accessibility/Usage Access state, network state and whether developer options/ADB are enabled.
Do not record device serial, accounts, real child identity or app/content history.

## Expiry performance

The precise runner contract, failure handling and evidence fields are in [qualification v3](KR-003-QUALIFICATION.md). OD-29 replaces the unexecuted
100-human Q6 workflow with [Q7](KR-003-Q7-AUTOMATED-QUALIFICATION.md): 100 active-oracle cycles plus three human checkpoint sessions. This is an
explicit evidence-model change, not a claim that telemetry became human observation.

Use the same configuration for all samples. Reset local timing samples, enable both required accesses, arm the 10-second timer and move to the
authorized disposable fixture. Q7 requires a per-cycle working input positive control, eligible use through expiry, successful attachment, 20
blocked real input taps and zero fixture focus regain across ten seconds. Repeat 100 times unattended. Human-visible evidence comes only from the
three separately identified checkpoints; record invalid/failed trials and never discard a slow valid sample.

Metric: elapsed milliseconds from the monotonic instant the local allowance mathematically reaches zero to successful overlay attachment.
Report sample count, p50, p95 and maximum plus fixture-oracle and human-checkpoint failures. Gate: p95 ≤2,000 ms and zero detected no-block/input-leak outcomes.
This metric excludes push/backend latency and does not by itself prove safe or tamper-resistant enforcement.

### Pre-qualification stability checkpoint

Before starting the 100-sample qualification after an enforcement-stability fix, run 10 **independent attempted cycles** on the exact candidate
configuration and APK hash. This staged checkpoint was adopted for the Mi 8 follow-up after the established overlay feedback-loop failure; it
does not replace, reduce, or count as the 100-sample qualification.

After preserving all earlier evidence, reset only the harness timing samples once before cycle 1 so the checkpoint's internal attachment metrics
do not mix with pre-fix samples. Do not clear app data.

Each cycle must start from a cleared restriction and a fresh arm/revision. Record the following observer results separately:

1. clearing the lab restriction makes the disposable ordinary app usable;
2. re-arming starts a new 10-second allowance and the ordinary app remains eligible through expiry;
3. expiry produces a continuously visible restriction for at least 10 seconds, with no flicker or disappearance;
4. the prospective OD-39 dual-path Home gate passes: exercise one available physical Home action without ordinary-use escape, or, when the owner confirms Home unavailable, pass the separately calibrated host-Home no-escape path;
5. the designated **Open device settings** action makes Settings visible and usable;
6. leaving Settings for a disposable ordinary app restores persistent enforcement;
7. returning through the designated safe surface and clearing the restriction restores ordinary use before the next cycle.

Record exactly 10 attempts and then stop, including failed and invalid attempts. Any failed or invalid observation keeps the checkpoint incomplete
and stops progression to the 100-sample run pending review; do not append replacement attempts to this checkpoint or silently discard them.
The operator—not the runner—must classify visible persistence, flicker, escape, safe-surface usability, re-entry enforcement and clear behaviour.
OD-39 prospectively approves two non-interchangeable Home evidence paths. Path A applies when a Home control/gesture is physically exercisable:
the owner exercises exactly one real Android system Home action and both physical observation and the independent hold oracle must show no
ordinary-use escape. `HOME_ACTION_EXERCISED_AND_RESISTED` is reserved for this path; a real escape is FAIL and uncertainty is INVALID.

Path B applies only when the owner physically confirms that Home is unavailable as presented while restriction remains visible. Absence alone
does not pass. Before relying on Path B, the unblocked ordinary fixture must be focused, the host injects exactly one fixed
`adb shell input keyevent KEYCODE_HOME`, and independent fixture state must show displacement from foreground/focus; the runner then returns and
verifies the fixture's known state. Rejection or no effect leaves Path B INVALID. Under restriction the host injects exactly one calibrated key,
while candidate restriction/attachment/health must remain continuous and the independent fixture must show no focus regain or input leak; the
owner must also observe that restriction stays effective and ordinary use is not restored. Only that combined result is
`HOME_ESCAPE_PATH_BLOCKED_WITH_CONTROL_UNAVAILABLE`. It is never physical Home resistance. Any established escape is FAIL; any uncertain signal is
INVALID. The candidate Accessibility service does not generate Home. Navigation mode is coarse contextual metadata only and neither establishes
control availability nor needs to be changed. This decision is prospective and does not alter earlier evidence.

The optional [owner-operated Mi 8 checkpoint runner](../../tools/kr003-mi8-checkpoint.ps1) can start the harness/disposable Calculator, wait,
capture only the debug trace tag and collect constrained observer entries. It deliberately does not inject Home and never converts
`overlay_attached` into a physical pass.

Report internal expiry-to-attachment samples and p50/p95/maximum independently from observer-confirmed trial results. Counts of attachment events,
safe-surface checks, Home attempts or re-entry checks are not additional expiry trials.

Repeat the candidate run at minimum on the oldest proposed API 28 configuration, Android 15, Android 16 and any proposed OEM support variants.
Current official documentation identifies Android 17 as API 37. Whether it is added to the approved KR-003 support matrix is **UNSPECIFIED**;
it cannot substitute for the existing API 36 gate without an owner support-boundary decision. See [Android 17](https://developer.android.com/about/versions/17/)
and [API levels](https://developer.android.com/guide/topics/manifest/uses-sdk-element.html), reviewed 2026-09-08.

Map each newly read configuration to those requirements before candidate installation. The Samsung SM-X400 metadata maps to Android 16/API 36 and
one exact Samsung/OEM-variant key. Its later active-oracle calibration PASS is one excluded prerequisite sample; the first 100-cycle attempt
stopped INVALID in network preflight before ARM/cycle 1, so neither required enforcement row is passed. It cannot satisfy
Pixel/current-Google, another Samsung build or another OEM row. Mi 8/API 29 evidence cannot satisfy a Samsung row, and Samsung evidence cannot retroactively change the Mi 8 outcome.

## Required functional/failure rows

| Matrix IDs | Procedure | Pass observation |
| --- | --- | --- |
| TIME-01/02/03/04 | interactive/unlocked, screen off, keyguard, zero | Only eligible time falls; visible ordinary-app restriction at zero |
| TIME-05/06 | terminate enforcement-agent process / relaunch (not just the ordinary fixture) | Durable balance restored; no fresh allowance; gap measured |
| TIME-07/08 | reboot online, then reboot offline while expired | No invented credit; degraded clock truth; downloaded expired state returns after service recovery |
| TIME-09/10/11 | wall clock ±24 h and timezone/date-line edit | No extra allowance within boot; household period contract unchanged |
| TIME-13/14 | deep sleep/doze and update | State preserved; elapsed clock behaviour reconciled; expiry result measured |
| TIME-16 | multi-window/PiP/launcher/video | Total counted once; safe enforcement across surfaces |
| PERM-01 | revoke Usage Access mid-use | Permission required and uncertainty surfaced; no Healthy state |
| PERM-02 | disable Accessibility while blocked | Applied status clears/degrades; no false acknowledgement |
| PERM-03 | incomplete setup | No enforcement-ready claim |
| TAMP-01/02/03 | force-stop, uninstall, clear data | Document bypass/recovery boundary; do not call it supported if state/control is gone |
| TAMP-04/05 | safe mode, guest/secondary user | Explicit unsupported/bypass result; primary-user state is not misreported |
| TAMP-06 | battery optimization and OEM kill | Behaviour/recovery time recorded for each candidate setting |
| TAMP-07 | ADB/developer options | Explicit adversarial boundary; never use a personal device |
| TAMP-08 | root/unlocked bootloader | Research/authorized disposable hardware only; no unsupported assurance |
| SAFE-01 | dialler/emergency, TalkBack, IME and permission dialogs while blocked | Accessible without hidden gestures or trapping; never call a live emergency service for testing |
| SAFE-02 | offline local help/recovery/removal route | Approved recovery remains reachable; any ordinary-use bypass is recorded |

Also test package identity missing/unrecognized, service interruption, storage commit failure where injectable, screen signal during process loss,
and no UsageEvents in the reconciliation window. Unknown/safe surfaces are expected to fail open in this spike; that is not an automatic pass.
These IDs follow MATRIX.md; the earlier physical table had placed TalkBack/IME under SAFE-02 and mislabelled deep sleep/multi-window.

## Evidence and decision

Use the [evidence template](evidence/README.md), attach aggregate timings and sanitized screenshots/video hashes where permitted, and mark every
row Passed, Failed, Unsupported or Not run. A failure cannot be converted to pass by documenting it. Physical evidence does not equal Play approval.

If consumer mode fails latency, safe-surface, lifecycle or policy gates, ADR-0002 requires a scope/support change or a separate managed-device proposal.
Do not move the spike into `apps/child-android` merely because it builds.
