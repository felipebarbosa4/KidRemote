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

## Authorized bounded retry diagnostic preparation

The owner approved the proposed fixed-file diagnostic after observation `3143554f` and requested no repetitive authorization prompts. The scoped grant is appended to DECISIONS-LOG; current work is no longer waiting for that approval. Physical ADB remains owner-operated. This preparation has not read the real retry file or run any Android/backend operation.

The existing metadata entrypoint now supports explicit `-RetrySummary`, admitted only by a matching `OD51_BOUNDED_RETRY_DIAGNOSTIC` immutable manifest. Default structural metadata mode remains separate. The same exact target, APK/signer, fixture, reverse-absence and temporary public-APK verification gates precede the new read. No product-runner modules are imported.

Only `no_backup/sync-retry` may be read. The fixed shell program rejects missing/nonregular/symlink/unreadable/oversized input and uses a bounded transfer with before/after metadata checks. There is no backup, identity, credential or arbitrary-path fallback. The host holds the record transiently in memory, validates its 1,024-byte bound, CRC32 and restricted flat writer schema, and emits a fixed technical projection. It rejects duplicate/unknown keys, wrong scalar types, malformed framing, invalid bounds and unsupported reason values without returning the raw body or identity binding. No raw record/hash is retained. CRC32 validates format integrity, not identity authenticity.

The projection contains pending/stopped, reason, attempt count, bounded delay, boot/deadline presence and explicit legacy-reason derivation. It does not expose the binding or absolute monotonic deadline, compare a device deadline to the host clock, claim credential validity, or identify the historical exception. A valid later record is a snapshot only. Missing or invalid input yields a typed stop, not repair or rerun.

Local Windows PowerShell 5.1 validation: 119 existing metadata assertions, 721 retry assertions over 65 synthetic cases with independently generated Python-zlib CRC fixtures, and 395 native fake-ADB entrypoint assertions passed. Synthetic cases cover success, legacy format, missing/malformed/oversized/changed data, privacy sentinels, manifest/switch disagreement and provenance/reverse failures. The expanded native test also rechecks original structural behavior and evidence preservation.

WSL validation: eight new fixed-shell filesystem tests passed; they preserve input bytes and reject symlink/directory/oversized files without reading backups. Three freezer/capability tests and six guidance tests passed. Full Linux discovery, repository/whitespace checks and exact-source CI remain required before freezing. Native PowerShell 7 is not available on this host; its required tests run in CI, not as an invented local result.

An initial local metadata assertion expected the old constant scope expression (CHECK_103); it now verifies the two explicit modes and matching manifest instead. A documentation-edit expression failed before commit; only this session's affected routing drafts were restored from the exact `2b45dd0` source and reapplied, then guidance/whitespace checks passed. No failed validation was called physical evidence and no historical device state was altered.

The existing metadata freezer now requires the full exact-source Planning checks workflow, not the lighter guidance workflow. It reuses public Java/apksigner bytes from the hash-verified prior immutable metadata bundle instead of mutable workstation installs. The fixed new shell file has LF checkout semantics across Windows/Linux. Frozen product bundles and Android binaries are unchanged.

Implementation references: the Android app's existing RetryStore is the schema authority. The parser uses documented [.NET regex anchors](https://learn.microsoft.com/en-us/dotnet/standard/base-types/anchors-in-regular-expressions) and strict [UTF8Encoding](https://learn.microsoft.com/en-us/dotnet/api/system.text.utf8encoding). [Toybox head source](https://raw.githubusercontent.com/landley/toybox/master/toys/posix/head.c) documents byte-limited output; no physical Toybox execution is inferred from host tests.

## Verified bounded retry diagnostic handoff

Frozen executable source `6d299495a16a8f4135e507a8bae2af0870f3395b` completed Planning checks `36804419951` with all six jobs successful, including Linux and native Windows PowerShell 5.1/7 coverage; guidance `36804419916` also succeeded. Only this exact executable source is admitted. The existing host-only freezer then exited zero.

The owner-local bundle is `%LOCALAPPDATA%/KidRemote/read-only-retry-probes/6d299495a16a8f4135e507a8bae2af0870f3395b`, manifest SHA-256 `a8cfb55c45fe7e9093a73d804c113eae2c38c542dfccb1de8fcf99b49f888be1`, entrypoint SHA-256 `4dc51a7db9aada30c34940361ec56595520ec1e410d4f069a2ab0b6d507075b2`. A separate verifier rehashed all 492 listed files, verified the exact inventory, LF fixed shell script, scope, bounds and absent incomplete marker. It wrote only public readiness metadata to the host validation directory.

The next command is `Read-CurrentMetadata.ps1 -RetrySummary` from that pinned directory, recorded in PR #24. It is a diagnostic read, not a new product trial, cleanup or acceptance. Physical execution is NOT_RUN and productPhysicalOracle remains BLOCKED. The actual retry file has not been read by this preparation, and the original timeout cause remains UNKNOWN. Later readiness-only documentation commits do not change or rebuild these immutable executable bytes.

