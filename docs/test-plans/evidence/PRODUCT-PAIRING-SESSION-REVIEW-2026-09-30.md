# OD-51 pairing-session diagnostic review - 2026-09-30

- **Goal:** Review the two owner reports without another physical trial, retain their evidence, and remove a demonstrated diagnostic ambiguity.
- **Context:** Source `062fd59b545b37ac6a58b03ac67889b181a806d8` was retired after `PAIRING_SESSION_INVALID` and a refused repeat.
- **Constraints:** No ADB/device action, new physical bundle, journal mutation, recovery-catalog amendment, host configuration change, or acceptance claim.
- **Done when:** Durable identities/inventories are recorded, available host-only checks are executed, diagnostic regression is tested, and unresolved history remains explicit.

## OBSERVED: durable records and scoped backend metadata

The owner-granted repository and KidRemote host directories were readable through the native file tool. The previous access blocker is resolved. [Structured results and SHA-256 inventories](PRODUCT-PAIRING-SESSION-REVIEW-2026-09-30.json) accompany this review; the [original console-only report](PRODUCT-PAIRING-SESSION-VALIDATION-OWNER-REPORT.md) remains unchanged.

Attempt `236b1c2b-9290-45cd-82ab-75c0a53fb51b` has a valid six-row hash chain: BEGIN, PAIRING_CLEANUP_ADMITTED, REVERSE_ADMITTED, ENROLLMENT_ADMITTED, VERDICT, CLEANUP. Its original result remains `INVALID:PAIRING_SESSION_INVALID` / primary cleanup `UNVERIFIED`. There is no SETUP_ADMITTED, POLICY_ADMITTED or LOCK_ADMITTED row. ENROLLMENT_ADMITTED is not completed enrollment.

The repeat is diagnostic `2ffe7b34-d19d-4cfc-90b4-be5feb6c82e9` at `2026-09-30T16:32:59.5816734Z`, refused at JOURNAL_READY before creating another product journal. An additional earlier source-062fd59 Docker-engine failure, journal `ecc14e8a-6a86-4674-91c1-66128220420c`, was also retained separately. Its journal cleanup is NOT_REQUIRED while its primary result says UNVERIFIED; these fields are not conflated.

An exact-ownership-verified, read-only SQL transaction found one lab owner, zero devices, two cancelled device-less pairing sessions and one unconsumed/uncancelled device-less session `2598b696-3ddc-497d-899b-a9622bb495ef`. That session was created at `2026-09-30T16:31:21.862324+00:00`, expiring exactly five minutes later. Only the verified stopped database was temporarily started for this SELECT/ROLLBACK and restored to its original stopped state. No session was created or cancelled by that review.

## OBSERVED: host-only checks, not physical results

The original New-ProductPairing function accepted a synthetic valid response on native Windows PowerShell 5.1. A subsequent real Auth/HTTP pairing check used only the existing separate synthetic probe account: CREATED, valid schema, string expiry, and approximately 300 seconds remaining. Its exact new probe session was cancelled and the existing backend stop routine retained the lab. The main unresolved session was not cancelled. No QR was displayed and no device was invoked.

The remote shell omitted OS; the first probe stopped at HOST_PREREQUISITE. The next process set OS only in that process after independently verifying Win32NT. No persistent environment or access-control setting was changed. A separate optional synthetic callback invocation was refused by the execution tool; it was not rerouted or counted as a passed test.

A Docker info SystemTime snapshot appeared behind Windows, but the actual database timestamp fell between the host timestamps around the query and the historical session timestamp matches the journal interval. That snapshot is not sufficient to diagnose clock skew as the historical cause. No clock repair was performed.

## Diagnostic correction and executed regression

The wrapper left its stage at PAIRING_SESSION_VALIDATE until the renderer itself ran its stage callback. A renderer callback/argument-binding exception in that gap was therefore misreported as PAIRING_SESSION_INVALID. This is a demonstrated diagnostic defect, not proof that it caused the original physical attempt.

LivePreparation now marks QR_RENDER_PROCESS before invoking the renderer and preserves only the exact, nonsecret PAIRING_SCHEMA and PAIRING_EXPIRY codes at pairing validation. All other private/unknown exceptions remain sanitized. Pairing schema/expiry checks, permissions, release binaries, oracle thresholds, immutable bundles and ReviewedInvalidAttempts.json are unchanged.

Regression was red before the code change (ENROLLMENT_FAILURE_CHECK_26), then green with 44 checks on native Windows PowerShell 5.1. Cases cover pre-render callback failure, renderer parameter-binding failure, both retained pairing codes, and rejection of an unapproved private detail. An initial local test-copy invocation lacked a transitive KR-003 module and did not run the suite; completing that test-copy dependency preceded the red/green runs. CI for the final commit is recorded on existing PR #24, not inferred from prior revisions.

## INFERRED / UNKNOWN and next action

The new session's association with the failed journal is inferred from its unique presence and creation within that journal's enrollment interval. The original response/exception was not retained. The exact historical root cause remains UNKNOWN; the later successful probe cannot reconstruct it or upgrade the INVALID result.

No attempt was added to the recovery catalog and no replacement bundle was frozen. Continue the existing pairing-recovery task by testing the actual nested enrollment-to-render callback boundary with synthetic inputs and normal safety checks, then review exact recovery admission before any new physical handoff. Do not repeat the retired source-062fd59 command. KR-003 and product physical acceptance remain open.
