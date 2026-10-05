# OD-51 enrollment callback context - 2026-09-30

- **Goal:** Exercise and correct the actual enrollment-to-render callback chain before another owner attempt.
- **Context:** The source-062fd59 attempt remains INVALID. The diagnostic boundary correction at 8c4bae4 passed its full Planning checks run 36750502071, but did not establish the complete callback chain.
- **Constraints:** No ADB, device operation, real QR display, backend mutation, host setting change, historical rewrite, or lowered acceptance checks.
- **Done when:** The real callback factory has a red/green regression, a synthetic QR is rendered headlessly with verified runtime bytes, exact history admission is reviewed, and required exact-source CI precedes any new immutable handoff.

## OBSERVED: context loss and correction

`New-LivePreparation` created an outer enrollment closure, then called `GetNewClosure()` again inside it to construct pairing/render/poll/open callbacks. Those inner closures did not retain constructor variables from the outer module scope. A native synthetic inspection found the wire scriptblock, bundle path and Java path present in the outer context and absent in the newly nested context.

An invocation through the actual `ops.Enroll` callback failed on the prior source at `PAIRING_SESSION_CREATE`, even though the HTTP boundary was stubbed with a valid response. This is a reproducible callback-context defect. A runner's similarly named ambient variables could mask some missing captures; the historical exception was not retained, so its exact causal path remains INFERRED rather than recovered evidence.

The correction constructs the pairing, renderer, window, poll, open and instruction callbacks in `New-LivePreparation` itself, while dependencies are local, then captures those callbacks in `ops.Enroll`. No protocol, schema/expiry acceptance, renderer validation, release permission or independent oracle is changed.

## OBSERVED: executed native tests

The synthetic full-chain regression failed before the correction with `ENROLL_CALLBACK_CONTEXT_FAILED_PAIRING_SESSION_CREATE_INVALID:PAIRING_SESSION_CREATE_FAILED`. After correction it passed for two distinct bundle paths, including one containing spaces. It checks exact renderer executable/classpath/payload, pairing and poll routes, one call per boundary, returned synthetic identity and window disposal.

A third run used the real frozen Java/host-QR renderer with a synthetic payload, after checking the exact source-062fd59 manifest and every listed file hash. It produced valid PNG bytes through the actual callback chain. HTTP, the window and device operations remained stubs. No real QR window was displayed and no child device was used.

The regression is incorporated into the existing `FrozenModules.Tests.ps1`, already run by the normal Windows PowerShell 5.1/7 CI route. A combined local expanded-suite invocation was refused by the execution tool. That invocation was not retried, routed around, or counted as passed; the successful dedicated callback and headless-render runs above are separate evidence. The existing required CI remains mandatory.

## Exact history admission, not a rewritten result

The [durable review](PRODUCT-PAIRING-SESSION-REVIEW-2026-09-30.json) remains unchanged. All ten files in attempt `236b1c2b-9290-45cd-82ab-75c0a53fb51b` were rehashed and matched its recorded inventory. The six-row journal admits enrollment, but no setup, policy or lock. Its primary verdict remains `INVALID:PAIRING_SESSION_INVALID`, cleanup `UNVERIFIED`; reverse removal and backend stop are separate observations.

One exact catalog entry is added for those source/bundle/APK hashes, journal stages and file hashes. It carries the one device-less, unconsumed, uncancelled session `2598b696-3ddc-497d-899b-a9622bb495ef` from the ownership-verified database snapshot. Association with the attempt is INFERRED from the unique new row and its creation inside the journal's enrollment interval; the original HTTP response was not retained.

This is conditional recovery admission using the existing rules, not a current-state guarantee. Before any new QR, the runner must independently match all reviewed sessions and the empty identity/accounting state, then cancel only the exact reviewed open session through canonical `finish_pairing`. Any unknown, changed, consumed or device-bound session fails closed. The two previously cancelled sessions remain cancelled. No session is cancelled by this source change.

`ResumeReview.psm1` and its admission predicates are unchanged. The new catalog fixture covers matching typed pairing failure and rejection of a mismatching failure code. Existing policy/lock/unknown-file rejection tests remain. The host-only Docker failure and refused-repeat diagnostic are not added as enrollment exceptions.

## Validation and remaining boundary

Required source validation includes the existing FrozenModules, EnrollmentFailure, ReviewedHistory and related native suites, guidance checks, full Planning checks and freezer syntax/compatibility checks. Exact final commit/run identities are recorded on existing PR #24; previous CI is not evidence for this change.

The last physical verdict is unchanged and the original source-062fd59 command remains retired. A replacement may be published only after exact-source CI and immutable freezing. Its manifest will describe four reviewed historical attempts and the one narrowly reviewed open session, not falsely state that all sessions are already cancelled. Physical execution remains owner-assisted; QR scan, Android consent and independent input/focus observations are not replaced by these tests.
