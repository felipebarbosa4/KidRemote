# OD-49 historical signing recovery — NOT_FOUND

- **Goal:** Recover the installed child's signing identity from bounded legitimate development locations, conditionally enabling an owned-emulator update test.
- **Context:** PR #24, baseline `1659120f1b7fd3d58bac130919f14fe1a20176f5`; owner read-only result confirms mismatched signers and two unclassified durable files.
- **Constraints:** No Samsung/physical ADB command, data erasure, permissions, backend, signing-key copy/output, release redesign or FCM. No search of unrelated documents/credentials.
- **Done when:** Record search/provenance/state limits and validation, then stop for owner choice if no compatible key is found.

## OWNER_REPORTED

Installed package `dev.kidremote.child.unassigned.debug`, APK SHA-256 `3ff9962ec6bf55eab20eda993e879112be9c04a3ed7c00e8287fc7660ad63ac9`, signer SHA-256 `771bc0fa9b91aecba8fd2d0e7d1e3af27237840198327731e098bb83dcbc97d7`. Signer match NO. Known KidRemote state absent; `otherDurableFiles=2`, `sufficientForEmptyStateReview=false`. No update, uninstall or clear-data occurred. This supersedes the prior inference with owner-reported signer readback, not agent physical observation.

## OBSERVED — exact historical origin

