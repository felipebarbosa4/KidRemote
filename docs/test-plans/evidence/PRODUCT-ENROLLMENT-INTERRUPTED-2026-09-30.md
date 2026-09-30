# OD-51 interrupted enrollment review - 2026-09-30

- **Goal:** Reconcile the interrupted source-de6a488 owner attempt before any further product run.
- **Context:** The owner reports scanning the QR, stopping the execution, and three refused repeats. The reported recovery-screen wording is approximate.
- **Constraints:** Preserve original journals/bundles/diagnostics; no ADB, app action, cancellation, data clear, history-catalog exception or product rerun in this review.
- **Done when:** Saved history and task-owned backend metadata are recorded, stale handoffs are retired, and one bounded owner read-only action identifies the missing Android state.

## OBSERVED: one unfinished journal and three refused repeats

[Structured evidence and SHA-256 inventories](PRODUCT-ENROLLMENT-INTERRUPTED-2026-09-30.json) identify journal `685624ea-8f7d-4d0f-8235-5b9a79bd261b`, source `de6a4882488f9dd19b5ad7b7470bcd76754345fd`, manifest `3654a62db1213ca8f3b027e0cb8707b4bc51ca4dffaa7a8aa8aeacd6c65190b4`.

Four complete, validly chained rows are present: BEGIN, PAIRING_CLEANUP_ADMITTED, REVERSE_ADMITTED and ENROLLMENT_ADMITTED. They end at 19:00:45.4583588Z. The resume-review checksum also validates. No temporary row, VERDICT, CLEANUP or result.txt exists. This is an unfinished attempt, not a recorded PASS/FAIL/INVALID verdict. Absence of a temporary row does not mean the experiment completed. No setup, policy or lock admission was recorded.

The three separate durable diagnostics at 19:02:23.8013196Z, 19:02:39.3216371Z and 19:02:47.5729736Z all report JOURNAL_READY / PRIOR_ATTEMPT_REVIEW_REQUIRED. Their own primary results are INVALID:INVALID_HOST_PREFLIGHT / UNVERIFIED, backend NOT_STARTED and reverse NOT_CREATED. None supplies the missing original verdict or proves original tunnel cleanup. The interrupted journal is not added to ReviewedInvalidAttempts.json.

## OBSERVED: task-owned backend snapshot

The exact lab database was verified against its recorded container ID, labels, source/schema, pinned image, named-volume mount and absence of published ports. It was stopped. Only that database was temporarily started for a bounded READ ONLY SELECT/ROLLBACK; its original stopped state was restored. No pairing or device row was changed by this review.

At server time 19:06:40.287846Z, the main synthetic household had zero devices. The three previously reviewed sessions were cancelled. The new session `c47322c4-f2b8-4e71-9b38-93208c03a43c` was device-less, unconsumed and uncancelled, created at 19:00:45.509469Z and expiring at 19:05:45.509469Z. It was expired at this review, which does not prove it was expired when scanned. Its association with the interrupted attempt is INFERRED from the unique new row and matching creation period; the original QR response was not persisted.

## Source-derived screen meaning; current device state UNKNOWN

[ChildActivity](../../../apps/child-android/src/main/java/dev/kidremote/child/ChildActivity.kt) displays `ResponsÃ¡vel revogou; usar novo QR` only on its pairing-recovery branch. [EnrollmentModel](../../../apps/child-android/src/main/java/dev/kidremote/child/Enrollment.kt) uses a generic recovery message when identity/contact work throws. Multiple failures share that message. The owner's approximate recollection does not identify the exact exception.

The button acknowledges a prior parent revocation; it does not call the backend to revoke a session. Its handler can remove the local pending marker only when no identity file exists. Do not click it to diagnose the issue or assume it has already revoked anything. Local identity/pending/accounting metadata and current reverse state remain UNKNOWN until a separate device observation. No screenshot, credential read or logcat capture is needed.

## Next owner action: existing read-only probe, not another product run

Reuse the existing [validated metadata probe](PRODUCT-READONLY-METADATA-PULL-INVALID-2026-09-16.md) from source `8ebcc89e0b483af1f5d3cf3a081fca640da37e10`. This review rehashed its manifest (`e4d8ab75d9b6c44ca08d3c5cb3958e3992afa4a254518f4fdebb450ba0cc29ee`) and all 489 listed files. Its exact Samsung configuration and child/fixture APK checks remain intact. No probe code or bundle was changed or executed against a device by the agent.

The owner may execute that read-only entrypoint once to observe structural file presence and the reverse prerequisite. It cannot enroll, launch, clear, revoke, change policy or run Lock/Unlock. It writes a new diagnostic on the PC and may temporarily copy the fixed public base APK for signer verification. If an existing reverse or any provenance ambiguity prevents the metadata read, preserve that result; do not remove the reverse or rerun automatically.

The source-de6a488 product command is retired from further execution pending reconciliation. Existing physical outcomes remain immutable. This review does not introduce a new product implementation, acceptance, host configuration change or reset permission.
