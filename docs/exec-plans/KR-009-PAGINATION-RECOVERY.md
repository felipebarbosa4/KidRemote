# KR-009 local pagination and recovery extension

- **Goal:** Consistent bounded snapshot pagination and durable push-independent lifecycle/retry convergence.
- **Context:** OD-47 extension, clean baseline `750916d`, existing Issue #9/PR #22 on `kr-009-local-sync`; CONTRACT and ADR-0006 remain authoritative.
- **Constraints:** Existing gateway, KR-007 identity and KR-008 Room/accounting; no FCM/provider, foreground service, enforcement, physical devices, deployment or next issue. Bounded data and no secret/history logging. Previous evidence unchanged.
- **Done when:** Real SQL/HTTP/Android pagination, restart/network/WorkManager and retry tests plus affected regressions/build/lint/security/CI pass; failures and APK identities retained; resources cleaned; bounded commits pushed and Issue #9/PR #22 synchronized with remaining physical/provider/performance gaps.
