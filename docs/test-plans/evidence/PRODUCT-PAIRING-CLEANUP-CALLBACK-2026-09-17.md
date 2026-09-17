# OD-51 pairing-cleanup callback failure

[Task contract](../../exec-plans/PRODUCT-PAIRING-CLEANUP-CALLBACK-RECOVERY.md).
The adjacent JSON is the sanitized machine-readable record.

## Immutable physical attempt

Attempt `a2f91a25-0acc-4fff-848d-10fa99e5af53`, from source
`b541595a33eee5ae3a4eecd6385780ae906426b7`, remains
`INVALID:PREPARATION_ORCHESTRATION_FAILED / cleanup UNVERIFIED`. Its journal is
exactly:

`BEGIN → PAIRING_CLEANUP_ADMITTED → REVERSE_ADMITTED → VERDICT → CLEANUP`.

`ENROLLMENT_ADMITTED`, `SETUP_ADMITTED`, `POLICY_ADMITTED`, and
`LOCK_ADMITTED` are absent. The result records `reverseCleanup=NOT_CREATED`.
Before source changes, the attempt, its host diagnostic, and earlier physical
history were hashed into an independent read-only record under the task-owned
Windows state. No historical file was edited.

## Observed backend state

A disposable read-only clone of the stopped task-owned PostgreSQL volume showed
zero devices, active credentials, configured policies, manual locks, and
reports. Both reviewed device-less, unconsumed pairing sessions are cancelled.
The latest attempt therefore completed the canonical cancellation of the session
left open by attempt `28756da0-cbcf-410b-9957-d7aade9afcf4`; it did not create a
new pairing session or enroll a child.

The source-controlled review records that exact `OPEN → CANCELLED` transition.
Current-state reconciliation collapses the creation and resolution records to
one terminal session expectation. An unreviewed session, device association,
consumption, duplicate creation, invalid transition, local identity, policy,
lock, report, reverse, or APK/fixture mismatch still blocks before a new QR.

## Root cause

An offline invocation of the exact frozen module under Windows PowerShell 5.1
reproduced the failure before any ADB process started. The `Reverse` closure
called the nested stage closure, which tried to resolve the private
`Set-ProductPreparationStage` command from the dynamic module made by
`GetNewClosure()`. That command was unavailable, producing
`CommandNotFoundException`; the state consequently remained
`PAIRING_SESSION_CLEANUP` and the outer sanitizer emitted the generic
orchestration code.

The stage callback now captures the private function body before creating the
closure. A frozen-module regression invokes the real `Reverse` closure with a
synthetic nonexistent ADB executable and requires the stage to reach
`REVERSE_CREATE` before the expected process failure. This validates the
callback boundary without contacting a device.