## Retry framing failure and host-only correction - 2026-10-01

**OBSERVED:** owner diagnostic `cd4c4627-39ef-49b8-8e8c-af6a321c65e4` at `2026-10-01T03:54:11.1262818Z` passed the exact configuration/APK/signer/fixture and reverse-absence checks, then stopped at RETRY_PARSE / RETRY_FRAME_INVALID. Checksum and schema were NOT_CHECKED; all retry-state fields were null. It is a diagnostic failure, not evidence of corrupt retry state, an AUTH/PROTOCOL/STORAGE stop, or the original timeout cause. [Preserved sanitized result](PRODUCT-RETRY-FRAME-2026-10-01.json).

The original PC result is 3,332 bytes, SHA-256 `fccb41360e0216e2b5b99cfc07b7020c3aa7f8666dc1d8060da45d2a8c92c619`. The repository representation changes only CRLF to LF, SHA-256 `f1bd164d97786031dec1453a307127de574a83cecccd8cadacddba0bc3f3eabf`; reversing that normalization reproduces the original bytes. All 96 observed files under the existing diagnostic/metadata/product-attempt directories were rehashed unchanged. No raw retry content was recovered or read again.

**OBSERVED, synthetic host reproduction:** the old parser accepted a CRC-valid LF fixture and rejected the same fixture after LF-to-CRLF transport conversion with precisely RETRY_FRAME_INVALID / NOT_CHECKED. This was executed in native Windows PowerShell 5.1, not on a device. A separate host-only `adb.exe version` invocation (no server connection or target operation) produced four CRLF lines. The [AOSP shell callback](https://android.googlesource.com/platform/packages/modules/adb/+/refs/heads/android15-qpr2-s8-release/client/commandline.h) writes through the host stream. Neither the upstream source nor the version-only output proves the bytes returned by the historical Samsung shell call. Its precise framing remains UNKNOWN because raw data was deliberately not retained. CRLF is a supported causal hypothesis, not a recovered physical exception.

**Implemented:** the same fixed single-file diagnostic now transports bounded bytes as an explicitly versioned HEX1 frame. The parser accepts LF/CRLF only in transport framing/hex whitespace and reconstructs the payload bytes before strict UTF-8, CRC32 and unchanged writer-schema validation. It never normalizes the checksum-covered record. The maximum underlying read remains 1,025 bytes including the oversize sentinel, with 1,024 bytes maximum admitted and a 4,096-character encoded-frame bound. The [AOSP toybox option declaration](https://android.googlesource.com/platform/external/toybox/+/8e0a71016dd12b049c1cb5e07017e21842a529aa/android/linux/generated/newtoys.h) includes the `od` byte-count/address/type options used by the fixed command; actual Samsung execution remains separate evidence.

The existing manifest additionally pins HEX1, rejecting mismatched framing versions before any private read. No raw, encoded, hashed-body or identity-binding value is emitted or saved. Missing, changed, malformed, invalid-UTF8 and oversized data still stop; no backup/credential fallback, expanded ADB command, setting change, app launch, backend call, reset or repair was added. The prior immutable source-6d29949 diagnostic remains unchanged and is retired from repeat use.

**Executed validation:** new protocol tests first failed against the old parser. The corrected native PowerShell suite passed 119 generic-metadata assertions, 1,036 parser/privacy assertions over 95 synthetic cases, and 505 final actual-entrypoint assertions with fake ADB only, including unknown/missing manifest framing rejection. These include LF and CRLF, exact CRLF bytes inside the checksum-protected JSON, and rejection of a checksum computed over different normalized bytes. Ten Linux synthetic-filesystem tests passed, including byte-exact transport and the 1,024-byte boundary; three freezer/capability checks and six guidance checks passed. Full exact-source CI must pass before freezing a replacement. Local PowerShell 7 remains unavailable and is not claimed tested locally.

The first temporary test wrapper reported failure despite captured success output and empty stderr; that wrapper result was not used as a test PASS. Its logs remain separate; all three tests were rerun directly with checked exit code zero. No product result was relabeled and no failing assertion was suppressed.

**Remaining boundary:** the owner requested that subsequent PowerShell testing be performed directly. Safe host reproduction, implementation and tests were performed on their computer without additional permission prompts. No agent physical ADB operation or private-device read was performed. The actual retry indicators and original INITIAL_REPORT_TIMEOUT cause remain UNKNOWN; product controls stay blocked, and no configured-policy recovery exemption was added.

## Verified HEX1 diagnostic handoff

Frozen executable source `c5b68a8728d8d3cc97d638ae4d6d4ed0b17e83b8` passed full Planning checks `36813640985` (all six jobs) and guidance `36813640967`. The existing freezer completed successfully. A separate verifier checked all 492 listed file hashes, exact inventory, expected HEX1 scope/limits, LF device-shell source, and absence of an incomplete marker. Manifest SHA-256 `db04cb64702ecdd9448396a3dae85fa2e8e3b1468c5c9838cbd39d02f9ca670c`; entrypoint SHA-256 `78a12084376837871a288b4d6d7706c7a0031c776d53cb993c9451702cbb68d6`. The owner-local directory is `%LOCALAPPDATA%/KidRemote/read-only-retry-probes/c5b68a8728d8d3cc97d638ae4d6d4ed0b17e83b8`.

The corrected diagnostic is READY_FOR_ONE_OWNER_RUN / physicalExecution NOT_RUN / productPhysicalOracle BLOCKED. Its tested executable bytes are pinned independently of later readiness documentation. No actual Samsung retry record was read again. The host-only tests are complete; physical ADB remains an owner-operated boundary. The exact command is recorded in existing PR #24. The original frame failure, null indicators, product timeout and all 96 reverified historical files remain unchanged. A new observation is required to know the retry state; no original failure is upgraded by this handoff.

## Valid retry state and native configured-sync check - 2026-10-01

**OBSERVED:** [owner retry observation b4a1296d](PRODUCT-RETRY-STATE-2026-10-01.json) at `2026-10-01T11:55:33.6829907Z` passed exact configuration/APK/signer/fixture/reverse gates and HEX1 decoding. CRC32 and schema are VALID; pending=true, stopped=false, reason=NONE, attemptCount=30, delayMs=224411, boot/deadline recorded, legacyReasonDerived=false. This is the first valid returned retry projection, not enforcement PASS. The original PC result is 3,277 bytes, SHA-256 `b71367d45b2090a05abffa0fcda7b66e724954a268b9a905b5e17bdba2a44049`; the linked LF representation hashes to `c8e8680eb28e4707ef231c7d081383caef1a7c0ceb112f0df14adb365028712e`. Restoring CRLF reconstructs the original bytes.

**SOURCE-DERIVED:** `SyncRecovery.run` preserves retryable IOException/RetryableSync failures as pending and caps the attempt counter with minOf(30,attempt+1). Thirty is the saturation value, not an exact retry total or terminal cutoff. reason=NONE is the absence of a recorded hard-stop category, not absence of failed HTTP attempts. `RetryTiming.delay` caps jitter at 300,000 ms (with separately bounded server Retry-After). The stored 224,411 ms is 224.411 seconds of selected delay, not time remaining at observation: absolute device deadline/current boot elapsed time are intentionally not emitted. This snapshot cannot distinguish timeout/refusal/other I/O from retryable HTTP 429/5xx. It does not authenticate the saved identity.

**INFERRED / UNKNOWN:** continued retry is consistent with the original run deliberately stopping its local backend and removing its reverse. The new probe directly confirms reverse absence, not current backend process state. Later native host preflight independently found all four original containers stopped. None of this identifies what happened during the original 30-second initial-report window. The previous generic framing failure is preserved; a later successful decode does not recover its missing raw response.

**EXECUTED HOST TEST:** the existing physical-lab live test previously exercised unconfigured bootstrap and persistence, but not this first configured snapshot transition. It now additionally accepts one initial SET_DAILY_LIMIT, requests the configured /device/sync response using the newly redeemed synthetic credential, checks version/epoch/limit/operation, independently confirms a persisted sync snapshot, verifies that a read alone creates no report/ACK, and checks that configuration/cache survives its existing stop/start sequence. No Android report or observed enforcement is fabricated.

[Native Windows result](PRODUCT-FIRST-CONFIGURED-SYNC-HOST-2026-10-01.json): the actual pinned Node runtime, native Docker, real PostgreSQL/Auth/PostgREST/gateway and a NEW random-ID synthetic lease passed 27 checks with exit zero. Preconditions required the original four containers stopped and fixed loopback ports free. The separate test lease was removed by the existing ownership-verified teardown; the original lab resource record and stopped state were unchanged. No ADB, emulator, device command, original-account request or private-content read occurred. This passes a host backend path, not the Samsung path or historical timeout diagnosis.

**NEXT DEPENDENCY:** reproduce automatic Android first-policy discovery while the backend is available, including an already-foreground child and a pre-existing retry deadline, using the existing owned-emulator/runtime workstream. Do not change retry semantics, inflate the physical timeout, clear retry state or infer a configured-device recovery exception from this snapshot. No more generic metadata/retry reads or QR scans are required now. Keep product source-452396d retired; any later physical continuation must preserve configured identity/policy and prior evidence. The original INITIAL_REPORT_TIMEOUT and KR-003/product acceptance remain open.

**Checkpoint validation:** the extended native live test passed 27 real host checks; separately, 27 existing WSL lease/compatibility/guidance tests passed, along with Node syntax, repository validation and patch whitespace. All 97 captured original host evidence files rehashed unchanged. The native record pins changed test bytes and source baseline; it is not an Android result. Full commit CI is tracked in PR #24. A temporary interactive evidence-edit expression failed; this standalone verifier rechecked originals and completed the evidence annotation before commit.
