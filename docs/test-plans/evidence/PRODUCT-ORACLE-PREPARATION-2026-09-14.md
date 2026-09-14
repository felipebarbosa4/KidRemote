# OD-49 product independent oracle preparation — BLOCKED

- **Goal:** Prepare a small Windows host-owned canonical-control/independent-fixture oracle.
- **Context:** Existing draft PR #24, baseline `5675a3881dd08ae4c2433470a809adc4b4711d47`.
- **Constraints:** No physical device command, product hook, FCM, permission change, installation/update, historical evidence modification or enforcement redesign.
- **Done when:** Tested core and explicit readiness boundary; immutable owner bundle only after complete live validation.

## OBSERVED

Owner authorization was appended to OD-49 without replacing earlier entries. Product code and historical runners/evidence are unchanged.

The new [host core](../../../tools/enforcement/product-oracle/README.md) reuses the separate fixture schema-2 parser and input/focus assertion, plus reviewed permission/stderr parsers. It models canonical LOCK/UNLOCK, stable operation UUID retries, fresh report requirements and independently verified cleanup. Attachment/ACK/applied status cannot override a fixture contradiction. A strict ADB command allowlist rejects installation, force-stop, settings writes and product ARM broadcasts before spawning a process.

The executable entrypoint is deliberately BLOCKED before ADB/HTTP. This is **not a complete live driver**: callback wiring, installed APK read/hash verification, durable on-disk journal and real canonical transport/cleanup have not been demonstrated. Synthetic callbacks do not establish network or Android results.

The current debug product source fixes its backend to `http://10.0.2.2:47366`; release endpoint is empty. Usage Access declaration is debug-only. No physical route to this backend was validated. Historical KR-007 physical invalid-QR tooling also uses `dev.kidremote.child.unassigned.debug`; replacing it could affect prior identity/state and is not automated.

Exact source/APK reference identities (previously exercised, **not newly exercised on Android here**):

| Item | Identity |
| --- | --- |
| Product APK source | `0b1ecdddf5b9843c16de513b1dce7081f6ed58af` |
| Child APK SHA-256 | `d2b3448b5c5574dc4ec693fc1e09386bae6ca1082e42c8c68f6c8c5d870b7f2f` |
| Ordinary fixture SHA-256 | `223219c17a31439b52698e769bdf03ead0998bbbe8bbb5c1b0ff5be3cfaf21dc` |
| Product package | `dev.kidremote.child.unassigned.debug` |
| Service | `dev.kidremote.child.unassigned.debug/dev.kidremote.child.enforcement.ChildEnforcementService` |

The fixture hash matches [historical Samsung calibration](KR-003-SAMSUNG-ORACLE-CALIBRATION-PASS-2026-09-08.md); the product APK does not inherit the spike candidate's qualification or permission. Review metadata is in `tools/enforcement/product-oracle/provenance.json`, not an immutable execution manifest.

### Independent validation attempts

1. Native Windows PowerShell 5.1: original 50 synthetic assertions PASS. No device/network calls.
2. Expanded parser test: FAILED at assertion 54, expected `INVALID:MISSING_OR_AMBIGUOUS_REPLY`, got `INVALID:MALFORMED_REPLY`. Test concatenated two Base64 replies without a separator, causing one malformed token. This failed test is retained here separately; it is not a physical verdict or product defect.
3. Corrected synthetic response framing: **58 assertions PASS**, including all-field provenance mismatches, missing product permission/spike permission non-transfer, rejected ADB commands, fixture positive-control failure, LOCK response loss/reused UUID, contradictory usable input/focus despite successful status callback, UNLOCK response loss/reused UUID, cleanup failure, journal failure before LOCK, malformed/stale/oversized fixture responses and blocked entrypoint before even opening a manifest.

Repository validator and whitespace check PASS. Node regressions: 99/99 PASS. Further build/audit/CI results are recorded after completion below.

## INFERRED

Existing independent fixture primitives are suitable for a small product driver, but a fake callback success cannot validate the product's physical transport. Enabling the current entrypoint would weaken evidence. Product/network configuration must be resolved before a live adapter and immutable owner command can be honestly supplied.

## UNSPECIFIED / NOT RUN

Current Samsung installed APK/state, product permissions, exact current configuration and safe installation/update compatibility remain UNSPECIFIED. No physical ADB command, install/update, permission toggle, capture, backend or emulator was started for this extension. No new Android runtime, SQL/HTTP or physical result is claimed; previously demonstrated integration/recovery remains in its original evidence.

**PRODUCT_PHYSICAL_ORACLE=BLOCKED.** No immutable owner bundle, bundle hash or future execution command is issued. Future manual setup is described separately in the README and requires safe state review plus explicit owner completion; qualification must stop until fresh readback verifies it. End-to-end duration is UNSPECIFIED. Cleanup is only verified after canonical Unlock plus independent restored input; outages/conflicts can leave it UNVERIFIED. No settings/destructive fallback is authorized.

### Local build and audit result

Debug/release Gradle build, unit-test and lint tasks SUCCESS in 24 seconds (372 tasks; 8 executed, 364 up-to-date). Existing JVM reports: child 84, parent 14 PASS. Child/parent merged-manifest, permission, privacy and release isolation audits PASS. Rebuilt debug child hash remains exactly `d2b3448b5c5574dc4ec693fc1e09386bae6ca1082e42c8c68f6c8c5d870b7f2f`. Three content-free recovery observer tests PASS. No new runtime evidence is inferred from cached JVM tasks or APK compilation.
