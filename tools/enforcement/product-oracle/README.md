# Product oracle preparation — BLOCKED

This directory is a tested host orchestration **core**, not an owner-ready physical driver or immutable bundle. `Start-ProductOracle.ps1` deliberately rejects before manifest access, HTTP or ADB. Do not remove that gate to obtain a run.

The reviewed APK's debug backend is `10.0.2.2:47366` (emulator host); release has no configured endpoint. There is no validated physical canonical-control transport. Live callback wiring, installed APK hash verification, durable on-disk attempt journal and complete end-to-end cleanup still require validation with that transport. Injected test callbacks are synthetic, not evidence of PostgreSQL, Android or physical execution.

## Reused independent oracle

The separate ordinary fixture schema-2 parser and `Assert-KRIndependentFixtureBlock` come from the unchanged KR-003 `Qualification.psm1`. Product control never calls spike ARM/CLEAR. Positive control requires known input to increment the same fixture's counter with usable focus. Three bounded blocked probes must preserve the counter and focus-gain count without usable focus; fixture restart, moved probe or ambiguous transport invalidates the observation. Unlock must restore independently usable input. Product desired/applied/attachment/ACK/parent status only corroborate; they cannot override fixture contradiction.

`ProductOracle.psm1` accepts host callbacks for preflight, initial report, canonical operations, normal activity-resume sync, fresh reports/status, fixture transport, pauses and journal writes. One UUID/body is retained for ambiguous operation retries. It preserves the original FAIL/INVALID when cleanup succeeds and records cleanup separately. No histories, content, bearer values or raw transport enter its result. The journal callback must become durable before an actual run is enabled.

`ProductTransport.psm1` has an enumerated ADB read/fixture-input allowlist and bounded canonical HTTP helper. There are no install/update, permission writes, force-stop, clear-data, capture or product receiver commands. These helpers are not yet a complete physical transport adapter. Metadata comparison is independently tested but not a substitute for reading and hashing the installed APKs.

## Future prerequisites — not instructions to execute now

1. Establish and validate a product-supported physical connection to the existing canonical backend without debug control hooks or a new enforcement architecture. Rebuild/provenance changes need explicit review; existing APK hash cannot describe a changed APK.
2. Read-only inventory must establish whether `dev.kidremote.child.unassigned.debug` is already installed, including retained state. KR-007's physical invalid-QR runner uses this same package. Current Samsung state is **UNSPECIFIED**; never replace/update it automatically. Absent/different product or fixture APK is INVALID pending owner review, not permission to install.
3. Owner would manually enable **KidRemote product** Accessibility service and Usage Access if absent, after safe installation/state review. Spike permission is not transferable. That run must stop before qualification; a separate preflight must read back both permissions. The driver must never toggle them.
4. Finish and test live callback wiring, strict canonical response validation, installed hash checks and durable attempt/cleanup recovery. Only then freeze one bundle with source/file/APK hashes and exact configuration. No owner execution command is currently provided.

Exact historical configuration: Samsung SM-X400, Android 16/API 36, build BP4A.251205.006, security patch 2026-07-05, battery saver disabled, app standby enabled. Adaptive/OEM battery policy remains UNSPECIFIED. Current configuration requires fresh readback before qualification; historical evidence does not transfer to other configurations.

## Verdict and cleanup

- **PASS:** positive input control, accepted canonical LOCK and fresh desired report, independent blocked input/focus, corroborating observed status, accepted canonical UNLOCK with positive allowance, independent restored input and final unrestricted status all verified.
- **FAIL:** ordinary usable focus/input contradicts required restriction.
- **INVALID:** provenance/setup/transport/schema/freshness/positive-control/cleanup ambiguity, including rejected control or unavailable backend. A prior FAIL remains FAIL if cleanup also fails.

Cleanup is canonical UNLOCK at the known expected version, with the same UUID on retry. It must not overwrite a newer concurrent command, mint time or reset accounting. No successful cleanup claim without independent restored input. Backend outage, expiry or uncertainty can leave cleanup **UNVERIFIED**; there is no unconditional cleanup guarantee and no permission-disable fallback. Each future attempt must have its own immutable record; no pooling or silent retry replacement.

Designed scope: one positive control, three blocked probes and one restored-input control, no 100-cycle qualification. Measured end-to-end duration is **UNSPECIFIED** until live transport is validated. Run only `ProductOracle.Tests.ps1` for device-free synthetic validation.
