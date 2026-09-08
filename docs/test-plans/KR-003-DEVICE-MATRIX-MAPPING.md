# KR-003 exact-device matrix mapping

- **Goal:** Map sanitized metadata from a newly authorized Android device to existing KR-003 physical requirements without generalizing between configurations.
- **Context:** Mi 8/API 29 evidence exists. The authorized Samsung SM-X400 onboarding record establishes Android 16/API 36/build `BP4A.251205.006`, transport PASS and calibration INVALID; it does not establish enforcement.
- **Constraints:** Use only the [generic onboarding](KR-003-DEVICE-ONBOARDING.md) record; no model/API inference from appearance, marketing name or owner expectation; no cross-device evidence transfer.
- **Done when:** Every applicable required row is named from exact read values, non-applicable rows stay open, and the evidence key fixes build, power and permission state.

## Mapping function

Given one validated `device.json` and its SHA-256:

1. Require all six identity/version fields: manufacturer, model, Android version, API level, security patch and build ID. Any `UNSPECIFIED` value makes the mapping INVALID.
2. Map the API row by exact `ApiLevel` only:
   - `28` → oldest proposed API 28 row;
   - `35` → Android 15/API 35 row only when the read Android version is also 15;
   - `36` → Android 16/API 36 row only when the read Android version is also 16;
   - API `37` / Android `17` → current-platform supplemental evidence while its required-gate status remains **UNSPECIFIED**;
   - any other API → supplemental evidence, satisfying none of the three required API rows.
3. Map the OEM row from the exact normalized manufacturer. `samsung` may satisfy the proposed Samsung variant row; it never satisfies the current-Google-reference or another-OEM row. The owner-supplied expectation is not enough before the read value.
4. A single device may cover one exact API row and one exact OEM-variant row at the same time. It does not cover another model, Android/API pair, build/security patch, user, battery policy or permission state.
5. Keep battery flags and required permission state with the evidence key. An OEM battery value left `UNSPECIFIED` permits transport testing but must be resolved before lifecycle/battery qualification.
6. Recompute the mapping whenever Android build, security patch, relevant battery configuration or required permission state changes. Preserve the old result as its own configuration; do not rewrite it.

## Value table

| Read value | Matrix value | What remains open |
| --- | --- | --- |
| API 28 | API 28 configuration | API 35, API 36 and every untested OEM variant |
| Android 15 + API 35 | Android 15/API 35 configuration | API 28, API 36 and every untested OEM variant |
| Android 16 + API 36 | Android 16/API 36 configuration | API 28, API 35 and every untested OEM variant |
| Android 17 + API 37 | Supplemental current-platform configuration pending owner support-boundary decision | Existing API 28/35/36 and every untested OEM variant |
| Manufacturer `samsung` | One exact Samsung OEM variant | Google reference, other Samsung model/build/configuration and other OEMs |
| SM-X400 / Android 16 / API 36 / `BP4A.251205.006` | Metadata and transport for the Android 16/API 36 plus exact Samsung-variant keys; enforcement remains Not run | Every enforcement/latency/safety/lifecycle result, API 28/35, Google reference and other OEM/model/build rows |
| Mi 8 / Xiaomi / API 29 | Preserved Mi 8 supplemental/OEM evidence only | All required 28/35/36 and Samsung/Google/other-OEM rows |
| Any mismatch/unknown | INVALID mapping | All rows remain open until corrected metadata is read |

Transport PASS, oracle-calibration PASS and 100-cycle qualification are separate values attached to the same evidence key. None substitutes for
the others. Human safety/usability rows and external Google Play evidence remain separately classified in [KR-003 remaining work](KR-003-REMAINING.md).
