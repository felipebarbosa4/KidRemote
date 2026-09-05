# ADR-0001 — Parent framework and native child boundary

Status: Proposed; parent framework **UNSPECIFIED**, owner approval OD-08 required.

- **Goal:** Minimize Android MVP implementation and operational complexity.
- **Context:** Only Android parent/child ship first; future Apple parent date/team skills are **UNSPECIFIED**.
- **Constraints:** No production bootstrap or unverified version pins now.
- **Done when:** KR-002 records owner choice and verifies stable tooling before app scaffolding.

## Alternatives evaluated

| Option | Benefits | Costs / limitations |
| --- | --- | --- |
| Kotlin + Jetpack Compose parent | Same language/toolchain as child, direct Android lifecycle and accessibility, native Material UI | Future iOS parent UI likely separately implemented |
| Flutter parent, Kotlin child | Potential shared Android/iOS parent UI and domain presentation | Dart plus Kotlin, plugin lifecycle/security audit, future native integration still needed |
| Cross-platform child | Some UI reuse | Enforcement still platform-specific; hides the highest-risk APIs behind bridges without resolving feasibility |

Android recommends Compose for modern UI and offers Material 3 support.
Flutter supports platform channels for native integration, which does not itself prove Screen Time capability or entitlement availability.
[Compose Material 3](https://developer.android.com/develop/ui/compose/designsystems/material3),
[Flutter platform channels](https://docs.flutter.dev/platform-integration/platform-channels). Verified 2026-09-05.

## Decision and reasons

Recommend native Kotlin/Compose parent and Kotlin child, sharing wire fixtures/design tokens and small pure Kotlin domain concepts where useful.
Keep separate application IDs and binaries. The parent never carries child enforcement privileges.
A language-neutral protocol is the portability boundary; do not claim binary/shared-code portability to Apple.
Flutter becomes preferable if a committed near-term iOS parent schedule and team skill evidence outweigh two-toolchain cost.

## Security/privacy implications

Audit parent session storage and deep links in either framework. Native does not eliminate security bugs.
QR scanning remains child-only user-initiated camera use, with no recorded images.
No Google SDK dependency enters the shared time reducer.

## Operational implications

One Android build toolchain initially; independent parent/child releases and compatibility tests.
Exact versions/package IDs/minimum API are **UNSPECIFIED**; verify at bootstrap and record in TOOLING.

## Risks and invalidation tests

Build a small parent navigation/auth-state shell after approval; measure warm list render and TalkBack/font scaling.
Reconsider if native effort substantially exceeds an equivalent Flutter spike with verified native/auth integrations,
or owner commits to simultaneous Android/iOS parent launch.
Do not run comparative production implementations merely to settle preference.
