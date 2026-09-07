# KR-003 Q7 oracle-transport preflight

- **Goal:** Determine whether the exact Mi 8 permits Q7's single fixed ADB input operation without beginning an expiry or qualification sample.
- **Context:** Three Q7 attempts reached the focused ordinary fixture, then stopped before ARM with `INVALID:ADB_REJECTED`.
- **Constraints:** Debug fixture only; no restriction/candidate command, raw ADB output, package history, content, identifier, radio/configuration/permission mutation or destructive action.
- **Done when:** The fixture receiver is queried, one unblocked tap is attempted, and either exactly one counter increment or a sanitized rejected-operation classification is preserved.

## Established localization from Q7

Runs `run-20260906-221807-0f52b94f`, `run-20260906-221841-388db07a` and `run-20260906-221914-a4512378` all completed setup,
candidate and fixture broadcasts, fixed settings checks, offline radio transition and owner confirmation. Attempt 0 then opened the fixture and
recorded two valid focused/resumed snapshots with `taps=0` and probe coordinate `540,1956`. It stopped with `Revision=null` and
`PositiveControlTap=UNRECORDED`. By the fixed `Invoke-Expiry` order, the only operation between that last snapshot and ARM is
`adb shell input tap 540 1956`. Therefore `INPUT_TAP` is the established rejected operation; zero samples began.

The historical runner retained neither exit code nor stderr class, so it cannot establish why the Mi 8 rejected the command.

## Standalone procedure

The transport runner installs/opens only the exact Q7 fixture, obtains its sender-protected state, attempts one tap at its own coordinate, checks
for exactly one counter increment, then stops. It never arms/clears the candidate or changes radios, permissions or device settings.

For every fixed ADB operation, `operations.json` contains only an operation category enum, integer exit code and stderr class `NONE`,
`SECURITY_EXCEPTION`, `PERMISSION_DENIAL` or `OTHER`. Raw output is never written. The summary retains only fixture receiver success, numeric
before/after counters and the rejected enum/class. No package history, UI text/content, screenshot, account, serial or identifier is retained.

`PASSED_TRANSPORT_PREFLIGHT:FIXTURE_COUNTER_INCREMENTED_ONCE` establishes only Q7 input transport. `INVALID:ADB_OPERATION_REJECTED` preserves the
rejected category/class. `FAILED:INPUT_NOT_DELIVERED` means ADB reported success but the independent counter did not increment. None is an expiry pass.

Android Open Source Project documents that the shell identity normally receives the input-injection permission used by `adb shell input`; a vendor
denial is a configuration/vendor divergence, not permission to bypass Q7. [AOSP input-injection security change](https://android.googlesource.com/platform/frameworks/base/+/edff3851325467a3f56ebe87af67df326b00a318)
(reviewed 2026-09-06).

Community reports associate this MIUI symptom with a separate Developer options switch labelled `USB debugging (Security settings)`, described on
devices as permitting grants and simulated input. No current official Xiaomi document for this exact Mi 8/MIUI build was located. Its presence,
current value and effect here remain **UNSPECIFIED** until sanitized transport evidence and owner inspection establish them. Do not change it or
rerun Q7 on inference alone.
