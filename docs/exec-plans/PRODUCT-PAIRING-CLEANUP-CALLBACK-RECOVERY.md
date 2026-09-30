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
