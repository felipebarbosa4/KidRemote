# Design system — proposed Android MVP

- **Goal:** Make five small flows calm, clear and accessible.
- **Context:** Android parent/child, light mode first, working codename only; generated images are concepts.
- **Constraints:** No surveillance styling, gamification, colour-only status or fake live offline timer.
- **Done when:** KR-010 implements approved tokens and all required states pass usability/accessibility checks.

Use native Material 3 components with consistent semantic roles. Exact Compose/Material library versions: **UNSPECIFIED**.
The Android guidance covers Material 3 colour/type/shape and accessibility defaults, including minimum 48 dp interactive targets.
[Material 3](https://developer.android.com/develop/ui/compose/designsystems/material3),
[accessibility defaults](https://developer.android.com/develop/ui/compose/accessibility/api-defaults).
Verified 2026-09-05.

## Tokens

| Role | Value | Use |
| --- | --- | --- |
| background | #F7F9F7 | Light canvas |
| surface | #FFFFFF | Cards/sheets |
| surface-subtle | #DDEFE7 | Quiet emphasis |
| ink | #172B2A | Primary text |
| ink-secondary | #526460 | Supporting text |
| primary | #176B5B | Add time / Pair |
| on-primary | #FFFFFF | Primary-button text |
| outline | #71817B | Input/focus-adjacent outline; verify contrast by use |
| healthy | #176B5B | Check icon + “Healthy” / recent Online |
| pending | #745300 | Clock icon + “Waiting for device” |
| pending-container | #FFF2CE | Pending callout |
| degraded/error | #9C2F33 | Warning icon + explicit issue |
| error-container | #FFEBE9 | Failure callout |
| offline | #526460 | Cloud-off icon + last seen |
| focus | #2855A6 | Visible focus ring |

Colour roles are proposed design decisions. Measure all rendered pairings; target ≥4.5:1 normal text, ≥3:1 large text and meaningful controls.
Text uses system Roboto/default sans; no remote font dependency.
Display remaining time 48 sp/56 line-height, headline 28/36, screen title 22/28, card title 20/28,
body 16/24, supporting 14/20, button label 16/24 medium. Support user font scaling; no fixed-height text clipping.

Spacing: 4, 8, 12, 16, 24, 32, 48 dp. Screen gutter 24 dp (16 on narrow widths); control gap 12 dp.
Shape: controls 12 dp, cards 16 dp, sheets 24 dp; pill only for compact status badges.
Elevation: flat by default, 1–2 dp cards only if needed; prefer whitespace/outline.
Touch targets ≥48 dp, main buttons ≥56 dp tall.
Use platform Material Symbols or equivalent maintained native icon set; exact dependency **UNSPECIFIED**.
Names: devices/tablet/phone, add, lock/lock_open, hourglass_empty, check_circle, cloud_off, warning, qr_code, refresh, help_outline.
Decorative icons hidden from accessibility; meaningful icons have labels or adjacent text. Focus order follows reading/action order.

## Actions and status

Primary filled: Pair, +10 min, +30 min. Equal visual weight for both increments.
Secondary outlined: Lock Now / Unlock (based on manual state), Retry, help.
Destructive: Remove device/account uses error text with confirmation and recent reauthentication.
Do not make Lock visually destructive; it is reversible policy control.
Daily limit is a small labelled settings row, not another primary control.
No -10/-30 in MVP; dark mode **UNSPECIFIED**, recommend defer.

| State | Text/icon and behaviour |
| --- | --- |
| Loading | Skeleton with accessible loading announcement |
| Empty | “No devices yet” + Pair a device |
| Recently online | Check + Online; explanatory last-seen freshness |
| Offline | Cloud-off + “Last seen …”; last reported time, no ticking |
| Pending | Clock + “Waiting for device”; never optimistically claim applied |
| Manual lock | Lock + “Locked by parent”; Unlock clears only manual flag if approved |
| Expired | Hourglass + “Time is up”; parent sees “Add time to allow use” |
| Both reasons | Parent lock + expired helper; +time does not remove parent lock |
| Permission/degraded | Warning + named missing step; previous time is labelled last reported |
| Update required | Update icon + “Update the child app” |
| Backend error | Error text + Retry; retained cache visibly timestamped |
| Pair expired/error | Replace QR or retry with fresh session; do not reuse consumed token |

## Layout guidance

Device list: MY DEVICES, compact account entry, cards with nickname/model, time/lock reason and status, Pair button.
Detail: back/title, large remaining, freshness, +10/+30, Lock/Unlock, daily limit, one status callout.
QR: instruction, non-scroll-obscured QR, expiration, regenerate/cancel; completion distinct from enforcement-ready.
Child: respectful message, minimal status/help, no shaming, animations or surveillance dashboard.
Degraded: explain limitation and steps on child; parent says the child device needs attention, with last-seen.

Five low-fidelity layouts: [wireframes](wireframes.html).
The polished concepts use these broad roles, but the written tokens and approved behaviours are authoritative;
generated gradients, extra menu decoration or exact geometry are not implementation requirements.
