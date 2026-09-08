# KR-003 next-device readiness

- **Goal:** Make the next authorized Android configuration ready for a transport-first KR-003 evaluation without changing or generalizing the preserved Mi 8 evidence.
- **Context:** The Mi 8/API 29 configuration rejects shell, UiAutomation and bounded Monkey input with `SECURITY_EXCEPTION`; Q7 stopped before sample 1. The owner expects an authorized Samsung tablet whose exact model, Android version, API, build and power configuration are **UNSPECIFIED** until read from the device.
- **Constraints:** KR-003 only; repository-local preparation tonight; no physical command, Samsung assumption, Mi 8 configuration change, production code, network change, destructive action, serial/account/content collection, evidence pooling or weakened gate.
- **Done when:** A hash-pinned fixture-only onboarding bundle and command are ready; a separate bounded active-oracle calibration workflow is prepared; current plans classify all remaining work A–E; device-to-matrix mapping and PR scope/isolation are audited; local/CI checks pass; GitHub issue/PR status reflects the new handoff.

## Execution

1. Audit current KR-003 documents, ADRs, evidence, GitHub issue/PR and release boundaries. Preserve every historical physical result.
2. Add a generic transport-first protocol and Windows PowerShell runner that records only approved sanitized metadata, verifies bundle and installed-fixture hashes, makes one tap, checks one counter increment and stops.
3. Add a separate bounded oracle-calibration runner for use only after transport PASS. It may install the unchanged disposable candidate, requires owner-established permissions, exercises one unblocked positive control, one blocked negative control, service continuity and one physical agreement check, then stops with zero qualification rows.
4. Separate configuration discovery/matrix mapping, transport capability, oracle calibration, 100-cycle qualification and human-only residual risks in the source-of-truth documents.
5. Add synthetic rejection/ingestion tests, package immutable bundles only from a clean committed source, and run the repository, PowerShell, Node, Android and release-isolation suites.
6. Push bounded checkpoints, wait for exact-source CI and synchronize Issue #3 / PR #16 / Project without closing, merging or starting KR-004.

## Stop point

Repository work stops after the generic bundles, validation, GitHub synchronization and morning handoff are complete. Physical metadata, transport and calibration outcomes remain **UNSPECIFIED** until owner execution. A transport FAIL/INVALID stops before candidate installation; a calibration FAIL/INVALID stops before 100 cycles.

## Repository checkpoint

Source `5a46f75e3dad68ccbf520bce327a6d1f1c03c77c` completed steps 1–5, including the synthetic no-delivery ingestion correction. The two immutable, independently rehashed mounted-Windows handoffs are recorded in [KR-003-NEXT-DEVICE-BUNDLES-2026-09-08](../test-plans/evidence/KR-003-NEXT-DEVICE-BUNDLES-2026-09-08.md). At that checkpoint their physical execution state was **Not run**. Earlier implementation/handoff checkpoints passed all three CI jobs; exact-source run 34190844982 verifies the corrected source. Issue #3 and PR #16 were updated/read back, KR-003 remains Open/In Progress, PR #16 remains Open/draft and KR-004 remains Open/Backlog. Repository-local readiness work was complete pending owner operation of an authorized device.

Superseding physical state: the source-`5a46f75` transport bundle passed on Samsung SM-X400; three calibration runs remain INVALID at runner-side
Accessibility verification. Continue only under [the bounded verifier correction](KR-003-SAMSUNG-PERMISSION-VERIFIER.md). The earlier readiness
checkpoint remains historical and is not rewritten as a calibration PASS.
