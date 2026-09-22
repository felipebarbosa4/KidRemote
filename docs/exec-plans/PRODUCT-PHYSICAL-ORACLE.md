# OD-49 product-compatible independent oracle

- **Goal:** Implement the smallest host-owned canonical-control/independent-fixture driver for one future physical slice.
- **Context:** PR #24, source 5675a38; automatic recovery is locally demonstrated, physical oracle is blocked.
- **Constraints:** No physical commands, product hooks, FCM, permission changes, installation/update or historical evidence edits. No PASS from product telemetry alone.
- **Done when:** Windows driver and fail-closed outcomes are tested; transport/setup/provenance readiness is explicit; only a fully validated driver may become an immutable owner bundle. Preserve attempts and synchronize existing issues/PR.
