# Product oracle and dedicated synthetic physical lab

## OD-51 current native runner

`Run-ProductReplacement.ps1` uses native Windows PowerShell, a frozen native Node
runtime and native Docker Desktop. It never enters WSL. The separate
`../physical-lab` lease retains its exactly owned synthetic PostgreSQL volume and
parent/device identity across normal stop/restart; the disposable KR-004 harness
is unchanged. DPAPI/current-user ACL protects local credentials, and an exclusive
host lock prevents concurrent runners. Source/schema/resource mismatch or partial
state stops for review. Service log retention is disabled; technical readiness is
checked without capturing service content.

Every device mutation follows the in-command host/backend/artifact/journal/read-only
target gate. A host failure is `INVALID_HOST_PREFLIGHT`, with zero device mutation.
The first successful setup uses OD-50 exact old provenance before replacement,
real product pairing and genuine Android consent. A verified subsequent lease/device/
APK/permission match uses `Reuse.psm1`: no uninstall, install, QR or consent prompt.
Canonical Unlock and, if needed, one dated +10 grant prepare positive allowance;
accounting uncertainty is never reset or bypassed.

`ProductOracle.psm1` remains the independent input-counter/usable-focus oracle.
Product attachment/Room/ACK/status corroborate only. Canonical Unlock plus independent
restored input is required for successful cleanup. Stop retains synthetic enrollment;
no implicit destructive reset. An explicit separately verified lease teardown journals
admission and deletes only its own containers/volume/network. Failed/partial journals
remain immutable and cannot be silently resumed or replaced.

Owner publication is conditional on all current-source CI and device-free checks,
then `../physical-lab/freeze.mjs` freezes all source/runtime/APK hashes. The immutable
manifest says `READY_FOR_ONE_OWNER_RUN` only for a safe attempt, never physical PASS.
See [current evidence](../../../docs/test-plans/evidence/PRODUCT-PERSISTENT-LAB-2026-09-14.md)
for the actual readiness verdict, failures and immutable bundle identity.

The [OD-50 preparation](../../../docs/test-plans/evidence/PRODUCT-REPLACEMENT-PREPARATION-2026-09-14.md)
remains historical: its failed Windows→WSL supervisor, disposable enrollment limitation
and BLOCKED verdict are not rewritten. Prior read-only bundles stay read-only;
`Start-ProductOracle.ps1` is the historical blocked entrypoint, not the new runner.

## Read-only inventory (separate bundle)

`ReadOnly-Preflight.ps1` imports only `ReadOnly.psm1`. It validates its manifest and both file hashes before spawning even ADB discovery. It requires one authorized attached target (no emulator/multiple targets), keeps the serial in memory, verifies Android user 0 and exact historical configuration, then reads only the two named packages. No serial, raw dumpsys/appops, content or secrets enter output. Five native synthetic entrypoint attempts independently test normal inventory, mismatch, rejected transport, manifest mismatch and file tampering.

Allowed commands: `devices`; exact `getprop` fields; `am get-current-user`; `pm path`; target-filtered `pm list packages -u`; target-only `dumpsys package`; exact `settings get`; target-only Usage Access appops; `sha256sum` of a strictly parsed installed `/data/app/.../base.apk`. No install/update/uninstall/clear-data, force-stop, app launch, touch/key, settings write, reverse, radio/navigation change, capture, backend call or LOCK/UNLOCK exists in this module.

Results: READY_FOR_INSTALL_REVIEW, PRODUCT_ALREADY_PRESENT_REVIEW_REQUIRED, CONFIGURATION_MISMATCH, PROVENANCE_UNVERIFIED, PERMISSION_SETUP_REQUIRED or INVALID_PREFLIGHT. **None authorizes installation or means enforcement PASS.** Package record absence cannot prove all data absent. Same product package was used by older KR-007 tooling, so existing state must be preserved. Signing certificate digest is UNSPECIFIED when bounded shell reads cannot obtain it; dumpsys signature hash codes are never relabeled SHA-256 certificates. Base APK SHA-256, version and stopped state are separate observations. Split/multiple paths or metadata ambiguity fail closed. Hash denial yields PROVENANCE_UNVERIFIED.

Exact historical configuration: Samsung SM-X400, Android 16/API 36, build BP4A.251205.006, patch 2026-07-05, battery saver disabled, app standby enabled. Adaptive/OEM battery policy remains UNSPECIFIED. Product Accessibility component and Usage Access are read independently; spike permission does not transfer.

