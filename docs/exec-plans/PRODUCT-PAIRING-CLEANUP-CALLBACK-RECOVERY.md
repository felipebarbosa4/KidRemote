# OD-51 pairing-cleanup callback recovery

- **Goal:** Diagnose and correct the preparation callback failure in immutable
  product attempt `a2f91a25-0acc-4fff-848d-10fa99e5af53`, admit only its
  evidence-proven pairing-session transition, and continue the bounded physical
  product slice autonomously.
- **Context:** Source `b541595a33eee5ae3a4eecd6385780ae906426b7` passed
  host validation and cancelled the exact abandoned pairing session, then
  admitted `REVERSE_ADMITTED` but failed before creating the reverse. The
  sanitized result retained the previous preparation stage and a generic
  orchestration code. PR #24 remains draft.
- **Constraints:** Preserve all physical attempts and diagnostics byte-for-byte;
  never promote an INVALID result or UNVERIFIED cleanup; query only the
  task-owned synthetic backend and KidRemote lab package; never persist or print
  JWTs, QR secrets, pairing tokens, serials, raw sensitive stderr, or unrelated
  private data; no destructive device operation, security bypass, merge,
  deployment, publication, or issue closure. Physical progress may use the
  explicitly authorized Windows ADB workflow and pauses only for a human QR scan
  or Android consent.
- **Done when:** The exact callback failure is reproduced without ADB, the
  dynamic-module boundary records the next stage on Windows PowerShell 5.1 and
  PowerShell 7, the immutable attempt and backend transition are narrowly
  reviewed, all relevant PowerShell/backend/SQL/JVM/Gradle/security/privacy and
  required CI gates pass, historical hashes remain unchanged, a replacement
  immutable bundle is frozen, and the physical slice reaches a verified result
  or a genuine human-interaction blocker.

## Resumption - 2026-09-28

**OBSERVED:** the clean integration checkout resumed at `db890983e801913f1c3bce66b32277ce2b411d2f`.
The callback correction and its exact-source CI were already complete, but the immutable
freezer still described only the older `d9157ae6` and `28756da0` attempts, still
called the latter verdict latest, and still described its now-resolved pairing session
as open. The reviewed-attempt catalog already contains the later `a2f91a25` INVALID
and its exact `OPEN -> CANCELLED` pairing transition.

**Action:** align only freezer metadata/current runner guidance with the reviewed history,
reuse previously frozen runtime/QR bytes after exact prior-manifest/source-equivalence
validation instead of mutable host Node or ephemeral `/tmp` outputs, add regressions for
both boundaries, run the relevant device-free tests, then publish/freeze a replacement
only after the exact-source `Planning checks` workflow passes; the lighter guidance
workflow is not sufficient admission.

**Evidence boundary:** this correction is host/repository preparation only. It does not
reclassify any physical attempt, prove Samsung enforcement, authorize another device,
or replace the required independent physical oracle and human consent/observation.

**Freeze admission observation:** the first post-CI freeze invocation at source `ee09dda`
stopped in Node parsing with a backslash-literal `SyntaxError`, before bundle directory
creation. The exact destination was confirmed absent and no ADB/Docker/device operation
occurred. Add `node --check` coverage to the freezer test before another freeze attempt.

## Current continuation - 2026-09-30

**Goal:** resolve the actual enrollment-to-render callback boundary without another blind physical retry. **Context:** owner-granted host access now permits the durable [attempt review](../test-plans/evidence/PRODUCT-PAIRING-SESSION-REVIEW-2026-09-30.md); the real host-only probe pairing passed, while the historical exception is missing. **Constraints:** keep the original INVALID/UNVERIFIED records, the main unconsumed session, the recovery catalog, clocks, device state and acceptance gates unchanged. **Done when:** the diagnostic gap has regression coverage, the remaining callback is independently exercised with synthetic inputs under normal safety checks, and exact recovery admission is reviewed before a replacement physical handoff.

The diagnostic-only change sets the rendering stage before callback argument binding and retains only two known nonsecret pairing codes. Native PowerShell 5.1 regression: baseline failed CHECK_26; corrected suite passed 44 checks. Full final-commit CI is tracked on PR #24. This is not a fixed-pairing or physical-PASS claim.

## Callback context correction - 2026-09-30

The actual enrollment callback now has a red/green context-capture regression and a successful headless synthetic QR run. See [callback evidence and conditional history admission](../test-plans/evidence/PRODUCT-ENROLLMENT-CALLBACKS-2026-09-30.md). The exact failed-attempt inventory is cataloged without changing its INVALID result. Complete required exact-source CI and freeze new bytes before one owner-assisted attempt; no tablet operation is performed in this preparation.

## Frozen owner handoff - 2026-09-30

