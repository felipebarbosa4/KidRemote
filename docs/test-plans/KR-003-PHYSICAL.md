# KR-003 Android physical feasibility protocol

- **Goal:** Generate reproducible evidence that either supports or rejects the consumer Accessibility candidate.
- **Context:** Desktop build/unit/static results cannot establish enforcement, emergency safety, lifecycle recovery or OEM behaviour.
- **Constraints:** Authorized sanitized lab devices only; no destructive personal-device tests; one evidence set per exact model/OS/build/user/battery configuration.
- **Done when:** Every required matrix row has actual evidence or an explicit unsupported boundary, each candidate has at least 100 valid expiry samples and owner go/no-go is recorded.

## Candidate record

Before testing record: evidence ID, date/timezone, observer, git commit/APK SHA-256, app version, device manufacturer/model,
Android version/API/security patch/build fingerprint, primary/secondary user, Google Play system status, launcher,
battery optimization and OEM power settings, Accessibility/Usage Access state, network state and whether developer options/ADB are enabled.
Do not record device serial, accounts, real child identity or app/content history.

## Expiry performance

Use the same configuration for all samples. Reset local timing samples, enable both required accesses, arm the 10-second timer and move to an
authorized disposable ordinary test app. A valid sample requires eligible interactive/unlocked time through expiry and a visibly perceived block.
Repeat at least 100 times. Record invalid/failed trials separately; never discard a slow valid sample.

Metric: elapsed milliseconds from the monotonic instant the local allowance mathematically reaches zero to successful overlay attachment.
Report sample count, p50, p95 and maximum from the app plus independent observer failures. Gate: p95 ≤2,000 ms and zero silent no-block outcomes.
This metric excludes push/backend latency and does not by itself prove safe or tamper-resistant enforcement.

Repeat the candidate run at minimum on the oldest proposed API 28 configuration, Android 15, Android 16 and any proposed OEM support variants.
Android 17 is currently a preview research target, not the stable production baseline.

## Required functional/failure rows

| Matrix IDs | Procedure | Pass observation |
| --- | --- | --- |
| TIME-01/02/03/04 | interactive/unlocked, screen off, keyguard, zero | Only eligible time falls; visible ordinary-app restriction at zero |
| TIME-05/06 | terminate ordinary app process / relaunch | Durable balance restored; no fresh allowance; gap measured |
| TIME-07/08 | reboot online, then reboot offline while expired | No invented credit; degraded clock truth; downloaded expired state returns after service recovery |
| TIME-09/10/11 | wall clock ±24 h and timezone/date-line edit | No extra allowance within boot; household period contract unchanged |
| TIME-14/16 | update and deep sleep/doze | State preserved; elapsed clock behaviour reconciled; expiry result measured |
| PERM-01 | revoke Usage Access mid-use | Permission required and uncertainty surfaced; no Healthy state |
| PERM-02 | disable Accessibility while blocked | Applied status clears/degrades; no false acknowledgement |
| PERM-03 | incomplete setup | No enforcement-ready claim |
| TAMP-01/02/03 | force-stop, uninstall, clear data | Document bypass/recovery boundary; do not call it supported if state/control is gone |
| TAMP-04/05 | safe mode, guest/secondary user | Explicit unsupported/bypass result; primary-user state is not misreported |
| TAMP-06 | battery optimization and OEM kill | Behaviour/recovery time recorded for each candidate setting |
| TAMP-07 | ADB/developer options | Explicit adversarial boundary; never use a personal device |
| TAMP-08 | root/unlocked bootloader | Research/authorized disposable hardware only; no unsupported assurance |
| SAFE-01 | emergency call/recovery path while blocked | Accessible without hidden gestures or trapping |
| SAFE-02 | TalkBack, IME, permission dialogs, settings, recents, split-screen/PiP | No accessibility/recovery trap; any ordinary-use bypass is recorded |

Also test package identity missing/unrecognized, service interruption, storage commit failure where injectable, screen signal during process loss,
and no UsageEvents in the reconciliation window. Unknown/safe surfaces are expected to fail open in this spike; that is not an automatic pass.

## Evidence and decision

Use the [evidence template](evidence/README.md), attach aggregate timings and sanitized screenshots/video hashes where permitted, and mark every
row Passed, Failed, Unsupported or Not run. A failure cannot be converted to pass by documenting it. Physical evidence does not equal Play approval.

If consumer mode fails latency, safe-surface, lifecycle or policy gates, ADR-0002 requires a scope/support change or a separate managed-device proposal.
Do not move the spike into `apps/child-android` merely because it builds.
