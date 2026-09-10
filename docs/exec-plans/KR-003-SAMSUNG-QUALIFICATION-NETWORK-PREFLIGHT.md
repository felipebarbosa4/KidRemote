# KR-003 Samsung qualification network-preflight repair

- **Goal:** Ingest the first configuration-bound Samsung qualification attempt, identify its operation-specific pre-cycle boundary, and publish a capability-aware replacement without executing it.
- **Context:** The exact `samsung` / `SM-X400` / Android 16 API 36 configuration already passed fixture transport and one excluded active-oracle calibration. Runner-v8 run `run-20260909-003140-758ee7f6` stopped `INVALID:ADB_REJECTED` while entering offline mode.
- **Constraints:** Preserve the run independently; no rerun, qualification sample, enforcement-failure inference, raw command output, identifier/content capture, root, airplane-mode substitution, permission change, production move or KR-004 work. Every declared network path must be disabled and read back; unknown capability/state and unverified restoration fail closed.
- **Done when:** Strict ingestion records the exact retained facts and unknowns; the runner uses Android system-feature capability rather than a global-setting value to decide whether mobile data applies; safe operation/exit/error-class diagnostics are retained; required PowerShell 5.1/7, Node, repository, isolated Android and CI checks pass; one clean-source immutable replacement is hash-verified; Issue #3 and PR #16 report one INVALID attempt before cycle 1; no physical command is run.

## Execution boundary

1. Read and hash the mounted run without modifying it.
2. Reconstruct only boundaries compelled by the immutable v8 source and journals; do not invent the discarded command exit/stderr.
3. Probe only `android.hardware.wifi` and `android.hardware.telephony.data` through `pm has-feature`; retain typed presence and operation results, never raw feature/settings/service output.
4. Treat a declared transport as mandatory to disable, verify and restore. Treat an absent transport as `NOT_APPLICABLE`. Any unknown probe or state is INVALID.
5. Preserve original state before mutation, attempt finalization after partial mutation, and never replace the primary result with cleanup failure.
6. Stop after immutable publication and administrative synchronization.