Source `de6a4882488f9dd19b5ad7b7470bcd76754345fd` passed full Planning checks `36760302670` and guidance `36760302546`. The freezer completed successfully; manifest SHA-256 `3654a62db1213ca8f3b027e0cb8707b4bc51ca4dffaa7a8aa8aeacd6c65190b4`, entrypoint SHA-256 `74ef1c8efa20712d3468f880e1468bbea64b963e4c9d379653502450dac99628`, 1,154 files rehashed independently. `READY_FOR_ONE_OWNER_RUN` / `physicalExecution=NOT_RUN`. The unchanged existing history verifier accepted the four exact cataloged INVALID journals in a read-only host check; six other journals remained finalized. No backend/device operation occurred. Execute only the pinned owner command in PR #24; readiness documentation may advance without rewriting this bundle.

## Interrupted owner execution - 2026-09-30

The source-de6a488 handoff above has been executed and is retired from further product reuse pending review. [The interrupted attempt](../test-plans/evidence/PRODUCT-ENROLLMENT-INTERRUPTED-2026-09-30.md) has no recorded final verdict/cleanup. Preserve it and the three refused repeats separately. The immediate goal is to reconcile Android structural identity/pending state with the read-only backend snapshot, not another QR or a forced reset. All 489 files of the existing separate metadata probe were reverified; its next physical execution is owner-operated. No recovery-catalog entry, cancellation, device operation or new product bundle was made by this review.

## Interrupted pre-setup recovery - 2026-09-30

- **Goal:** Reconcile the returned owner metadata observation and permit only a new, non-destructive enrollment attempt when the exact unfinished history and live empty state agree.
- **Context:** Observation `ee5cb367-4f67-402f-8b86-9cc3c97ff8f6` completed on the authorized configuration. Its sole generic-catalog unknown is the exact Samsung runtime path already classified in September 16 evidence. Journal `685624ea-8f7d-4d0f-8235-5b9a79bd261b` still has no recorded verdict/cleanup. The snapshot does not explain the earlier recovery screen.
- **Constraints:** Preserve original journal, diagnostics, probe output and frozen bundles. No fabricated finalization, no unrestricted interrupted-run exemption, no reset/uninstall/clear/credential read, no agent ADB, and no removal of an unknown file. Use the existing review catalog and live provenance/state gates. Historical metadata is review evidence, not a substitute for a new live check.
- **Done when:** The original observation remains byte-for-byte unchanged; a separately hashed LF representation is retained, its existing OEM classification is separately derived and tested, one exact interruption is reviewable without inventing a verdict, negative tests reject changed history/observation/state, and exact-source CI precedes any new immutable owner handoff. Any interrupted-history continuation must be `ENROLL` only, with zero backend/saved-device/local product state and no unknown files; only the precisely reviewed device-less session may be cancelled canonically.

## Verified interruption-recovery handoff

