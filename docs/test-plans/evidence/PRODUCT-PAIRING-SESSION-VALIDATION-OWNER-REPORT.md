# OD-51 pairing-session validation: two owner-reported executions

- **Goal:** Preserve the two reported outcomes separately and block reuse of the failed physical handoff until its durable history and backend residue are reviewed.
- **Context:** The owner pasted two Windows PowerShell results for immutable source `062fd59b545b37ac6a58b03ac67889b181a806d8`, manifest SHA-256 `3eb64b3b5dc134b3ea226c4ba1776a2767b36cae49bd161220d76aaf72dc8fd5`. Execution timestamps and attempt UUIDs were not included. These are owner-supplied console records, not an independent read of host journals or the retained backend.
- **Constraints:** No physical rerun, ADB, data clear, uninstall, history deletion, backend mutation, blanket allowlist, or invented attempt identity. Preserve original INVALID and UNVERIFIED outcomes. No change to product semantics or acceptance gates.
- **Done when:** Reports are recorded, the stale executable handoff is withdrawn, the missing evidence/access boundary is explicit, and continuation cannot silently bypass prior-attempt review.

## Report A: pairing-session validation failed

The console first printed `Preparando backend local isolado; nenhuma substituição do tablet foi admitida ainda.` and then the following JSON (formatting normalized; values retained):

```json
{
  "scope": "OD51_ONE_PRODUCT_SLICE_NOT_QUALIFICATION",
  "hostValidated": true,
  "hostFailureStage": "NONE",
  "hostFailureCode": "NONE",
  "hostFailureAction": "NONE",
  "preparationFailureStage": "PAIRING_SESSION_VALIDATE",
  "preparationFailureCode": "PAIRING_SESSION_INVALID",
  "preparation": {
    "classification": "SAFE_RESUME_FROM_ENROLLMENT",
    "packageMode": "LAB_PACKAGE_UNPAIRED",
    "path": "ENROLL",
    "credentialProof": "NOT_ESTABLISHED",
    "reviewReason": "NONE",
    "failedChecks": [],
    "backendDevice": false,
    "localIdentity": false,
    "pairingPending": false,
    "localAccounting": false
  },
  "reuse": false,
  "expectedSetupActions": 5,
  "persistentSyntheticLab": true,
  "source": "062fd59b545b37ac6a58b03ac67889b181a806d8",
  "primary": {
    "status": "INVALID",
    "reason": "INVALID:PAIRING_SESSION_INVALID",
    "cleanup": "UNVERIFIED"
  },
  "backendCleanup": "STOPPED_SYNTHETIC_LEASE_AND_ENROLLMENT_RETAINED",
  "reverseCleanup": "OWN_REVERSE_REMOVED",
  "labRecovery": "NOT_REQUIRED",
  "oldApkRestored": false,
  "newAppMayRemainInstalled": true,
  "historicalEvidenceUnchanged": true,
  "hostDiagnosticWrite": "DURABLE"
}
```

## Report B: repeat blocked by prior-attempt review

The owner invoked the same command again and supplied this separate JSON:

```json
{
  "scope": "OD51_ONE_PRODUCT_SLICE_NOT_QUALIFICATION",
  "hostValidated": false,
  "hostFailureStage": "JOURNAL_READY",
  "hostFailureCode": "PRIOR_ATTEMPT_REVIEW_REQUIRED",
  "hostFailureAction": "Host preflight failed before tablet mutation. Check the named stage and code. Docker engine availability is relevant only to DOCKER_ENGINE. Preserve this attempt and paste only this sanitized JSON.",
  "preparationFailureStage": "NONE",
  "preparationFailureCode": "NONE",
  "preparation": null,
  "reuse": false,
  "expectedSetupActions": 5,
  "persistentSyntheticLab": true,
  "source": "062fd59b545b37ac6a58b03ac67889b181a806d8",
  "primary": {
    "status": "INVALID",
    "reason": "INVALID:INVALID_HOST_PREFLIGHT",
    "cleanup": "UNVERIFIED"
  },
  "backendCleanup": "NOT_STARTED",
  "reverseCleanup": "NOT_CREATED",
  "labRecovery": "NOT_REQUIRED",
  "oldApkRestored": false,
  "newAppMayRemainInstalled": true,
  "historicalEvidenceUnchanged": true,
  "hostDiagnosticWrite": "DURABLE"
}
```

A and B are report labels, not journal UUIDs or qualification rows. B does not replace A. Neither output establishes physical enforcement, successful enrollment, or verified canonical cleanup. The false preparation fields in A describe its preflight assessment, not independently verified post-failure state. A reports removal of its own reverse separately from its UNVERIFIED primary cleanup; do not upgrade the latter.

## Source inspection and unresolved cause

**OBSERVED in source:** [New-ProductPairing](../../../tools/enforcement/product-oracle/EnrollmentHost.psm1) advances to `PAIRING_SESSION_VALIDATE`, then can reject response schema (`INVALID:PAIRING_SCHEMA`) or expiry (`INVALID:PAIRING_EXPIRY`). [Invoke-ProductEnrollmentPreparation / Throw-ProductPreparationFailure](../../../tools/enforcement/product-oracle/LivePreparation.psm1) maps any exception at that stage to `PAIRING_SESSION_INVALID`. The outward code therefore does not identify which predicate or exception occurred. The canonical wire has already returned before that stage; this does not independently prove the session's durable post-failure state.

**INFERRED:** report B is consistent with the runner refusing an unreviewed prior attempt before starting the backend. It is not evidence of a new pairing defect or permission to delete the journal.

**UNKNOWN:** exact attempt UUIDs/timestamps, original journal inventories/hashes, which validation predicate failed in A, whether a more specific cause was preserved anywhere, current backend pairing-session residue, and current child state. No clock/schema/credential diagnosis is asserted from the collapsed error alone. More specific detail may not be recoverable from the historical logs; reproduce the boundary with synthetic inputs rather than inventing the missing exception.

## Access and next bounded action

The connected host was found, but a read of the task-owned `product-slice-attempts` directory was denied by the remote connector's directory allowlist. Its current allowed directory belongs to another project. No shell or WSL workaround was used to bypass that restriction, and no permission setting was changed.

The next action is an owner-granted, scoped host-file access path (or owner-provided sanitized records), then read-only inspection of the two durable diagnostics and applicable mutation journal. Validate their exact immutable inventory before reviewing any synthetic backend residue. Do not print QR payloads, credentials, serials, raw sensitive errors, or private application contents. Do not add either report to `ReviewedInvalidAttempts.json` without actual journal/provenance evidence. No new physical run or replacement bundle is authorized by this report.

`PRODUCT_PHYSICAL_ORACLE = BLOCKED_PENDING_ATTEMPT_REVIEW`.
Source `062fd59` remains retained but is retired from further physical execution. Its bundle bytes and earlier records must not be rewritten. PR #24 and Issues #3/#10 remain open; KR-003 and product physical acceptance are unchanged.
