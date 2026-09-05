# Android Accessibility disclosure and Play evidence packet

- **Goal:** Make the consumer enforcement candidate understandable, optional and reviewable before asking for sensitive access.
- **Context:** ADR-0002 recommends a bounded Accessibility feasibility spike while Android's assistive-tool guidance and Google Play's conditional non-assistive uses remain in tension.
- **Constraints:** KidRemote is not an accessibility tool; no hidden access, content inspection, gestures, screenshots, autonomous decisions or claim of approval.
- **Done when:** The implemented flow matches this packet, refusal is safe, the exact manifest is audited, a truthful review video exists and applicable Google Play review accepts the use. Approval is **UNSPECIFIED**.

## Standalone in-app disclosure draft

Display this before the button that opens Android Accessibility settings, separate from terms, privacy policy and pairing:

> KidRemote uses Android Accessibility to show a screen-time block over ordinary apps when the time set by a parent is up. It does not read screen text or content, record typing, take screenshots, or perform gestures. Designated system, permission, emergency and recovery screens remain available. You can refuse or turn this access off in Android Settings; screen-time enforcement will then be unavailable or degraded.

Affirmative action label: **I understand — open Accessibility settings**.

Refusal action label: **Not now**. Refusal must return to permission health, keep setup incomplete, perform no accessibility work and explain that enforcement cannot be reported Healthy.
The spike keeps the disclosure visible and relies on the platform's manual settings toggle. A production onboarding screen with a distinct
“Not now” control remains part of the later child UI issue.

Usage Access needs a separate disclosure:

> KidRemote uses Usage Access to reconcile total screen-interactive and unlocked time. It does not retain or upload per-app history.

## Candidate declaration facts

| Question | Candidate answer / evidence |
| --- | --- |
| Is this a disability-support accessibility tool? | No; `android:isAccessibilityTool="false"`. |
| Core purpose | Deterministic parent-configured total screen-time restriction on an enrolled child device. |
| Why is Accessibility requested? | UsageStats measures signals but does not block; the candidate service displays the app-owned blocked surface over known ordinary apps. |
| Events | `typeWindowStateChanged` only in the spike. |
| Window content | Disabled: `canRetrieveWindowContent=false`; no node/source/text traversal. |
| Actions/capabilities | No gesture dispatch, screenshots, global actions, key logging or view interaction. |
| Package handling | Transient package classification only for ordinary vs safe/unknown surface; no package history retained or uploaded. |
| Autonomous behaviour | None. Parent policy and local deterministic time state decide whether restriction is required. |
| Disable/uninstall prevention | Not implemented or promised. |
| Approval | **UNSPECIFIED** until an applicable Play review accepts the exact release flow/listing/build. |

## Review-video checklist

Record only on a sanitized lab device:

1. Child onboarding context and separate Usage Access disclosure.
2. The complete Accessibility disclosure before leaving the app.
3. Refusal/Not now and the resulting Permission required state.
4. Affirmative button, Android's own settings/warning and manual enablement.
5. Timer use, ordinary-app block, safe settings/emergency/recovery route and permission revocation.
6. Permission health changing without falsely showing enforcement applied.
7. No personal app content, account identifiers, QR tokens or child data in the recording.

## Refusal and failure rules

- Never navigate to settings before affirmative action, auto-enable the service, suppress Android warnings or claim access is mandatory for account creation.
- Pairing may complete, but local setup remains incomplete and parent state must not say Healthy/applied.
- When access is revoked or the adapter fails, stop reporting an applied restriction, expose Permission required or Enforcement degraded and preserve known policy/accounting state.
- Unknown surfaces fail open in the spike for safety and report a degraded adapter result. This is a possible bypass and must not be hidden.
- Exact production safe-surface coverage, supported OEMs and listing/audience classification remain **UNSPECIFIED** pending physical and policy evidence.

Official sources rechecked 2026-09-05:
[Android Accessibility guide](https://developer.android.com/guide/topics/ui/accessibility/service),
[Play Accessibility declaration](https://support.google.com/googleplay/android-developer/answer/10964491),
[Play sensitive API policy](https://support.google.com/googleplay/android-developer/answer/16558241).
