# KR-010 local parent workflow — OD-48

- **Goal:** Usable authenticated MY DEVICES/detail with real reported state and +10/+30/Lock/Unlock/explicit daily-limit control, reusing KR-009.
- **Context:** Baseline `a3c6335`; Issue #10; existing KR-006 Compose/Auth/vault, KR-007 pairing and KR-009 canonical operations/Room/ACK. PRODUCT, STATE-MACHINE, DESIGN-SYSTEM and CONTRACT define semantics.
- **Constraints:** One local-only stacked branch/draft PR. No invented allowance, optimistic enforcement, fake countdown, parallel backend, surveillance, screenshots, physical action, FCM, deployment or merge. Keep original decisions/evidence and earlier PRs unchanged.
- **Done when:** Actual parent→PostgreSQL/gateway→child Room→ACK→parent UI cases execute on owned emulator; affected JVM/Compose/SQL/HTTP/regressions, build/lint/security and CI pass; independent failures and exact APK identities are recorded; Issue #10/draft PR synchronized and task services cleaned. Physical AC-5/6/8 and production performance remain unrun.

Implementation: bounded invoker/RLS read projection of existing canonical policy/latest report; existing gateway mutations/status; pure presentation model plus existing ViewModel; one durable retry request excluded from backup and cleared on logout, with no bearer in request storage. No new child accounting/sync architecture.

Evidence will distinguish OBSERVED / INFERRED / UNSPECIFIED. Compose semantics, not screenshots or semantics-tree dumps, validate labels/actions/size. References: [testing APIs](https://developer.android.com/develop/ui/compose/testing/apis), [accessibility defaults](https://developer.android.com/develop/ui/compose/accessibility/api-defaults). OS/physical accessibility and enforcement are not inferred from emulator tests.
