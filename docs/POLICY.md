# Google Play and distribution feasibility assessment

- **Goal:** Identify release constraints before building the production enforcement system.
- **Context:** Official policy documentation initially reviewed **2026-09-05**; mobile target-API requirement rechecked **2026-09-08**; two Android apps, future Apple note only.
- **Constraints:** No claim of review approval; audience and legal markets are **UNSPECIFIED**.
- **Done when:** KR-003 produces a concrete least-privilege flow, safe physical evidence and an owner-reviewed submission assessment.

## Assessment result

Consumer enforcement is a **conditional feasibility candidate**, not cleared for production.
The technical ADR and this documentary assessment are complete enough to run a bounded spike.
Play Console submission/approval and supported-device evidence are **UNSPECIFIED**; production gate stays closed.

| Area | Current constraint | Required evidence / owner decision |
| --- | --- | --- |
| Accessibility purpose | Android guide narrows services to assistive tools; Play allows other declared uses conditionally | Resolve documented tension with policy reviewer and concrete flow; ADR-0002 |
| Accessibility disclosure | Non-accessibility tools need prominent in-app disclosure, affirmative consent, declaration/demo and listing explanation | Standalone consent flow; do not set isAccessibilityTool=true |
| Deterministic automation | Rule-based actions are distinguished from autonomous planning/actions in policy | Static parent rules only; no AI monitoring/control |
| Disable/uninstall | Policy contains parent-authorized exception but forbids security/privacy-control circumvention | No uninstall interception in MVP; do not infer technical capability from exception |
| Foreground service | Type/manifest use case and restrictions apply if used | Prefer system-bound service spike; specialUse needs review if required |
| Target SDK | New apps/updates require Android 16/API 36+ from 2026-08-31 in current mobile Play requirements | Actual chosen SDK **UNSPECIFIED**; reverify stable tooling and policy at bootstrap/release |
| Families/audience | Target audience declaration affects data/SDK rules | Parent/child listings classified separately; OD-13 |
| Monitoring classification | Sending sensitive state about another person may trigger monitoring-app rules | Applicability **UNSPECIFIED**; review isMonitoringTool=child_monitoring and visibility obligations if applicable |
| User data / deletion | Accurate Data safety, privacy policy and account-deletion entry points | Data-flow audit, in-app and web deletion tests |
| Store assets | Real core UI and truthful claims; generated concepts are not functioning screenshots | Replace/validate mockups at launch |

Official sources: [Android Accessibility](https://developer.android.com/guide/topics/ui/accessibility/service),
[Play API policy](https://support.google.com/googleplay/android-developer/answer/16558241),
[Accessibility declaration](https://support.google.com/googleplay/android-developer/answer/10964491),
[FGS types](https://developer.android.com/develop/background-work/services/fgs/service-types),
[target API](https://developer.android.com/google/play/requirements/target-sdk),
[Families](https://support.google.com/googleplay/android-developer/answer/9893335?hl=en),
[monitoring metadata](https://support.google.com/googleplay/android-developer/answer/12955211?hl=en),
[Data safety](https://support.google.com/googleplay/android-developer/answer/10787469),
[deletion](https://support.google.com/googleplay/android-developer/answer/13327111),
[preview assets](https://support.google.com/googleplay/android-developer/answer/9866151?hl=en).

## Least-privilege candidate inventory

Internet/network state; Usage Access special settings grant; system-bound AccessibilityService declaration with BIND_ACCESSIBILITY_SERVICE;
boot recovery receiver with appropriate boot permission; foreground-only camera scanning if a camera-based scanner is selected.
Notification runtime permission must be evaluated for the chosen visible status/FCM notification flows.
No broad package query, overlay permission unrelated to the selected mechanism, location, contacts, SMS, microphone,
media, VPN, exact-alarm, wipe, password-reset or Device Admin permission without a new justified ADR.
The disposable KR-003 candidate now declares Usage Access, boot receipt and the system-protected Accessibility service only; it deliberately has
no Internet, broad package query, unrelated overlay, Device Admin, camera, location or audio permission. Its configuration uses
`typeWindowStateChanged`, `canRetrieveWindowContent=false` and `isAccessibilityTool=false`; merged-manifest CI audit is required.
This is spike evidence, not a final production manifest or Play acceptance.
[Exact disclosure/declaration packet](product-specs/ANDROID-ACCESSIBILITY-DISCLOSURE.md),
[spike](../spikes/android-enforcement/README.md).

## Release evidence packet

Architecture/ADR; exact child disclosure and refusal path; permission setup and denial video; explanation of why narrower APIs are insufficient;
minimal event configuration; synthetic traffic/schema/log inventory; physical timer/boot/emergency/recovery results;
target-audience/monitoring classification; Data safety/privacy/deletion; accurate listing screenshots; current target SDK.
Owner/policy sign-off is a release decision. Documentation research is not legal advice or Google approval.

## Future Apple

App screenshots must reflect actual UI; Family Controls distribution entitlement approval is an external prerequisite.
No Apple screenshots are uploadable for a non-existent iOS application.
[Apple guidelines](https://developer.apple.com/app-store/review/guidelines/),
[entitlement](https://developer.apple.com/documentation/FamilyControls/requesting-the-family-controls-entitlement).