`freeze-preflight.mjs` accepts the owner-local root, requires clean committed source and refuses an existing destination. It freezes only the two read-only files and manifest. The manifest SHA-256 pins every executable file; no canonical module, APK or lab controls enter the bundle. Every result, including invalid attempts, gets a unique host JSON file under `%LOCALAPPDATA%\KidRemote\product-preflight-results`. Paste only the emitted sanitized JSON. No screenshots or raw ADB output are requested.

## Durable future attempt journal

`Journal.psm1` creates a unique directory and flushes source/bundle/APK/configuration provenance before use. Events use exclusive writer locking, create-new temporary files, `Flush(true)`, atomic rename, per-record checksum and a chain anchored to provenance. An interrupted/truncated temporary record is preserved and blocks further admission. Readers can inspect complete prior rows after restart; existing attempts cannot silently become a fresh run. A checksum is corruption detection, not protection from a malicious host.

Canonical LOCK/UNLOCK admission records carry the same operation UUID and expected version before HTTP is called. The original verdict is write-once; cleanup has its own event. A known failure is journaled before cleanup. Reopening an unfinished attempt is review-only: no automatic replay of an unknown mutation or permission to pool it into another run. Host power-loss/filesystem-controller guarantees beyond tested process/write seams are UNSPECIFIED. These journal helpers are not shipped in the read-only inventory bundle.

## Canonical host callbacks

`Canonical.psm1` supplies injectable local Auth/mail/household setup, initial own-device/report read, canonical LOCK/UNLOCK, fresh report and operation-status callbacks. It uses the existing KR-009 routes on fixed loopback ports. Parent JWT remains a SecureString between requests, with transient marshaling only; raw errors/bodies are never evidence. Setup uses synthetic `@example.test` identities and local mail verification; no elevated key or automatic child enrollment is added.

Device/epoch, numeric/boolean fields, version, report freshness and period key (`revision:date`) are validated. Same request retries preserve UUID and expected version. Conflict/newer command never causes automatic expected-version adjustment. Timeout/refusal/401/403/conflict/malformed/stale/cleanup-outage tests are **synthetic callback tests**, not live gateway or physical evidence. Actual product sync remains through the existing child lifecycle; it cannot be simulated by a parent callback. Live physical convergence remains unrun.

## Lab APK / future transport

`-PkrPhysicalLab=true` selects **only** a fixed debug BuildConfig endpoint `http://127.0.0.1:47366` and versionName suffix `-physical-lab`. Normal debug retains `10.0.2.2:47366`; release Backend remains empty and has no lab endpoint in DEX. No QR/user-selected host, runtime menu, receiver or enforcement hook is added. Existing network-security rules already permit only these two debug hosts; release permissions/security stay unchanged. The package/signing identity intentionally still collides with existing debug state: this is a blocker for automatic install, not permission to replace it.

A future explicitly approved ADB reverse of only TCP 47366 can connect this APK to the existing host-loopback gateway; `Get-LabReverseArguments` provides the fixed argument plan for synthetic validation. **No reverse is executed or included in preflight.** Tunnel ownership/readback and physical connectivity still need a future authorized live step; no LAN listener is introduced. `build-lab.mjs` inspects the actual APK endpoint/version/certificate and release DEX. Dirty-source builds are validation-only and cannot freeze an artifact.

## Qualification criteria retained

PASS requires positive fixture input, canonical Lock, independently blocked input/focus, corroboration, canonical Unlock with positive allowance, independently restored input and final unrestricted status. Usable fixture input/focus under restriction is FAIL; provenance/setup/transport/oracle ambiguity is INVALID. Cleanup uses canonical UNLOCK at the original expected version, never adds time/resets accounting/toggles permission. Outage/conflict can leave cleanup UNVERIFIED. Every failed/partial attempt remains separate. No physical performance, safety, OEM lifecycle or enforcement acceptance follows from these host tests.

Platform reference checked 2026-09-14: [AOSP ADB manual](https://android.googlesource.com/platform/packages/modules/adb/+/refs/heads/main/docs/user/adb.1.md) documents serial selection, device listing and `reverse [--no-rebind] REMOTE LOCAL`. It establishes command syntax, not successful Samsung connectivity. No ADB global listen-all option is used.
