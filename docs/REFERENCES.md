# Authoritative references and verification record

- **Goal:** Anchor significant platform, policy and security claims in official documentation.
- **Context:** Initial architecture review performed **2026-09-05** (America/Toronto).
- **Constraints:** Official primary sources only. Review date is not policy approval, test execution, or a claim about future stability.
- **Done when:** Claims link next to their use and decision gaps are explicit.

Entries were initially reviewed on **2026-09-05** using official pages, official indexed documentation, vendor DocC JSON, or official GitHub API/CLI documentation.
Rows with a later verification date were rechecked independently; this does not imply every other row was re-reviewed on that date.
Where a web reader returned only JavaScript, Apple framework contents were additionally obtained from its official documentation JSON.
Page modification dates are listed only where observed; otherwise publisher modification date is **UNSPECIFIED**.
Recheck current docs at implementation and before release. No exact mobile/backend SDK versions are selected here.

## Significant discrepancies and limitations

1. Android Accessibility guide narrows intended purpose to assistive tools, while Play permits broader declared uses conditionally. ADR-0002 flags this tension; no automatic production approval.
2. Current FCM REST Message prefers fid and marks token deprecated, while Android setup retains token examples. CONTRACT models address kind; KR-009 must validate real compatibility.
3. Supabase publishable/secret keys are current; anon/service_role are legacy, with elevated keys still backend only. Disabling an Edge JWT check is not device authentication.
4. Current mobile Play target requirement is API 36+ from 2026-08-31; actual chosen target/toolchain remains UNSPECIFIED.
5. Three requested store concepts are not the four-shot set for Play recommendation formats; real UI captures are required before submission.
6. Android ordinary install/QR pairing cannot silently become managed provisioning. Monotonic time cannot prove true calendar time across arbitrary offline reboot/clock edits.
7. Initial unavailable/old documentation paths were replaced with the current official links below. No failed page was treated as proof.
8. Physical Android/OEM enforcement, Play review, provider-project rollout and Apple remote parity remain UNSPECIFIED. Documentation is not test evidence.

## OpenAI / Codex

