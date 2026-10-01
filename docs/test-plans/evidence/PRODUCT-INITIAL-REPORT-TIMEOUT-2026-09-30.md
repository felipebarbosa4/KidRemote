# OD-51 initial-report timeout after enrollment - 2026-09-30

- **Goal:** Identify the next unproven synchronization boundary after the first completed enrollment/preparation attempt, without another physical run.
- **Context:** Owner result from frozen source `452396d834dd76410a72094bd1e3e27e3c2954df` reports `INVALID` / `INITIAL_REPORT_TIMEOUT`, slice cleanup `NOT_REQUIRED`.
- **Constraints:** Preserve all original journals, metadata and bundles. No agent ADB, app action, credential/content read, reset, cancellation, policy mutation, extended recovery exception or physical-PASS claim.
- **Done when:** The durable attempt is matched, backend report state is inspected within the exact synthetic lease, misleading handoff instructions are retired, and one bounded owner observation supplies the missing current Android state.

## OBSERVED: completed attempt, not a Lock test

[Structured result, journal inventory and bounded backend snapshots](PRODUCT-INITIAL-REPORT-TIMEOUT-2026-09-30.json) record attempt `8e407e8b-eddb-4d65-b1bc-1819155b1d52`. All twelve files were hashed; eight journal rows form a valid chain and the resume-review checksum validates. There are no partial rows or extra directories.

The sequence is BEGIN, PAIRING_CLEANUP_ADMITTED, REVERSE_ADMITTED, ENROLLMENT_ADMITTED, SETUP_ADMITTED, POLICY_ADMITTED, VERDICT INVALID, CLEANUP NOT_REQUIRED. The initial policy was admitted at `2026-09-30T23:34:59.7446137Z`; the verdict was recorded at `23:35:31.9653174Z`. No LOCK_ADMITTED or UNLOCK_ADMITTED row exists. All three independent observation flags and corroboration remain false.

The original result records backend stop with synthetic enrollment retained and removal of the attempt's own reverse. `NOT_REQUIRED` describes the slice's Lock cleanup because no Lock request was admitted. It does not mean the initial allowance was deleted, or that an independent input test proved the tablet unrestricted.

The result's `preparation.backendDevice=false`, empty local-state flags and `credentialProof=NOT_ESTABLISHED` describe the pre-enrollment decision. They are not a final inventory. Likewise, `primary.expectedVersion=0` is the initial value of the not-yet-created Lock request, not a canonical policy-version measurement.

## OBSERVED: paired backend, configured allowance, no report

The existing lease record, exact database ID, ownership labels, source/schema, pinned image, named-volume mount and absence of published ports were verified. The stopped database alone was temporarily started for bounded READ ONLY SELECT/ROLLBACK inspections, then restored to its stopped state after each inspection. No session, device, policy, credential or receipt was changed. No Auth/gateway/physical runner was started.

At `23:38:20.240853Z`, the main synthetic household had one unrevoked device. Its pairing session was consumed at `23:34:10.281298Z`. The canonical policy was configured at version 1, daily limit 3600 seconds, manual lock false. The sole command was SET_DAILY_LIMIT with the same UUID as the journal's POLICY_ADMITTED event. No report or receipt was stored, and there was no Lock/Unlock command.

A second bounded snapshot at `23:40:09Z` found no row in `private.sync_snapshots` for this exact device. Only existence/count and selected nonsensitive cache metadata were queried, not credentials or a raw snapshot payload. This is not evidence that no network request was attempted; a failed or rolled-back transaction would leave no snapshot either.

## Source-derived boundary and UNKNOWN cause

[LiveSlice](../../../tools/enforcement/product-oracle/LiveSlice.psm1) polls the existing canonical Initial callback for up to 30 seconds. A missing report is rejected by [Canonical](../../../tools/enforcement/product-oracle/Canonical.psm1) as DEVICE_EPOCH_OR_POLICY; stale/concurrent reports and unsuitable health also prevent admission. The historical timeout did not retain individual poll results. The later database snapshots narrow the current backend finding to absent report, not a demonstrated enforcement failure.

[ProductOracle](../../../tools/enforcement/product-oracle/ProductOracle.psm1) awaits Initial before starting the positive fixture control or constructing/sending Lock. Do not interpret the console announcement mentioning LOCK/UNLOCK as proof that those operations ran.

The exact cause remains UNKNOWN. Candidate boundaries include initial sync dispatch, HTTP/transaction completion and local identity/storage/retry state. Source inspection alone does not identify which happened on the Samsung. No timeout increase, synthetic ACK, speculative runtime fix, or reset is justified by this result.

The old pre-setup empty-state exception is not a recovery plan for this now-configured device. Do not add this POLICY_ADMITTED attempt to that exception, reclassify older results, or discard enrollment to get past the gate.

## Next owner action: current structural metadata only

The most recent prior metadata observation is still ee5cb367 at `19:31:42.1862523Z`, before the successful enrollment. It cannot describe the state after this attempt. One new read-only observation is required to distinguish absent identity, stored identity without accounting, and accounting/retry/ACK-path candidates without reading their contents.

The existing metadata-only probe remains reusable for this diagnostic purpose: source `8ebcc89e0b483af1f5d3cf3a081fca640da37e10`, manifest SHA-256 `e4d8ab75d9b6c44ca08d3c5cb3958e3992afa4a254518f4fdebb450ba0cc29ee`. Its manifest and all 489 listed file hashes were reverified in this review. The agent did not invoke the probe or any ADB command. The owner command is recorded in existing PR #24. It does not enroll, revoke, clear state, change permissions or exercise Lock/Unlock.

