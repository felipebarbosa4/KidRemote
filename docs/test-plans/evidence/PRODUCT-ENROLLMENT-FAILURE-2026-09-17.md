# OD-51 post-preflight enrollment failure review

[Task contract](../../exec-plans/PRODUCT-ENROLLMENT-FAILURE-RECOVERY.md).
The machine-readable review is
[`PRODUCT-ENROLLMENT-FAILURE-2026-09-17.json`](PRODUCT-ENROLLMENT-FAILURE-2026-09-17.json).

## Preserved physical attempt

The product attempt is `28756da0-cbcf-410b-9957-d7aade9afcf4`, from immutable
source `863a977407b1f7d5a072b1e6284de0847a5ed0c4`. Its result remains
`INVALID / INVALID:HOST_OR_TRANSPORT_FAILURE / cleanup UNVERIFIED`, with SHA-256
`fbd510ce8449d0788d53eef7446512f75a286e3ef0b1135f32f3095b176b93bd`.
The separate host diagnostic is `a0b601e2-fc2c-4ca7-85a3-9418d3394a4f`, SHA-256
`2c412e0bedc3e6baaa164babc6e9f334e12e8331523251081867e1ba08591636`.
Neither record was edited.

The immutable journal is exactly:

`BEGIN → PAIRING_CLEANUP_ADMITTED → REVERSE_ADMITTED → ENROLLMENT_ADMITTED → VERDICT → CLEANUP`.

Thus `ENROLLMENT_ADMITTED` is the last admission. `SETUP_ADMITTED`,
`POLICY_ADMITTED`, and `LOCK_ADMITTED` are absent. Cleanup remains
`UNVERIFIED`; the independently checked reverse result remains
`OWN_REVERSE_REMOVED`.

## Failure boundary and renderer hypothesis

The retained backend proves that pairing-session creation committed 52 ms after
`ENROLLMENT_ADMITTED`. The console never printed `QR_WINDOW_READY`, so the failure
is bounded after pairing creation and before the scan instruction. The old runner
did not persist an enrollment stage, exception category, process exit, output
bounds, or QR-window phase. The exact failing substage and operational root cause
are therefore **UNKNOWN**, not backfilled.

The source hypothesis is real but not established as the physical cause:
`Invoke-ReviewProcess` converts its process failures to `READ_ONLY_REVIEW_INVALID`,
which the outer runner converted to `SANITIZED_HOST_EXCEPTION`. A host-only replay
with the same frozen Java/JAR and a synthetic QR value returned exit 0, 1,256 bytes
of valid Base64 PNG, empty stderr, and also passed the generic helper. This rules
out a deterministic normal-stderr failure on the current host; it cannot recover
the unrecorded physical exception.

## Read-only retained-backend review

The stopped original volume was mounted read-only into a disposable copy. Only
the synthetic product scope and structural session/device state were queried; the
original database was never started or modified. The product scope contains zero
devices, active credentials, configured policies, manual locks, and reports.

It contains exactly two reviewed sessions:

- the earlier session is unconsumed, device-less, and already cancelled;
- `53f9f593-cd45-4b60-89fa-87f7cc3241d9`, created at
  `2026-09-17T02:12:25.690Z`, is unconsumed, not cancelled, and device-less.

The second session is temporally and structurally attributable to this attempt.
It is not enrollment. A replacement runner may cancel only that exact session via
the canonical `finish_pairing` path, confirm no device exists, and then create one
fresh QR. A missing, changed, consumed, additional, or device-bearing session
blocks before mutation.

The physical preflight established the exact LAB APK/fixture and absent local
identity, pending pairing, and accounting. No backend redemption occurred.
Because there was no post-attempt private-state observation, the replacement
runner must revalidate all of those live facts before admitting cleanup or a new
QR.

## Independent disposition

The latest INVALID attempt is reviewable only through its complete immutable file
inventory and the exact backend-session state above. Any `POLICY_ADMITTED` or
`LOCK_ADMITTED` history, inventory change, active restriction, local identity,
backend device, saved-device pointer, reverse, package mismatch, or session
mismatch remains fail-closed. This review does not rewrite the attempt or promote
its cleanup to verified.

The replacement reports `preparationFailureStage` and
`preparationFailureCode`, uses a dedicated bounded QR renderer, and never writes
QR input or raw stderr to evidence. The renderer discards bounded subprocess
stderr when exit status and the decoded PNG are valid, while nonzero exit,
oversized output, malformed Base64, and non-PNG output remain typed failures.
The current cataloged stages include pairing
creation/validation, QR process/output/window/readiness/poll/timeout, child open,
both consent steps, and initial policy.
