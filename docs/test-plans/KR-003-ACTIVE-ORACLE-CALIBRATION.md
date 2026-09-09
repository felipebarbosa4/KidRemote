# KR-003 generic active-oracle calibration

Status, 2026-09-08: **PASSED on one exact Samsung configuration.** The preserved [runner-v5 result](evidence/KR-003-SAMSUNG-ORACLE-CALIBRATION-PASS-2026-09-08.md) contains one excluded sample and zero qualification rows. Historical INVALID attempts remain unchanged. This permits only preparation of the [configuration-bound qualification](KR-003-CONFIGURATION-ACTIVE-ORACLE-QUALIFICATION.md); it does not authorize its physical execution.

- **Goal:** Determine whether one exact transport-capable Android configuration can support the independent active oracle before any 100-cycle qualification starts.
- **Context:** A fixture-only transport PASS is necessary but cannot show that the candidate blocks input or stays connected. Q7's Mi 8 specialization remains blocked and unchanged; a new device requires fresh calibration.
- **Constraints:** Run only after a preserved generic transport PASS; exact disposable candidate/fixture hashes; no network/configuration mutation, screenshots, UI nodes/text/content, raw identity/history, destructive action, result pooling or qualification loop.
- **Done when:** One unblocked tap increments the fixture exactly once, one armed expiry produces a ten-second blocked hold with input/focus denial and candidate service continuity, one operator agreement response is preserved, cleanup is verified, and zero qualification rows exist.

Runner v2 independently verifies Usage Access from the `GET_USAGE_STATS` AppOp and Accessibility from current-user secure settings before ARM and
after the blocked hold. Accessibility component identifiers are parsed using Android `ComponentName` short/full equivalence; raw strings are never
persisted. `ENABLED`, `DISABLED` and `UNKNOWN` plus verification-source/parse-result enums are retained. Candidate heartbeat and candidate-health
enums are recorded separately. Any `UNKNOWN` fails closed; permission/service loss after initial success is FAIL, not a reusable setup result.
[Android 16 AccessibilityManagerService](https://android.googlesource.com/platform/frameworks/base/+/refs/heads/android16-release/services/accessibility/java/com/android/server/accessibility/AccessibilityManagerService.java)
and [ComponentName](https://android.googlesource.com/platform/frameworks/base/+/refs/heads/android16-release/core/java/android/content/ComponentName.java), reviewed 2026-09-08.

Runner v3 added a closed enum for the active host stage and whitelisted exception class plus primary-result, cleanup and finalization status, but
its first host invocation stopped before device execution because `$script:Host` collided with PowerShell's automatic read-only `$Host` variable.
Runner v4 renamed that internal state to `$script:HostState`, preserved the external `HostDiagnostic` schema and permission/oracle logic, and added
static collision plus real-entrypoint tests. Four v4 attempts then exposed a separate case-insensitive same-script-scope alias: `$armed` held the
ARM reply, `$script:Armed=$true` replaced it with a Boolean, and strict `.revision` access failed. Runner v5 removes the unused flag, uses
`$armReply`, and validates exactly one typed reply before revision assignment. It never stores the raw exception message, stack, path or command output. Cleanup remains attempted
from `finally`; a cleanup/finalization error cannot overwrite an earlier physical or typed primary result, while failed finalization invalidates an otherwise successful run.

## Bounded workflow

The separate calibration bundle performs only this sequence:

1. verify bundle integrity, ADB authorization and the exact installed/pulled APK hashes;
2. read the exact configuration again and require the candidate's Usage Access, Accessibility service, heartbeat and eligible-use health;
3. clear only the disposable lab timer, foreground the independent fixture and require one shell tap to increment its counter exactly once (**unblocked positive control**);
4. arm one fresh ten-second disposable allowance/revision while the fixture is visible;
5. wait for candidate attachment, then inject 20 equivalent taps over at least ten seconds and require zero fixture increments and zero focus regain (**blocked negative control**);
6. require no candidate trace gap, process replacement, permission loss or new service connection from the pre-arm baseline through the hold (**candidate service continuity**);
7. ask the operator once whether the visible restriction agreed with the automated result, recording P/F/I (**physical agreement check**);
8. clear only the lab timer, verify restriction release without altering the calibration latency sample, write a sanitized summary and stop with `QualificationSamples=0`.

Candidate telemetry is corroborating evidence only. The fixture has an independent package/UID and no shared storage or callback with the candidate. It exposes only its generated instance, focus/resume/focus-gain counters, touch counter and its own probe coordinate. Neither component reads node text, content, screenshots or package history.

## Result contract

- **PASS — `PASSED_ORACLE_CALIBRATION_THIS_CONFIGURATION_ONLY`:** all four technical controls and the one physical agreement check pass, cleanup is verified, and exactly one excluded calibration sample is retained.
- **FAIL:** visible disagreement, delivered blocked input, focus regain, missing block, permission/service loss or cleanup failure. Stop before qualification.
- **INVALID:** transport, hash, configuration identity, evidence correlation or operator observation was unavailable/uncertain. Stop before qualification.

The three source-`5a46f75` Samsung attempts remain `INVALID:REQUIRED_PERMISSION_STATE_NOT_VERIFIED`; v2 diagnostics do not retroactively relabel them.
The fresh runner-v2 Samsung attempt remains `INVALID:HOST_EXCEPTION`: its permission and fixture positive controls passed, but ARM-stage host handling
stopped before attachment and the blocked hold. Runner v3 does not retroactively recover the unretained v2 exception class, and its separate
startup failure is not device evidence. The four runner-v4 attempts remain independently `INVALID:HOST_EXCEPTION`; each passed permission and
positive controls and issued ARM, then stopped before attachment/blocked hold and completed verified cleanup. Runner v5 does not retroactively
relabel any historical run.

A PASS permits preparation of a new configuration-specific 100-cycle qualification bundle; it does not authorize that run by itself and is never counted among its 100 rows. The exact required OS/API/OEM matrix mapping must be recorded first. Human-only rendering/safe-surface residual risks remain separate even if calibration passes.
