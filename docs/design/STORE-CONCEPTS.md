# Three initial store concepts — MOCKUPS

- **Goal:** Explore a truthful, calm store presentation of the requested product.
- **Context:** No functioning Android or Apple app exists; images were generated with the built-in image tool in this architecture pass.
- **Constraints:** Never upload these as actual screenshots. Final brand/copy approval **UNSPECIFIED**.
- **Done when:** Three concepts, exact prompts, files, intended dimensions and replacement rules are available.

## Concepts and files

| Concept | Headline | Visual and qualification |
| --- | --- | --- |
| [1 — device list](assets/store-01-devices.png) | “All their screens. One place.” | Three synthetic device cards, recent/manual-locked/offline; subtitle “Paired Android devices” limits the platform claim |
| [2 — add time](assets/store-02-add-time.png) | “Add time in one tap.” | Remaining display, +10, +30 and Lock Now; no implication of instant delivery to offline device |
| [3 — no surveillance](assets/store-03-no-surveillance.png) | “Simple screen time. No surveillance.” | Child expired screen; no location tracking, browsing history or message monitoring; minimal technical state still exists |

Each image has visible “MOCKUP · ANDROID CONCEPT”.
Actual generated files: **941 × 1672 px**, RGB PNG, no alpha; approximately 9:16.
Intended future Google Play layout: **1080 × 1920 px** captured/composed from actual app UI.
Built-in output did not use the requested exact canvas; no claim that these reach the 1080 px recommendation tier.
Use written design tokens as source of truth; generated ornament/menu geometry is not a feature spec.

## Verified store rules (2026-09-05)

Google Play: minimum two screenshots to publish a listing; JPEG or 24-bit PNG without alpha;
dimensions 320–3840 px and longest dimension no more than twice shortest.
Recommendation-format eligibility for apps calls for **at least four** 1080 px screenshots at the specified ratios.
Therefore the requested three concepts are not a complete recommendation-eligible launch set.
A fourth real screenshot can later show pairing or permission transparency.
Screenshots should show the actual core experience; generated UI must be replaced/validated.
[Google Play preview assets](https://support.google.com/googleplay/android-developer/answer/9866151?hl=en).

Apple: 1–10 JPEG/JPG/PNG screenshots, no alpha; use exact device-class sizes.
Current 6.9-inch options include 1260×2736, 1290×2796 and 1320×2868 portrait.
Future recommendation: actual Apple-app 1320×2868 capture when that device class remains accepted; not a resized Android concept.
Screenshots/metadata must match actual functionality. No Apple launch or accepted entitlement is implied.
[Apple screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/),
[App Review 2.3](https://developer.apple.com/app-store/review/guidelines/).

## Pre-release replacement and copy review

Capture real synthetic accounts on supported app versions, verify every button/state and privacy statement,
export at current store dimensions, inspect readability on store surfaces, complete platform-specific listing review.
“No surveillance” refers to excluded content/location/message monitoring; keep privacy disclosure of totals, identity, push and health.
Do not imply “all platforms,” zero technical data, tamper-proof control, or five-second delivery guarantees.
Retain these labelled concepts for design history; final approved screenshots live in a separate release directory.
Prompt set: [IMAGE-PROMPTS](IMAGE-PROMPTS.md). Built-in image generation was used, not a CLI/API fallback.