| Official source | Constraint reviewed | Verified |
| --- | --- | --- |
| [Best practices](https://learn.chatgpt.com/guides/best-practices) | Goal/context/constraints/completion and durable context | 2026-09-05 |
| [Repository AGENTS.md](https://learn.chatgpt.com/docs/agent-configuration/agents-md) | Short repository instruction map | 2026-09-05 |
| [Prompting](https://learn.chatgpt.com/docs/prompting) | Bounded task prompts and useful context | 2026-09-05 |

## Android

| Official source | Constraint reviewed | Verified |
| --- | --- | --- |
| [UsageStatsManager](https://developer.android.com/reference/android/app/usage/UsageStatsManager) | Usage Access, limited event retention, pre-first-unlock constraints | 2026-09-05 |
| [UsageEvents.Event](https://developer.android.com/reference/android/app/usage/UsageEvents.Event) | Interactive/keyguard event semantics and API 28 availability | 2026-09-05 |
| [SystemClock](https://developer.android.com/reference/android/os/SystemClock) | Monotonic elapsedRealtime and deep sleep; page showed updated 2026-08-03 | 2026-09-05 |
| [PowerManager](https://developer.android.com/reference/android/os/PowerManager) | Current interactive-state query | 2026-09-05 |
| [KeyguardManager](https://developer.android.com/reference/android/app/KeyguardManager) | Keyguard presentation vs credential lock | 2026-09-05 |
| [Create an Accessibility service](https://developer.android.com/guide/topics/ui/accessibility/service) | Current assistive-tool-only guidance; conflicts with broad consumer assumption | 2026-09-05 |
| [AccessibilityService API](https://developer.android.com/reference/android/accessibilityservice/AccessibilityService) | System-bound lifecycle, global actions and accessibility overlays | 2026-09-05 |
| [Background execution limits](https://developer.android.com/about/versions/oreo/background) | Ordinary started services vs bound services | 2026-09-05 |
| [Foreground service start restrictions](https://developer.android.com/develop/background-work/services/fgs/restrictions-bg-start) | Background launch and while-in-use constraints | 2026-09-05 |
| [Foreground service types](https://developer.android.com/develop/background-work/services/fgs/service-types) | specialUse declaration/review, not blanket approval | 2026-09-05 |
| [Work requests](https://developer.android.com/develop/background-work/background-tasks/persistent/getting-started/define-work) | Periodic work minimum/inexact timing | 2026-09-05 |
| [Device administration](https://developer.android.com/work/device-admin) | Legacy capabilities and deprecation | 2026-09-05 |
| [Device admin deprecation](https://developers.google.com/android/work/device-admin-deprecation) | Specific policy removals; not all Device Admin is deprecated | 2026-09-05 |
| [DevicePolicyManager](https://developer.android.com/reference/android/app/admin/DevicePolicyManager) | lockNow and managed-role capabilities; avoid stale resetPassword examples | 2026-09-05 |
| [Build a DPC](https://developer.android.com/work/dpc/build-dpc) | Owner/profile management distinctions | 2026-09-05 |
| [Dedicated-device provisioning](https://developer.android.com/work/dpc/dedicated-devices) | Factory reset and managed enrollment; different from consumer pairing | 2026-09-05 |
| [Lock Task](https://developer.android.com/work/dpc/dedicated-devices/lock-task-mode) | DPC allowlisting vs user-exitable pinning | 2026-09-05 |
| [Android stopped-package changes](https://developer.android.com/about/versions/15/behavior-changes-all) | Force-stop persists until user interaction; pending intents cancelled | 2026-09-05 |
| [Android 17](https://developer.android.com/about/versions/17/) | Current API 37 platform; no automatic SDK/support selection | 2026-09-08 |
| [Android API levels](https://developer.android.com/guide/topics/manifest/uses-sdk-element.html) | Android 17 maps to API 37 | 2026-09-08 |
| [Hardware device setup](https://developer.android.com/studio/run/device) | USB debugging, device authorization and ADB connection verification | 2026-09-08 |
| [Doze and App Standby](https://developer.android.com/training/monitoring-device-state/doze-standby) | Generic power modes and user battery-optimization state do not establish OEM policy | 2026-09-08 |
| [Android 16 AccessibilityManagerService](https://android.googlesource.com/platform/frameworks/base/+/refs/heads/android16-release/services/accessibility/java/com/android/server/accessibility/AccessibilityManagerService.java) | Current-user enabled-service persistence/parsing uses colon-delimited `ComponentName` values; not a stable `dumpsys` text contract | 2026-09-08 |
| [Android ComponentName](https://android.googlesource.com/platform/frameworks/base/+/refs/heads/android16-release/core/java/android/content/ComponentName.java) | Full and leading-dot short flattened class forms normalize to the same package/class identity | 2026-09-08 |
| [Android 16 AppOps](https://android.googlesource.com/platform/frameworks/base/+/refs/heads/android16-release/core/java/android/app/AppOps.md) | App-op names are stable relative to integer codes; absent/default/non-allowed state cannot be promoted to allowed | 2026-09-08 |
| [AOSP multi-user testing](https://source.android.com/docs/devices/admin/multi-user-testing) | Resolve current foreground user and explicitly scope user-aware shell commands | 2026-09-08 |
| [Android system navigation](https://support.google.com/android/answer/9079644) | Gesture Home is swipe up from the bottom; three-button Home uses the on-screen Home control; OEM steps may vary | 2026-09-09 |
| [Android 16 navigation-mode setting](https://android.googlesource.com/platform/frameworks/base/+/android16-release/core/java/android/provider/Settings.java) | Hidden current-user secure value maps 0/1/2 to three-button/two-button/gestural; shell use is read-only and unknown fails closed | 2026-09-09 |
| [Android 16 navigation resource](https://android.googlesource.com/platform/frameworks/base/+/android16-release/core/res/res/values/config.xml) | AOSP navigation interaction mode independently documents the same 0/1/2 meanings | 2026-09-09 |
| [Direct Boot](https://developer.android.com/privacy-and-security/direct-boot) | Device/credential-encrypted storage and component availability | 2026-09-05 |
| [Android Keystore](https://developer.android.com/privacy-and-security/keystore) | Key storage/wrapping boundary; compromised OS limitations | 2026-09-05 |
| [Auto Backup](https://developer.android.com/identity/data/autobackup) | Backup/device-transfer exclusion requirements | 2026-09-05 |
| [Room](https://developer.android.com/training/data-storage/room) | Recommended structured local persistence | 2026-09-05 |
| [DataStore](https://developer.android.com/topic/libraries/architecture/datastore) | Persistence alternative for smaller preference state | 2026-09-05 |
| [Material 3 in Compose](https://developer.android.com/develop/ui/compose/designsystems/material3) | Native design system guidance | 2026-09-05 |
| [Accessibility API defaults](https://developer.android.com/develop/ui/compose/accessibility/api-defaults) | Touch target/semantic defaults | 2026-09-05 |

## Google Play

| Official source | Constraint reviewed | Verified |
| --- | --- | --- |
| [Sensitive permissions and APIs](https://support.google.com/googleplay/android-developer/answer/16558241) | Broader declared Accessibility uses, parental exception and security-control prohibition | 2026-09-05 |
| [Accessibility declaration and use](https://support.google.com/googleplay/android-developer/answer/10964491) | Disclosure/consent/declaration/video; deterministic automation distinction | 2026-09-05 |
| [Target API requirements](https://developer.android.com/google/play/requirements/target-sdk) | New mobile apps/updates API 36+ from 2026-08-31 | 2026-09-08 |
| [Target audience](https://support.google.com/googleplay/android-developer/answer/9867159) | Accurate audience classification; owner choice not inferred | 2026-09-05 |
| [Families](https://support.google.com/googleplay/android-developer/answer/9893335?hl=en) | Children's data/identifier and SDK constraints | 2026-09-05 |
| [Data safety](https://support.google.com/googleplay/android-developer/answer/10787469) | Actual collection/sharing declarations | 2026-09-05 |
| [Account deletion](https://support.google.com/googleplay/android-developer/answer/13327111) | In-app and external deletion path requirements | 2026-09-05 |
| [Monitoring metadata](https://support.google.com/googleplay/android-developer/answer/12955211?hl=en) | child_monitoring classification may apply; owner policy review | 2026-09-05 |
| [Preview assets/screenshots](https://support.google.com/googleplay/android-developer/answer/9866151?hl=en) | Two basic screenshots vs four for recommendation formats; actual experience | 2026-09-05 |

## Supabase / PostgreSQL

| Official source | Constraint reviewed | Verified |
| --- | --- | --- |
| [Auth](https://supabase.com/docs/guides/auth) | Parent identities and supported login methods | 2026-09-05 |
| [Sessions](https://supabase.com/docs/guides/auth/sessions) | Session/token lifecycle and signout limitations | 2026-09-05 |
| [Auth rate limits](https://supabase.com/docs/guides/auth/rate-limits) | Auth-specific limits, separate from KidRemote proposed API quotas | 2026-09-05 |
| [RLS](https://supabase.com/docs/guides/database/postgres/row-level-security) | auth.uid, grants, RLS, definer/view boundaries | 2026-09-05 |
| [API keys](https://supabase.com/docs/guides/getting-started/api-keys) | Publishable/secret vs legacy anon/service_role; secret keys bypass RLS | 2026-09-05 |
| [Edge authentication](https://supabase.com/docs/guides/functions/auth) | Current JWT/handler modes; custom device verification cannot be omitted | 2026-09-05 |
| [Migrations](https://supabase.com/docs/guides/local-development/database-migrations) | Version-controlled schema workflow | 2026-09-05 |
| [Database testing](https://supabase.com/docs/guides/database/testing) | Database/pgTAP testing | 2026-09-05 |

## Firebase

| Official source | Constraint reviewed | Verified |
| --- | --- | --- |
| [Android setup](https://firebase.google.com/docs/cloud-messaging/android/get-started) | Still shows registration token and refresh handling | 2026-09-05 |
| [Android receiving](https://firebase.google.com/docs/cloud-messaging/android/receive-messages) | Data/notification background distinction and missed-message sync | 2026-09-05 |
| [Android priority](https://firebase.google.com/docs/cloud-messaging/android-message-priority) | High priority expects visible notification; potential deprioritization | 2026-09-05 |
| [Registration management](https://firebase.google.com/docs/cloud-messaging/manage-tokens) | Current FID-oriented guidance; update/prune registrations | 2026-09-05 |
| [HTTP v1 Message](https://firebase.google.com/docs/reference/fcm/rest/v1/projects.messages) | Current token deprecation/fid target; verified adjacent to rollout caveat | 2026-09-05 |
| [Message lifespan](https://firebase.google.com/docs/cloud-messaging/customize-messages/setting-message-lifespan) | TTL/collapse/non-guaranteed delivery | 2026-09-05 |
| [Firebase installations](https://firebase.google.com/docs/projects/manage-installations) | Installation IDs/auth tokens differ; deletion timing | 2026-09-05 |
| [Android Installations API](https://firebase.google.com/docs/reference/android/com/google/firebase/installations/FirebaseInstallations) | Documented installation ID retrieval; not KidRemote authentication | 2026-09-05 |

## Amazon / Fire OS

| Official source | Constraint reviewed | Verified |
| --- | --- | --- |
| [Fire OS overview](https://developer.amazon.com/docs/fire-tv/fire-os-overview.html) | Android-derived OS, Google service replacements; page updated 2026-05-20 | 2026-09-05 |
| [A3L Messaging](https://www.developer.amazon.com/docs/a3l-messaging/understanding-a3l-messaging.html) | FCM on Android, ADM on Fire; page updated 2025-09-19 | 2026-09-05 |
| [A3L setup / porting](https://developer.amazon.com/docs/a3l-messaging/get-started.html) | Separate provider credentials and integration path | 2026-09-05 |
| [ADM overview](https://developer.amazon.com/docs/adm/overview.html) | Amazon device messaging boundary | 2026-09-05 |

## Apple

| Official source | Constraint reviewed | Verified |
| --- | --- | --- |
| [Screen Time frameworks](https://developer.apple.com/documentation/screentimeapidocumentation) | Framework division; official indexed content used where JS shell returned | 2026-09-05 |
| [FamilyControls](https://developer.apple.com/documentation/familycontrols) | Child Family Sharing authorization; official DocC JSON also retrieved | 2026-09-05 |
| [ManagedSettings](https://developer.apple.com/documentation/managedsettings) | Native privacy-preserving settings; official DocC JSON also retrieved | 2026-09-05 |
| [DeviceActivity](https://developer.apple.com/documentation/deviceactivity) | Native extension monitoring; official DocC JSON also retrieved | 2026-09-05 |
| [Family authorization](https://developer.apple.com/documentation/familycontrols/authorizationcenter/requestauthorization%28for%3A%29) | Child vs individual authorization differs | 2026-09-05 |
| [Family Controls entitlement request](https://developer.apple.com/documentation/FamilyControls/requesting-the-family-controls-entitlement) | Account holder request and extensions; external launch dependency | 2026-09-05 |
| [Screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/) | Exact current device-class dimensions and no alpha | 2026-09-05 |
| [App Review guidelines](https://developer.apple.com/app-store/review/guidelines/) | 2.3 accurate metadata/actual app screenshots | 2026-09-05 |

## Microsoft / Windows

| Official source | Constraint reviewed | Verified |
| --- | --- | --- |
| [Assigned Access](https://learn.microsoft.com/en-us/windows/configuration/assigned-access/) | Managed kiosk/restricted-user capabilities, not fullscreen tamper resistance | 2026-09-05 |

## GitHub

| Official source | Constraint reviewed | Verified |
| --- | --- | --- |
| [Projects](https://docs.github.com/en/issues/planning-and-tracking-with-projects/learning-about-projects/about-projects) | Table/board/roadmap and fields | 2026-09-05 |
| [Iterations](https://docs.github.com/en/issues/planning-and-tracking-with-projects/understanding-fields/about-iteration-fields) | Weekly iteration configuration and @current | 2026-09-05 |
| [Project API](https://docs.github.com/en/issues/planning-and-tracking-with-projects/automating-your-project/using-the-api-to-manage-projects) | Project scopes and automation API | 2026-09-05 |
| [Issue Forms syntax](https://docs.github.com/en/communities/using-templates-to-encourage-useful-issues-and-pull-requests/syntax-for-issue-forms) | Required form body/field syntax | 2026-09-05 |
| [Labels](https://docs.github.com/en/issues/using-labels-and-milestones-to-track-work/managing-labels) | Repository label management | 2026-09-05 |
| [Milestones](https://docs.github.com/en/issues/using-labels-and-milestones-to-track-work/creating-and-editing-milestones-for-issues-and-pull-requests) | Milestone configuration | 2026-09-05 |
| [Built-in automation](https://docs.github.com/en/issues/planning-and-tracking-with-projects/automating-your-project/using-the-built-in-automations) | Project status automation | 2026-09-05 |
| [Roadmap configuration](https://docs.github.com/en/issues/planning-and-tracking-with-projects/customizing-views-in-your-project/customizing-the-roadmap-layout) | Date/iteration-based roadmap | 2026-09-05 |
| [Actions security](https://docs.github.com/en/actions/reference/security/secure-use) | Minimum permissions and pinned actions | 2026-09-05 |
| [checkout release](https://github.com/actions/checkout/releases/tag/v7.0.1) | Verified stable action exception; release 2026-07-20 | 2026-09-05 |
| [checkout README](https://github.com/actions/checkout/blob/v7.0.1/README.md) | Runtime/security and checkout options | 2026-09-05 |
| [gh project CLI](https://cli.github.com/manual/gh_project) | CLI commands also checked using installed gh help | 2026-09-05 |
| [Issues REST create](https://docs.github.com/en/rest/issues/issues#create-an-issue) | Issue creation tool/CLI contract | 2026-09-05 |

## Flutter alternative

| Official source | Constraint reviewed | Verified |
| --- | --- | --- |
| [Native platform channels](https://docs.flutter.dev/platform-integration/platform-channels) | Cross-platform UI does not remove native platform integrations | 2026-09-05 |
