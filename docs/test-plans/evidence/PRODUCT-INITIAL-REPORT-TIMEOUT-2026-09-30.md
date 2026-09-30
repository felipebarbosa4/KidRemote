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