Source `14d82dbbf764c5a78c2c80393756d5302842958f`; [CI 34662155724](https://github.com/felipebarbosa4/KidRemote/actions/runs/34662155724), child artifact ID `10288340546`. A fresh read-only download of that artifact contains `child-debug.apk` with the exact installed hash above. The preserved owner-local runtime copy has the same hash, and SDK apksigner verifies the target certificate. Historical camera/physical results are unchanged.

The CI log identifies GitHub-hosted Ubuntu 24.04, image `20260907.300`, Java 17 setup and normal `validateSigningDebug`. Historical child Gradle config has version 1 / `0.0.1-local`, `.debug` suffix and no explicit signingConfig. The workflow uploads APKs only, not the signing keystore. Current child config also uses default debug signing; the approved lab was built in WSL, whose standard Android debug certificate matches its signer. Neither config pins a shared debug identity.

**INFERRED cause:** different environment-local default debug keys, with the old one created/used on the historical hosted runner. Android documents automatic debug signing and GitHub documents fresh hosted runner environments. No preserved private key was found; an APK's public certificate does not recover it. This does not prove no copy exists anywhere outside the authorized search scope. [Android signing](https://developer.android.com/studio/publish/app-signing), [GitHub-hosted runners](https://docs.github.com/en/actions/concepts/runners/github-hosted-runners), checked 2026-09-14.

## OBSERVED — bounded candidate results

| Sanitized location category | Result | Certificate SHA-256 |
| --- | --- | --- |
| WSL standard Android debug store | Metadata verified; mismatch | `638dfa66379788415c313d7a3ca96dcfcaf7e643c12bb0c4950b3046a3f76beb` |
| Windows standard Android debug store | ABSENT | Not applicable |
| Task-owned Windows KidRemote runtime/build directories | No keystore/JKS/PKCS12 candidates | Not applicable |
| Current task repository/build directories | No candidates | Not applicable |
| Windows Gradle directory | ABSENT | Not applicable |
| WSL Gradle configuration-cache store | Symmetric SecretKeyEntry metadata; no PrivateKeyEntry/certificate, not an Android signer | Not applicable |

Only file discovery and keytool certificate/entry-type metadata were used. The Gradle cache store did not accept the standard debug-store credential; separate passwordless metadata listing succeeded but did not verify integrity. It showed a symmetric entry, not a signing certificate. No other passwords were attempted and no private key was exported/read into evidence. No existing keystore was changed. Candidate paths remain outside committed evidence; only location categories/digests are retained.

**OLD_SIGNING_KEY=NOT_FOUND.** No signingConfig, product code, release signing or lab artifact was changed. No new APK was built/frozen; **SAME_SIGNER_UPDATE=NOT_DEMONSTRATED / NOT_RUN**. The conditional emulator install/data/downgrade tests cannot run with a missing matching key. No emulator or backend was started.

## Historical durable-state inventory — source knowledge, not device readback

The source-14d82db product writes only `no_backup/device-identity` and `no_backup/pairing-pending`, through Android AtomicFile (including possible `.new`/`.bak` sidecars). The identity uses AndroidKeyStore alias `device-identity-v1`, outside ordinary app files; filename absence cannot inventory that key. This version has no Room ledger, sync/retry journal, recurring policy cache or removal marker implementation. Its debug fault counters are memory-only.

Transitive ProfileInstaller contains `files/profileinstaller_profileWrittenFor_lastUpdateTime.dat` and `files/profileInstalled`. Both constant names are present in the exact old APK DEX; the locally preserved ProfileInstaller 1.4.0 bytecode uses `getFilesDir` for these files. They are plausible structural candidates, **not a classification of the owner's two files**. Platform/runtime cache/profile artifacts may also exist; a complete device-file inventory cannot be inferred from product source.

Separate historical test APK code could write fixed markers `no_backup/camera-revoke-ready`, `camera-identity-id`, `camera-identity-pid`, `gateway-restore-ready`, and `runtime-pid`. The host/test flow could stage `no_backup/qr-handoff` or `scene-invalid.png`. These are source-known literal paths, never names read from Samsung. Product APK execution alone does not demonstrate test execution or marker presence. Secret-bearing handoff/identity contents must not be read.

The owner returned only an aggregate count for other files. It cannot distinguish ProfileInstaller files from test leftovers or other retained data. **Both files remain UNKNOWN; do not delete, replace, or label them harmless.** Destructive replacement is unauthorized. No additional physical inventory command is supplied in this slice.

## Validation and independent partials

- Exact CI artifact/archive hash and SDK signatures: PASS for old and existing approved lab.
- Existing lab fixed loopback DEX and existing release's absence of lab/emulator endpoints: PASS. Existing permission/privacy/release audits: PASS; reports contain child 84 / parent 14 passing JVM tests (audit of existing reports, not a fresh local JVM run).
- Read-only review synthetic suite: 78 PASS; actual metadata shell fixtures: 4 PASS; affected Node security suite: 9 PASS. Repository validation and whitespace check PASS.
- Required final-head CI builds/lint/JVM/regressions are reported in PR #24 and Issues #3/#10 after completion. CI validation APKs do not replace the approved physical-lab artifact or recover the historical signing key.
- First artifact audit stopped at missing process `ANDROID_HOME` (`aapt2 ENOENT`); parent audit and Node tests in that chained attempt did not run. Separate invocation with the existing SDK path passed all three. No implementation validation was weakened.
- Two guessed historical source-file paths did not exist; tree inspection located `Enrollment.kt` and the actual runtime test files. These were read failures, not runtime test results. A documentation URL lookup failed; no conclusion relies on that page.

Approved lab remains source `668ab87a22591319afd43167d55ef9ac0909c1b3`, version 2 / `0.0.2-local-physical-lab`, APK `f6d2a240fae179343d9eb19dfde7684ae6e241b35cebea8ce491205110f7ad56`, signer `638dfa66379788415c313d7a3ca96dcfcaf7e643c12bb0c4950b3046a3f76beb`. No original APK, key, owner bundle or historical evidence was replaced.

## Owner decision — neither selected

**PRODUCT_PHYSICAL_ORACLE=BLOCKED.** Stop before implementation of either alternative:

A. Create a side-by-side physical-lab package, preserving the installed package/state.

B. Explicitly owner-authorized destructive uninstall/reinstall after a separate state/risk review.

No Samsung command, install/update, data clear, permission change, reverse, backend or physical qualification was executed. No new owner execution command is supplied. PR #24 remains draft and Issues #3/#10 remain open.