Preserve any provenance/reverse/read failure and do not rerun automatically. The known exact Samsung IDS structural classification remains separate from the old generic probe output; do not delete that file. Do not scan another QR or select the fresh-QR/removal buttons.

The product source-452396d command is retired from repeat execution pending this review. Its immutable bundle and all earlier results remain unchanged. KR-003 qualification, product physical acceptance and all release/support/Play gates remain open.

## Validation of this evidence update

Local WSL execution passed all six existing guidance tests, the repository validator and whitespace checks. Original attempt/diagnostic hashes and the host resource record were rechecked unchanged. Only evidence/current-routing documents were edited; no new Android, backend or runner test result is claimed. The separate CI for this documentation checkpoint is not validation of a new executable bundle.

## Post-enrollment observation received - 2026-10-01 UTC

**Goal:** locate the first unproven child-sync boundary without repeating the product attempt. **Context:** the owner completed the requested post-enrollment structural probe. **Constraints:** no device/backend operation, private-state content read, reset, revocation, APK change or recovery-catalog amendment. **Done when:** the observation and its limits are recorded and the next missing diagnostic is distinguished from a new physical trial.

[Observation 3143554f](PRODUCT-POST-ENROLLMENT-METADATA-2026-10-01.json) is recorded at `2026-10-01T01:34:58.3254981Z`. The exact owner-local JSON is 3,678 bytes, SHA-256 `6d0124c37009bcaa04e4a3ad2fa948db3d9e856497385d63f561053750431ed9`. This repository representation changes only CRLF to LF, SHA-256 `c79f16040849d19fbe358729850e573852a2899e63fd9650adfc4f237213e110`; restoring CRLF reproduces the original bytes. The original host diagnostic is unchanged.

**OBSERVED:** exact configuration, child APK/signer and fixture provenance passed; the fixed lab reverse was absent; metadata parsing completed and the temporary host APK was removed. Known-present product kinds are `identity`, `syncRetry` and `consent`. Four generic runtime kinds and the same 108-byte Samsung IDS structural entry complete the eight-file inventory. No known `pairing`, `accounting`, accounting sidecar/write-intent or sync-page-progress kind is present in this snapshot. This is not a decrypted identity, consent-value or retry-state observation.

The old generic probe still reports `UNKNOWN_DURABLE_FILES_PRESENT` and `productPhysicalOracle=BLOCKED`. Preserve these original fields. The [existing exact Samsung classification](PRODUCT-SAMSUNG-IDS-CLASSIFICATION-2026-09-16.md) accounts for the one structural IDS entry only on the already-recorded configuration; it does not make this configured device an empty-state recovery candidate. Do not read or delete the IDS file.

**INFERRED:** the unresolved boundary is before the first locally evidenced accounting snapshot, rather than an independently demonstrated Lock failure. The previous backend report/cache observations and this later structural observation were made at different times. They do not prove which HTTP, scheduler, validation or storage step failed. No new backend query was made for this update.

**UNKNOWN:** whether the stored identity can be decrypted and authenticated, whether the retry record is valid or stopped/pending, its reason, and whether initialization ever attempted a write. The existence of `syncRetry` is not proof that a retry executed; the presence of `consent` does not prove its value or current system permission. Preserve `INVALID / INITIAL_REPORT_TIMEOUT / NOT_REQUIRED` as the original slice result, not an enrollment or enforcement PASS.

## Proposed next diagnostic - owner authorization required

The current OD-51 metadata authorization explicitly excludes private file contents. `RetryStore` in `SyncRecovery.kt` already persists `pending`, `stopped`, `reason`, `attempt`, `boot`, `due` and `delay`, together with technical identity binding. Reading those values is outside the completed structural probe's scope. No such read or implementation was performed, and no new permission is inferred from folder access.

Propose one owner-operated, fixed-package read of only `no_backup/sync-retry` (bounded to the existing 1,024-byte format), reduced locally to checksum/schema validity, pending/stopped, the existing reason enum and bounded attempt/timing indicators. No raw body, identity binding, credentials, arbitrary paths, logcat, screenshot, network operation, app launch, consent change or state write may be retained or emitted. The encrypted identity and all other app files remain outside that proposal. Missing/malformed/oversized input must produce a typed diagnostic, never trigger repair or fallback content reads.

This is a proposal, not an approved extension or runnable handoff. Ask the owner before implementing/executing it. If approved, reuse the existing metadata-probe provenance and command boundaries, test synthetic valid/malformed/secret-leak cases and require exact-source validation before one owner command. Do not repeat the generic structural probe or the product runner meanwhile. The configured-policy history remains excluded from pre-setup recovery.

### Validation of the post-enrollment evidence update

Local WSL passed the six existing guidance tests, repository validation and patch whitespace checks. The new metadata representation reconstructs the exact original CRLF bytes. The twelve original timeout-attempt files, its separate durable diagnostic, the original structured timeout record and existing recovery implementation/catalog were rehashed unchanged. Only evidence and current-routing documentation changed. No new Android/backend/runner test or physical acceptance is claimed; the proposed retry-summary diagnostic is not implemented or authorized.
