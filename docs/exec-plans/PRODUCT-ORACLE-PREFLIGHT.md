# OD-49 device-free prerequisites

- **Goal:** Complete host persistence/transport/provenance boundaries and freeze one read-only owner inventory bundle.
- **Context:** PR #24, baseline 0b4dfb1; independent fixture core tested, physical oracle BLOCKED.
- **Constraints:** No physical commands, qualification, FCM, destructive operations or product control hooks. Debug-only fixed lab endpoint; release unchanged. No serial/secrets/content in evidence.
- **Done when:** Failure-injected host tests, APK isolation and CI pass; one hashed read-only bundle exists; unresolved live prerequisites and all partial attempts are explicit.
