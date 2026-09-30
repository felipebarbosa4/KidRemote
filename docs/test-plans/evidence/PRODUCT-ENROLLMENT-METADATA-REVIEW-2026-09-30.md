# OD-51 post-interruption metadata and bounded recovery - 2026-09-30

- **Goal:** Complete the interrupted-attempt state review without deleting history or resetting the child.
- **Context:** The owner returned metadata observation `ee5cb367-4f67-402f-8b86-9cc3c97ff8f6` after interrupted journal `685624ea-8f7d-4d0f-8235-5b9a79bd261b`.
- **Constraints:** Preserve all original bytes and missing verdicts; no agent ADB, backend mutation, file-content collection, data clear, reinstall or general interrupted-run exemption.
- **Done when:** The new observation is preserved, existing OEM classification is applied separately, exact historical review and live-empty-state restrictions are tested, and required CI precedes any new immutable owner handoff.

## OBSERVED: the returned read-only observation

The original owner-local diagnostic remains unchanged: 3,519 bytes, SHA-256 `f95eb06ff7cd347919b81e2ec444d1bd6e658fecf179bb187768324ac8654a7d`. The [repository JSON representation](PRODUCT-ENROLLMENT-METADATA-2026-09-30.json) changes only CRLF line endings to LF: SHA-256 `ace912f3a8b0c4ed6458c3b10257084b8e3ef27a40887020d1cadcd07d5fcbde`. Parsed values are identical, and restoring CRLF reproduces the exact original bytes. The existing whitespace check caught the CRLF export; no check was disabled. Its UTC is `2026-09-30T19:31:42.1862523Z`; source `8ebcc89e0b483af1f5d3cf3a081fca640da37e10`, manifest `e4d8ab75d9b6c44ca08d3c5cb3958e3992afa4a254518f4fdebb450ba0cc29ee`.

Configuration, child APK/signer and fixture provenance passed. The fixed lab reverse was absent, metadata was fully parsed, and the temporary host APK was removed. The probe result is OBSERVED, not enforcement PASS. It lists four generic runtime files plus `shared_prefs/android.app.ActivityThread.IDS.xml`, 108 bytes. No known identity, pending-pairing, accounting, sync-state or consent file is present in this snapshot. Contents were not read.

## DERIVED: reuse the existing exact OEM classification

The generic probe predates the [Samsung IDS classification](PRODUCT-SAMSUNG-IDS-CLASSIFICATION-2026-09-16.md). Its original `UNKNOWN_DURABLE_FILES_PRESENT`, four-known/one-unknown counts and `productPhysicalOracle=BLOCKED` remain unchanged. The existing `ProductRuntimeOemOverlay.psm1` maps this exact path only for samsung / SM-X400 / Android 16 / API 36 / BP4A.251205.006 / patch 2026-07-05. Applying that already-established structural classification accounts for the fifth file. This neither reads its contents nor establishes a Samsung-wide rule.

Together with the earlier scoped [backend snapshot](PRODUCT-ENROLLMENT-INTERRUPTED-2026-09-30.json), these observations support a candidate empty-enrollment recovery. They are snapshots at different times, not a current live guarantee and not an explanation of the owner's earlier recovery screen. The earlier QR's exact failure remains UNKNOWN.

## Exact unfinished-history review without invented finalization

The seven original journal files were rehashed against the previous immutable inventory. Its four rows still end at ENROLLMENT_ADMITTED, with no VERDICT, CLEANUP or result.txt. Primary status/reason/cleanup remain NOT_RECORDED. The three refused-repeat diagnostics remain separate; none supplies the missing outcome.

The existing review catalog now has one explicitly typed INTERRUPTED_PRE_SETUP entry. It pins source/bundle/APKs, all seven hashes, the exact four-row sequence, original empty-state resume-review and the independent observation's path/hash. It records the previous session's observed OPEN-to-CANCELLED transition and the new device-less, unconsumed, uncancelled session. Association of the new session with this run is INFERRED from the unique row and matching creation interval; the original QR response was not retained.

The review function does not append a fake verdict or exempt arbitrary unfinished journals. It rejects changed inventory, hidden/unexpected entries, partial rows, any later setup/policy/lock/verdict, altered metadata, changed configuration, product state or a different recovery path. Previously finalized INVALID review semantics remain separate.

A new owner run must independently repeat live provenance, backend/session, reverse and structural-state checks. The interrupted-history branch additionally requires the exact lab package, no backend device, no saved pointer, no local product-state file and no unknown file; only ENROLL is permitted. RESET_ENROLL, REPLACE and VERIFY_REUSE are not authorized by this entry. Historical hashes are checked again after live preflight, before new mutation admission. Only the exact reviewed unconsumed/device-less session may be cancelled through canonical finish_pairing. No session was cancelled by this change.

The freezer now derives historical attempt IDs and the latest recorded outcome from the existing catalog instead of a second manually maintained list. Missing outcomes remain NOT_RECORDED in the new manifest. The QR instruction now explicitly asks the owner to wait for the final JSON and not acknowledge revocation or repeat the command on an app error.

## Executed device-free validation

- Native Windows PowerShell 5.1: the expanded existing ReviewedHistory regression failed on the previous implementation at REVIEWED_HISTORY_CHECK_8. After the change, all 42 checks passed, including unknown kind/path/status/hash, altered snapshot, later admissions, partial/unexpected history and nonempty live-state rejection.
- Native read-only verification against actual saved records accepted five cataloged histories and derived three CANCELLED plus one OPEN session expectation. No original file, backend or device was modified by that verifier.
- WSL: 13 guidance/compatibility/history-consistency tests, freezer syntax check, repository validation and patch whitespace passed.
- Required full exact-source CI is recorded separately on existing PR #24. These local results do not establish Android execution, physical pairing or enforcement.

## Remaining boundary

The owner has completed the requested read-only probe. Do not ask them to rerun it or delete the IDS file. Publish a replacement product command only after exact-source validation and immutable freezing. Keep the former source-de6a488 command retired, the interrupted result missing, and all KR-003/product acceptance gates open. A future owner trial is new evidence, not a rewritten result or a guaranteed fix for the original recovery screen.

## CI integration correction

Planning run `36767867912` for `8476ef7` exposed a missing input in the existing extracted `ReadOnlyTarget` gate test: the new interrupted-history flag was initialized outside the tested scriptblock. The Windows job stopped at an unset `$interruptedHistory`; no bundle was frozen from that revision. The flag is now derived inside the gate from its existing verified-history input, eliminating the additional ambient dependency rather than defaulting an unknown flag to false. The existing gate test now covers twelve interrupted-history cases as well as all original cases. Native Windows PowerShell 5.1 passed 257 assertions, with all transports synthetic and no device invocation. The failed CI remains preserved; full validation is required again for the corrected source.

The next Windows CI job, `110069011500` in run `36768523531` for `0f65730`, reached the native lease/compatibility checks after the PowerShell suites, then caught Git's automatic CRLF checkout conversion of the hash-pinned metadata representation. The observed hash was the original CRLF hash rather than the intended repository LF hash. Following the existing backend-source convention, `.gitattributes` now pins LF for this one metadata path. Runtime hash comparison is not normalized or weakened. An isolated `core.autocrlf=true` checkout produced the expected `ace912f3...` bytes, and the consistency test now asserts the path's Git eol attribute. Both failed runs remain retained; a replacement still requires fresh complete CI.
