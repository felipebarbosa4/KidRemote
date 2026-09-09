# KR-003 Samsung calibration PASS and qualification handoff

- **Goal:** Ingest the one runner-v5 Samsung calibration without broadening its result, then publish an immutable 100-cycle active-oracle qualification bundle bound to that exact configuration.
- **Context:** The fixture-only transport already passed on `samsung` / `SM-X400`; source `4690d3951d0952fefe43eab9de0799599c6ea903` produced `calibration-20260908-231756-97a0855b` with `PASSED_ORACLE_CALIBRATION_THIS_CONFIGURATION_ONLY:COMPLETED`.
- **Constraints:** Preserve every historical run; calibration is excluded from qualification; no physical execution, pooling/resume, permission grant, screenshots, UI-node/text/content capture, package history, serial, production move, KR-004 work or cross-device inference. Unknown evidence fails closed.
- **Done when:** Strict ingestion and independent hash/provenance checks support every claimed calibration sub-check; only directly advanced matrix status is recorded; the configuration-bound runner retains 100 fresh active-oracle cycles, three checkpoint sessions, offline/finalization/bailout gates and exact APKs; PowerShell 5.1/7, Node, repository, release-isolation and Android checks pass; a new immutable bundle, Issue #3 and draft PR #16 are synchronized; physical execution remains `NOT_RUN`.

## Execution boundary

1. Re-read the mounted calibration and referenced transport evidence without modifying either directory.
2. Record safe structured fields and artifact hashes, distinguishing captured system metadata from owner labels.
3. Bind the qualification manifest to the captured manufacturer/model/Android/API/build/patch, calibration identity and exact candidate/fixture hashes.
4. Reject live configuration drift before the runner changes radios or starts its excluded preflight calibration.
5. Preserve the approved Q7 evidence model and fail-closed stopping/finalization semantics; do not assume Mi 8 metadata or transfer a Mi 8 physical result.
6. Package only from a clean committed source, verify mounted bundle bytes, publish the future one-command handoff, and stop.
