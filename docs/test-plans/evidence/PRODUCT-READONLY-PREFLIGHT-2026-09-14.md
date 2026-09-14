# OD-49 device-free prerequisites and read-only inventory

- **Goal:** Durable host journal, canonical/provenance adapters, isolated lab build and one immutable read-only owner bundle.
- **Context:** Baseline `0b4dfb144e0346eb5a9fda31075aba20583a993c`, draft PR #24; product physical oracle BLOCKED.
- **Constraints:** No physical command, qualification, FCM, destructive operation or historical evidence edit.
- **Done when:** Device-free checks and CI pass, bundle source/hashes recorded, owner receives only an inventory command.

## OBSERVED

OD-49 extension appended without overwriting earlier authorization. See [current implementation/readiness](../../../tools/enforcement/product-oracle/README.md). Product restriction design and historical evidence are unchanged. Only debug endpoint selection/build metadata changed in the app.

- New prerequisites suite: **71 checks PASS** under native Windows PowerShell 5.1. Real host filesystem flush/atomic append, interrupted admission, truncated write, duplicate retry/conflict, immutable FAIL/separate cleanup, reader restart and corrupted final record are covered. Canonical callback timeout/refusal/401/403/conflict/lost response/stale/concurrent/cleanup outage and synthetic local Auth setup are covered. These are not actual backend results.
- Separate native fake-executable entrypoint suite: **10 checks PASS**, including independent result files for successful inventory, configuration mismatch, native rejection, manifest mismatch and file tampering. No ADB executable/device was used. Serial/error-detail redaction verified.
- Existing independent oracle suite: **64 checks PASS**; fixture input/focus contradiction cannot be overruled by applied telemetry.
- **99 Node regressions PASS**, **3 content-free Python observer tests PASS**. JVM reports child **84**, parent **14**, debug/release build/lint and permission/privacy/release audits PASS (378 Gradle tasks, 34 executed, 344 up-to-date; 40 seconds). Existing cached test reports are not new Android runtime evidence.
- Lab build: fixed `http://127.0.0.1:47366`, versionCode 2, versionName `0.0.2-local-physical-lab`, package `dev.kidremote.child.unassigned.debug`. Actual DEX check: lab endpoint present only in lab debug; neither lab nor emulator endpoint in release. Default debug rebuilt separately and audited.
- Lab APK SHA-256 `f6d2a240fae179343d9eb19dfde7684ae6e241b35cebea8ce491205110f7ad56`; debug certificate SHA-256 `638dfa66379788415c313d7a3ca96dcfcaf7e643c12bb0c4950b3046a3f76beb`.
- Default debug APK SHA-256 `b90fe7c6a4f03ce307ffca46b49052ca14a7d03d3493bae6782d75cf80e415da`; unsigned release SHA-256 `ffb42850fe95fe7f6f48f8e00fe89c534743e334462625b4bed4b7d1f2cb60be`. BuildConfig generation changes APK bytes; release behavior/endpoint/permissions remain isolated, not claimed byte-identical.

### Retained failed/partial attempts

1. Initial prerequisites test stopped because its test scope had not imported `New-ProductOperation`. Earlier checks had run; no complete PASS claimed. Explicit core import fixed the test.
2. First lab artifact audit: Gradle build/lint SUCCESS, Python audit FAILED because it requested `child-release.apk` instead of actual `child-release-unsigned.apk`. Corrected path; independent second audit PASS. No immutable artifact was created from the failed audit.
3. First native entrypoint test FAILED `ENTRY_CLASSIFICATION`: manifest file-set validation assumed a culture-dependent sort order for punctuation. Replaced ordering assumption with exact membership/count validation. Separate rerun passed all 10 checks.
4. Expanded callback test FAILED when closure could not resolve module-private `Assert-LabInteger`. Captured the helper explicitly in the closure; separate rerun passed. This was a host callback defect, not Android evidence.

Dirty-source lab validation identified its baseline and `sourceWorkingTreeChanged=true`; no artifact was frozen from dirty source. Source-pinned artifact/bundle details follow only after the implementation commit.

## INFERRED / boundary

A fixed debug-only loopback endpoint supports planning an ADB reverse without changing release or exposing the gateway to LAN. Only the fixed argument plan is synthetically validated here; no tunnel, physical route or canonical-to-physical sync was tested. Shell signature hash codes do not establish certificate digests; signer remains UNSPECIFIED when not obtainable with bounded reads.

## UNSPECIFIED / NOT RUN

Current Samsung configuration, installed APK/version/signing/state and product permissions remain UNSPECIFIED until the owner executes the read-only bundle. No APK installation/update, reverse, input, app launch, settings change, backend mutation, device command or emulator was executed by this extension. Existing identity/accounting may collide with the debug package and must be preserved.

**PRODUCT_PHYSICAL_ORACLE=BLOCKED.** Only inventory can become ready; its classifications are review outcomes, never enforcement PASS or install authorization. Read-only duration is an unmeasured estimate: approximately 30–90 seconds normally, bounded by per-read 10-second timeouts (roughly five minutes worst case). Paste only the sanitized JSON; never serial/raw dumpsys/screenshots. No cleanup settings/device operations are needed because the bundle performs no physical mutations. Host result files, including invalid attempts, are preserved separately.

5. Staged whitespace check reported one trailing space in Journal.psm1 before the implementation commit. The shell sequence still committed; the space is corrected in a separate follow-up commit. This is retained as a failed check, not a runtime failure.
