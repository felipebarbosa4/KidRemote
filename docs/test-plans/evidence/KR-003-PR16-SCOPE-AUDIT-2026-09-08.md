# KR-003 PR #16 scope and isolation audit — 2026-09-08

- **Goal:** Decide whether accumulated PR #16 work remains one coherent KR-003 feasibility change and verify that diagnostic capability stays disposable/release-isolated.
- **Context:** The draft PR contains the Mi 8 failure/repair/transport evidence chain, debug harness automation and next-device readiness. Historical commits and physical evidence must remain reviewable.
- **Constraints:** No history rewrite or aesthetic split; no deletion/rewording of earlier PASS/FAIL/INVALID evidence; no production move, device action, store/deployment action or KR-004 work.
- **Done when:** Scope, stale/duplicate material, production-facing paths, permissions/logging, release DEX/manifests, bundle/history links and validation are reviewed; only evidence-preserving cleanup is applied.

## Scope conclusion

Keep PR #16 intact and draft. Its size is substantial, but every material file belongs to one falsifiable KR-003 chain: Mi 8 overlay stability,
safe recovery iterations, independent-oracle design, denied transports, evidence ingestion, release isolation and the next authorized-device preflight.
Splitting or rewriting the already published chain would make physical source/APK/bundle provenance harder to review. The PR title should be generalized
from “Mi 8 overlay stability” to the final KR-003 scope; this is metadata cleanup, not history rewriting.

No production application, backend, migration, protocol wire contract, deployment or store asset is introduced. The only repository-root/product
surfaces are planning documentation and CI checks. All Android implementation remains under `spikes/android-enforcement`; all host automation
remains under `tools/kr003` plus the historical Mi 8 checkpoint helper.

## Duplicate and stale review

- `KR-003-Q6-QUALIFICATION.md` and its bundle record are intentionally retained and explicitly marked superseded-before-execution. They are
  historical decision evidence, not a runnable current handoff.
- Q2–Q7 bundle/result documents are not duplicates: each pins a different source/hash/status transition. Deleting them would break GitHub comments
  and the evidence chronology.
- The Mi 8-specific Q7, shell/UiAutomation/Monkey runners and packagers remain reproducibility sources for preserved evidence. Current next-device
  instructions now point to separate generic transport/calibration tooling.
- `tools/kr003-mi8-checkpoint.ps1` remains the source for the ten-cycle Mi 8 checkpoint and is not promoted to the generic flow.
- Shared generic metadata, permission parsing and verdict logic is centralized in `DevicePreflight.psm1`; the new device and calibration runners
  duplicate only their intentionally different ADB orchestration stages.
- Stale “stop for owner selection” handoffs were reconciled to OD-31. Unknown Samsung facts and runtime outcomes remain **UNSPECIFIED**.

No evidence-bearing file is safe to delete. No history rewrite or PR split is recommended.

## Security and release isolation

The enforced build audit requires:

- candidate main/release permissions limited to Usage Access and boot receipt; ordinary fixture and input probe have zero permissions;
- sender-`DUMP`-protected candidate/fixture receivers in debug only;
- self-targeted input instrumentation and Monkey helper in debug only;
- no lab receiver, instrumentation, trace/probe/helper class, typed debug tag or injection string in release manifests/DEX;
- no Internet, broad package, overlay permission, device-admin, camera, location or microphone permission;
- no Accessibility node/root/text/content, screenshot, gesture or global-action access;
- a single typed sanitized debug log sink and a no-op release trace implementation.

The generic fixture-only bundle contains no candidate APK. Its runner never arms a timer or changes permission, network or device configuration.
The conditional calibration bundle contains the disposable candidate, but rejects any qualification loop and records `QualificationSamples=0`.
Both persist typed operation classes instead of raw ADB output and reject serial, Android ID, build fingerprint, account, package-history and content fields.

## Verification record

Repository-local results before the packaging commit:

- 24/24 Android JVM cases, debug/release lint and builds passed;
- all six debug/release merged-manifest and release-DEX isolation checks passed;
- 19 Node evidence/security tests passed, including generic metadata/operation rejection and transport/calibration anti-promotion cases;
- 34 generic device-preflight and 8 oracle-calibration PowerShell assertions passed under Windows PowerShell 5.1;
- existing Windows PowerShell suites passed: 104 finalization, 18 shell transport, 61 UiAutomation and 86 Monkey assertions;
- repository validation and `git diff --check` passed.

The legacy `Qualification.Tests.ps1` suite requires PowerShell Core because it spawns `pwsh` from `$PSHOME`; that executable is unavailable in
the local Windows PowerShell 5.1 installation. The unchanged GitHub Linux job runs it under PowerShell Core, so exact-source CI remains the required
coverage before publication. Immutable bundle hashes are recorded after a clean source commit. Automated checks do not alter or certify the Mi 8
physical evidence, a Samsung result, production enforcement, RLS or Google Play acceptance.