Executable source `452396d834dd76410a72094bd1e3e27e3c2954df` passed complete exact-source CI and was frozen with manifest `fe352fe67342e0c8f176dc975dadf10dd7bbd8be16737e8b4a101950b69848dd`. The [metadata/recovery review](../test-plans/evidence/PRODUCT-ENROLLMENT-METADATA-REVIEW-2026-09-30.md#verified-owner-local-handoff) records the two caught CI integration failures, their corrections, final successful runs, all-file hash verification and native read-only frozen-history verification. Physical execution remains NOT_RUN. The next action is one owner-assisted, live-gated ENROLL-only attempt, not another metadata probe, reset or a claim that the earlier scan failure is resolved.

## Initial report after enrollment - 2026-09-30

**Goal:** diagnose the first missing child report without replaying enrollment or resetting state. **Context:** [attempt 8e407e8b](../test-plans/evidence/PRODUCT-INITIAL-REPORT-TIMEOUT-2026-09-30.md) reached SETUP_ADMITTED and POLICY_ADMITTED, then finalized INVALID / INITIAL_REPORT_TIMEOUT / slice cleanup NOT_REQUIRED before any Lock. Exact read-only backend snapshots confirm one paired device, initial policy version 1 with a 3600-second allowance and manual lock false, but no report, receipt or configured sync snapshot. **Constraints:** preserve all bytes and prior missing outcomes; no ADB by the agent, reset/revocation/reinstall, report fabrication, broader history exception or new product trial. **Done when:** durable evidence is ingested, missing post-enrollment Android metadata is observed through the existing owner-operated read-only probe, and the next synchronization dependency is identified without conflating backend acceptance with child persistence.

The source-452396d handoff above is now historical and retired from repeat execution. Existing interrupted-pre-setup ENROLL-only recovery does not authorize recovery of this configured device. The earlier metadata probe preceded this enrollment; a new bounded structural observation is the next owner action. No runtime code, APK, catalog predicate or frozen bundle was changed by this review.

## Post-enrollment metadata received - 2026-10-01 UTC

**Goal:** diagnose the first absent local accounting snapshot without another product run. **Context:** observation `3143554f-6b4f-4ba6-8584-299ac2999ae0` at `2026-10-01T01:34:58.3254981Z` shows identity/syncRetry/consent and the known runtime files, but no known accounting or pending-pairing file; fixed reverse absent. **Constraints:** no private contents, agent ADB, backend mutation, reset/revocation/reinstall, fabricated outcome or recovery-catalog expansion. **Done when:** ingest this independent observation, preserve the earlier timeout, and name the next discriminating diagnostic without claiming a cause from filenames.

The [initial-report review](../test-plans/evidence/PRODUCT-INITIAL-REPORT-TIMEOUT-2026-09-30.md) now includes the exact record/hash, a separately normalized repository representation and a proposal for a one-file sanitized retry-state read. Current structural-only authorization does not cover that read. Obtain explicit owner authorization before implementing or executing it; no further generic inventory or new product-run handoff is needed at this boundary. The existing source-452396d attempt remains INVALID / INITIAL_REPORT_TIMEOUT, not an independently tested Lock/Unlock result.

## Authorized bounded retry diagnostic

**Goal:** obtain persisted synchronization stop/retry indicators without another product trial or reset. **Context:** the owner approved the one-file technical read after observation `3143554f` and requested autonomous progress without repeated approvals. **Constraints:** fixed `no_backup/sync-retry` only; bounded transient read; existing Samsung/APK/signer/reverse gates; no raw record/binding in outputs or files; no identity/backup/fallback reads; no agent physical ADB. **Done when:** synthetic parser/privacy/filesystem/native entrypoint tests and exact-source full CI pass, the existing freezer publishes a distinct immutable diagnostic scope, and one owner command yields only the typed summary.

Reuse `metadata-observation/Read-CurrentMetadata.ps1` with explicit `-RetrySummary` and matching `OD51_BOUNDED_RETRY_DIAGNOSTIC` manifest. Default metadata behavior remains separate. No product runner, database, protocol, app binary or recovery-catalog change is needed. A later summary is a snapshot, not proof of the historical timeout cause.

## Bounded retry diagnostic ready

The authorized diagnostic is frozen at `6d299495a16a8f4135e507a8bae2af0870f3395b` after complete exact-source CI. Manifest `a8cfb55c45fe7e9093a73d804c113eae2c38c542dfccb1de8fcf99b49f888be1` and all 492 listed files were verified independently. Current execution and PR #24 carry one owner-operated command; no physical read or product test was executed by the agent. Ingest only the technical result, preserving the existing timeout and all earlier evidence.

## Retry framing recovery - 2026-10-01

**Goal:** make the authorized retry summary byte-exact across host line endings without changing application state. **Context:** the returned diagnostic stopped at RETRY_FRAME_INVALID before CRC/schema checks; the owner requested direct PowerShell testing rather than further manual host tests. **Constraints:** preserve the original failure, private-file scope and all historical bytes; no physical ADB by the agent, private-content retention, backend call, reset, policy operation or speculative app fix. **Done when:** the host-only reproduction, parser/filesystem/native regressions and exact-source CI pass, the existing freezer produces a verified replacement diagnostic, and the next physical boundary is stated separately.

[Framing evidence](../test-plans/evidence/PRODUCT-INITIAL-REPORT-TIMEOUT-2026-09-30.md#retry-framing-failure-and-host-only-correction---2026-10-01) distinguishes the proven LF/CRLF synthetic reproduction from the unknown original frame. HEX1 reconstructs exact record bytes before CRC checks; it is not a permissive newline rewrite. The original source-6d29949 diagnostic is retired from repeat execution. No further authorization question is needed for safe work inside this diagnostic scope.

The corrected HEX1 diagnostic source `c5b68a8728d8d3cc97d638ae4d6d4ed0b17e83b8` passed full CI and was frozen with manifest `db04cb64702ecdd9448396a3dae85fa2e8e3b1468c5c9838cbd39d02f9ca670c`. Independent verification covered all 492 files. Host PowerShell tests are complete; the remaining owner-operated physical diagnostic is NOT_RUN and does not authorize a product retry. See the verified handoff section in the existing initial-report evidence.

## Valid retry summary - 2026-10-01

**Goal:** distinguish the observed retry state from the original first-report failure and exercise the first configured sync boundary without another tablet trial. **Context:** owner diagnostic b4a1296d reports a valid current RetryStore, pending=true, stopped=false, reason=NONE, saturated attempt=30 and stored delay=224411 ms. The earlier product attempt ended with its backend stopped/reverse removed; this later retry state does not identify the original exception. **Constraints:** preserve all historical bytes, do not restart the original product run/lease, do not read more Android contents, do not reset/revoke/reinstall or fabricate physical acceptance. Safe host tests may use only a newly owned synthetic lease, existing transport/modules and mandatory cleanup, with original lab resources excluded. **Done when:** evidence is ingested, retry semantics are checked against existing code/tests, the native host configured-sync dependency is exercised with checked results, and any remaining physical boundary is stated precisely.

## Automatic first-policy discovery reproduction - 2026-10-01

- **Goal:** execute the missing Android bootstrap-to-first-policy path rather than ask for another Samsung probe.
- **Context:** checkpoint `048b095` passed complete CI; the separate native backend delivered its first configured snapshot, while the physical timeout and later pending-retry observation do not identify the Android cause.
- **Constraints:** use only the existing owner-verified API-36 emulator at port 5584 and a separately allocated synthetic backend. Preserve original Samsung enrollment, policy, retry state, journals and immutable bundles. Do not invoke physical ADB or add a new permission, provider, enforcement design, runtime polling loop or recovery exception. Controlled scheduler fixtures are not physical latency evidence.
- **Done when:** an executed instrumented test distinguishes an already-foreground launch from a real resume and retained-backoff behavior, records the first real authenticated snapshot/ACK or an independently classified failure, restores only owned test resources, and identifies the smallest evidence-supported next change.

Reuse the existing KR-009 instrumentation and native physical-lab lease test. New code belongs to test orchestration unless a product defect is reproduced. A successful emulator path cannot reclassify the original `INITIAL_REPORT_TIMEOUT` or approve Samsung Lock/Unlock.

**Executed outcome:** four instrumented scenarios now pass on the exact owned emulator, including two separate real backend leases and the service-enabled case. The original guard failure remains preserved. Both connected runs observed the first server report/ACK; a controlled retained deadline crossed 30 seconds and converged naturally, without a retry-policy change. The [classified evidence](../test-plans/evidence/PRODUCT-INITIAL-REPORT-TIMEOUT-2026-09-30.md#executed-android-first-policy-reproduction---2026-10-01) records exact APK/test hashes and cleanup. The next dependency is scoped synchronization readiness for the retained enrolled state, not another bootstrap reproduction or generic metadata read. No Samsung action or new physical handoff occurred.

## Retained enrollment synchronization-readiness observation

**Goal:** obtain the first fresh authenticated child report without another enrollment or enforcement trial. **Context:** the owner asked to continue after the executed first-policy emulator investigation. The original configured Samsung identity and policy must be retained; the separate controlled-deadline experiment does not establish the historical timeout cause. **Constraints:** compose the existing fixed target/APK/signer, bounded retry reader, native persistent backend, canonical parent read and exact reverse/launch helpers. No direct app-data writes, reset, new policy/allowance, credential extraction, permission change, independent-input claim or change to the product recovery catalog. Physical ADB remains owner-operated. **Done when:** a distinct, bounded observer has negative/native tests, required exact-source CI, immutable provenance and one exact owner handoff; preserve the 30-second observation separately from a maximum six-minute diagnostic window.

The observation may reconnect the previously enrolled app to its existing policy. It is not a read-only device experiment: automatic policy/accounting/ACK changes are possible. It must not call the product-slice runner or treat a report as enforcement acceptance. Preserve the prior INVALID journal; verify it without turning it into a configured-state product recovery exception. Stop on changed identity/epoch/version, invalid retry data, unknown history, foreign transport or cleanup uncertainty. A stored delay above the ordinary five-minute retry cap is a typed stop, not permission to ignore Retry-After.

The previous exact-source CI run 36890236971 completed cancelled, not PASS. Its completed jobs and executed emulator records remain separate. Do not use that run to admit an executable handoff; require the final observer commit's full CI.

## Verified retained synchronization handoff

Frozen executable source `6fb6593c328732a6f49dda7a58b98ac70da039a3` passed exact-source Planning checks `36906188112` and guidance `36906188126`. The observer bundle has manifest SHA-256 `53137a7e4f7c29718b1891fd08e38b982b8b7f5a742c9b727c1152396ec7d7f4`, entrypoint SHA-256 `c2430c9da970d50ce8d3f341e7bd5b08d0896f24d397ab500a25e689f6d80004` and 1179 separately verified files. Scope is OD51_RETAINED_SYNC_READINESS; physical execution is NOT_RUN and the product oracle remains BLOCKED. Physical execution is the remaining owner boundary; no product control operation or configured-state recovery exception is introduced.
