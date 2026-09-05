# ADR-0007 — Future platform boundaries

Status: Future research only. No Fire, Apple or Windows implementation.

- **Goal:** Preserve product concepts without claiming identical platform enforcement.
- **Context:** Android MVP first; Fire OS, Apple feasibility and Windows V2 later.
- **Constraints:** Native enforcement per platform, minimal data, no extra implementation in MVP.
- **Done when:** Shared contract has no Google/Android-specific policy fields and future blockers are explicit.

## Alternatives evaluated

Google APIs embedded in domain logic: fastest initial coupling, costly Fire port; rejected.
Cross-platform enforcement facade pretending identical APIs: hides unsupported behaviour; rejected.
Small native adapters around platform-neutral policy/receipt concepts: recommended.
A3L across all Android builds now: potentially one SDK but adds a dependency before Fire feasibility; defer.

## Fire OS decision and reasons

Use a small PushTransport boundary on client and provider adapter on server.
Current Amazon docs identify Fire OS as Android-derived and list A3L Messaging or ADM as FCM replacements.
A3L delegates to FCM on Google Android and ADM on Fire OS; it does not provide Google services on Fire devices.
[Fire OS overview](https://developer.amazon.com/docs/fire-tv/fire-os-overview.html),
[A3L](https://www.developer.amazon.com/docs/a3l-messaging/understanding-a3l-messaging.html),
[ADM](https://developer.amazon.com/docs/adm/overview.html).
Do not assume Fire model/API mapping from old Fire OS 8-only guidance; current overview includes newer OS families.
Tablet/model/Kids-profile permission behaviour: **UNSPECIFIED**. Porting test must verify actual devices, Amazon Kids profiles,
Usage Access, Accessibility, service lifecycle and lack of Play Services. No Google QR scanning dependency in core.
[App porting/A3L setup](https://developer.amazon.com/docs/a3l-messaging/get-started.html).

## Apple decision and reasons

Future native agent uses FamilyControls authorization, ManagedSettings restrictions/shields and DeviceActivity monitored events.
Child authorization requires parent/guardian in the same Family Sharing group; individual authorization has different protections.
KidRemote backend pairing does not replace Apple's authorization ceremony.
[FamilyControls](https://developer.apple.com/documentation/familycontrols),
[ManagedSettings](https://developer.apple.com/documentation/managedsettings),
[DeviceActivity](https://developer.apple.com/documentation/deviceactivity),
[framework relationships](https://developer.apple.com/documentation/screentimeapidocumentation).

Family Controls distribution entitlement requires Apple approval requested by the account holder, including applicable Screen Time extensions.
Treat this as an external launch dependency before committing to Apple delivery dates.
[Entitlement request](https://developer.apple.com/documentation/FamilyControls/requesting-the-family-controls-entitlement).

Exact arbitrary remote whole-device Lock/Unlock, total interactive/unlocked measurement parity,
remote extra-time application while suspended, reboot behaviour, cross-device selection tokens and background delivery SLA:
**UNSPECIFIED** / RESEARCH REQUIRED.
Do not upload Apple's opaque application/domain selections or introduce browsing history.
Native Apple concepts must map to policy/bonus/acknowledgement with explicit capabilities and unsupported results.

## Windows V2 decision and reasons

Future enforcement mechanism and privilege model: **UNSPECIFIED**.
Investigate Windows service + per-user session boundaries, installation/admin consent, supported editions,
Assigned Access/AppLocker/app-control suitability, session/lock APIs, reboot and signed updates.
Assigned Access is an OS-managed kiosk/restricted-user facility with edition/configuration requirements; a full-screen app is not equivalent.
[Microsoft Assigned Access](https://learn.microsoft.com/en-us/windows/configuration/assigned-access/).
Do not assume kiosk controls fit a normal consumer Windows family PC.
Future research entry: goal choose an enforceable user/privilege boundary; done when bypass/recovery evidence exists on supported Windows editions.

## Security/privacy and operational implications

Each platform has separate secure storage, permissions, signing and store review.
Version/capability negotiation must return unsupported explicitly; never pretend an Android command has identical effect elsewhere.
Reuse protocol fixtures and semantic tests, not Android service logic in Apple/Windows.
Additional provider secrets remain backend only; Fire build excludes Google-only runtime dependencies.

## Risks and tests that invalidate the decision

Fire: no usable permission path or service durability in target Kids profile.
Apple: entitlement denied or allowed APIs cannot implement the approved meaning of total screen time/remote controls.
Windows: useful restrictions require unacceptable admin/managed setup or block safe recovery.
Invalidate “shared concepts” if commands require platform-specific meaning changes; version the contract and obtain owner approval.
