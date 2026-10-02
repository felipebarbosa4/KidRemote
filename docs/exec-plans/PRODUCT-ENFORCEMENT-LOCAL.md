# Product enforcement integration — OD-49

- **Goal:** Integrate the existing KR-003 Accessibility candidate with durable KR-008 desired state and KR-009 ACK / KR-010 presentation; reference Issues #3/#10.
- **Context:** Clean baseline e007eb23331d5b1cc924f9b67ab9fb0329e39414; PR #23 remains unchanged. ADR-0002, STATE-MACHINE, LOCAL-TIME and the reviewed candidate are authoritative.
- **Constraints:** Repository-local and existing owned emulator only. No physical commands, capture, FCM, deployment, merge, new blocking design or historical evidence changes. Preserve A/B recovery and safe/unknown-surface behavior. No content/package history. Separate observed attachment from durable desired state.
- **Done when:** Bounded adapter, authenticated reports and truthful UI are tested with JVM/Room/service/HTTP/SQL and regressions, release isolation audited, CI recorded, draft stacked PR published. Physical unknowns remain open. Prepare only one future short handoff if the existing independent oracle can support it without destructive setup or weakened proof; otherwise document the blocker.

## Reuse assessment

Copy only SurfacePolicy / SurfaceEventResolver from LabTimer.kt, overlay layout/type/flags and Q5 Settings intent from EnforcementAccessibilityService. Keep the spike unchanged. Exclude LabTimerReducer/Store, device-protected lab preferences, ARM/CLEAR receivers, trace/latency counters, diagnostic UsageStats and all visual/qualification infrastructure from the product APK.

Physical tooling currently binds candidate package/hash and ARM/CLEAR protocol to the spike. Enabling the new product service also requires a distinct Android service permission; existing spike permission is not transferable. A future command must not pretend those prerequisites are already satisfied.
