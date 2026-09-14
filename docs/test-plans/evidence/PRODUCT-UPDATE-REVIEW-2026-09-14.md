# OD-49 read-only signer/state update review

- **Goal:** One read-only owner handoff establishing signer compatibility and durable-state metadata.
- **Context:** PR #24, baseline `0b54aaf4045c699fd6cafbdc1c9a41ce163e49a7`; owner reports matching Samsung configuration, child v1 installed, permissions not verified enabled.
- **Constraints:** No physical command by agent, installation, permission change, app/input, backend/reverse, secret contents or DB rows. Preserve historical evidence and approved lab bytes.
- **Done when:** Device-free checks/CI pass and one pinned read-only bundle is delivered; fresh device evidence stays pending until owner returns it.

## OWNER_REPORTED (not agent-observed device state)

Samsung / SM-X400 / Android 16 / API 36 / BP4A.251205.006 / patch 2026-07-05 matched. Child `dev.kidremote.child.unassigned.debug`, installed true, versionCode 1 / versionName `0.0.1-local`, hash `3ff9962ec6bf55eab20eda993e879112be9c04a3ed7c00e8287fc7660ad63ac9`, serviceRegistered false, retainedState POSSIBLE_PRESERVE, Accessibility and Usage Access NOT_VERIFIED_ENABLED. Fixture hash `223219c17a31439b52698e769bdf03ead0998bbbe8bbb5c1b0ff5be3cfaf21dc`. Prior preflight classification PERMISSION_SETUP_REQUIRED. Owner reports no mutation.

## OBSERVED on host artifacts

Preserved source-14d82db APK under existing owner runtime `artifacts-kr007-14d82db/debug/child-debug.apk` matches the reported installed hash exactly. SDK apksigner verifies signer SHA-256 `771bc0fa9b91aecba8fd2d0e7d1e3af27237840198327731e098bb83dcbc97d7`.

Approved lab source `668ab87a22591319afd43167d55ef9ac0909c1b3`; SHA-256 `f6d2a240fae179343d9eb19dfde7684ae6e241b35cebea8ce491205110f7ad56`; versionCode 2; versionName `0.0.2-local-physical-lab`; signer SHA-256 `638dfa66379788415c313d7a3ca96dcfcaf7e643c12bb0c4950b3046a3f76beb`. Package `dev.kidremote.child.unassigned.debug`; manifest service `dev.kidremote.child.enforcement.ChildEnforcementService`; endpoint `http://127.0.0.1:47366` fixed/debug-only. AAPT and actual DEX inspection passed; existing release contains neither lab nor emulator endpoint. No lab rebuild or re-sign occurred.

Windows SDK JAR SHA-256 `2defad215d7ff52968a409cde528cdaef7918b115e276b8e3378ca7a178e4180`; Android Studio JBR java.exe SHA-256 `7148521120f35659dc0b233358a107c67ca7ca92993391519660ee6c80a9df9a`. Real Windows SDK verification was exercised through the same process wrapper with archived APK copies and a fake ADB executable. No real ADB was invoked.

## Validation

- 78 Windows PowerShell synthetic checks PASS: state paths/markers, unknown/duplicate/malformed metadata, signer schemas/mismatch, hash failure, SDK failure and temporary-copy deletion.
- 4 Python tests execute the actual fixed shell program on owned synthetic host directories: empty state, metadata-only identity blob, undisclosed unknown filename, symlink rejection. PASS; synthetic file bytes unchanged.
- 16 native Windows entrypoint checks PASS, using actual SDK/apksigner and two archived APKs, with **fake ADB only**. Empty/present/denied state retains SIGNER_MISMATCH_BLOCKED; bad copied hash gives READ_ONLY_REVIEW_INVALID. Temporary copies deleted and four independent JSON attempts preserved during tests. These are not Samsung observations.
- Separate actual SDK lab-copy signature/deletion check PASS. Existing 3 host observer tests PASS.
- JVM reports child 84 / parent 14 PASS; debug/release lint/build tasks SUCCESS in 40 seconds (166 tasks, 22 executed). Existing APK permission/privacy/release audits PASS. Frozen lab reference remains byte-identical; normal CI validation builds do not replace it.

### Failed/partial attempts retained independently

1. Synthetic signer test initially FAILED at check 58: unparenthesized PowerShell array concatenation created an unintended valid fixture. Corrected fixture grouping; independent rerun 78 PASS.
2. Python test setup initially errored before tests because the Windows subprocess lacked the existing process-only ExecutionPolicy Bypass invocation. Added that flag; no persistent host setting changed.
3. Next Python run had 1 failure / 3 passes: test expected synthetic blob length 27, actual fixture length 29. Corrected expected length; independent 4/4 PASS.
4. First native entrypoint test encountered UNKNOWN metadata because fake ADB emitted duplicate labels (each shell branch contains an UNKNOWN printf). A separate diagnostic reproduced duplicate metadata and parser rejection. Fixed only the fake fixture to emit each key once; independent 16-check run PASS. Parser remained strict.

The initial direct Windows Java verification emitted a native-access deprecation warning while verifying successfully. The production host wrapper uses the explicit process-only native-access flag and the same pinned SDK; the subsequent wrapper check had clean stderr. No verification failure was suppressed.

## INFERRED / current decision

**SIGNER_MISMATCH_BLOCKED** for the reported installed APK versus the approved lab, inferred from exact reported hash matching independently verified archived bytes. Fresh pull/signature confirmation remains owner-operated and NOT RUN. This is not an executed install rejection. The approved V2-signed lab has no demonstrated signing lineage that would establish compatibility with the old certificate. No attempt to obtain keys, re-sign, uninstall or bypass signing was made. [Android signing](https://developer.android.com/studio/publish/app-signing), [apksigner](https://developer.android.com/tools/apksigner), checked 2026-09-14.

## UNSPECIFIED / stop boundary

Current private state remains UNKNOWN until metadata readback. Historical 2026-09-12 identity/pairing absence is preserved but not reused as current evidence. Existing identity/removal/ACK contents are never read. Any present/unknown durable state blocks automatic update. All classifications are review results, never authorization to update. PRODUCT_PHYSICAL_ORACLE remains BLOCKED.

No device, backend, tunnel or emulator resources were started. Only host synthetic copies were created/removed. Owner bundle source/file hashes and the single read-only command are recorded in the final PR/issue handoff after freezing clean committed source.
