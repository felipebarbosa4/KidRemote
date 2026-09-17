# OD-51 exact Samsung IDS runtime classification

[Task contract](../../exec-plans/PRODUCT-SAMSUNG-IDS-CLASSIFICATION.md). The machine-readable independent review is
[`PRODUCT-SAMSUNG-IDS-CLASSIFICATION-2026-09-16.json`](PRODUCT-SAMSUNG-IDS-CLASSIFICATION-2026-09-16.json).

## Preserved observation

Owner probe `88af2a3b-bdfd-4d5b-b814-729facbac4a9` remains a separate,
read-only observation. Its 3,519-byte result still has SHA-256
`f4bff1b17176ce621db4c27c412710b8148f604422d0bc62fca6d968ecb13e14`.
It observed exact configuration/APK/fixture provenance, no reverse, valid metadata,
four known runtime files and one additional regular file:
`shared_prefs/android.app.ActivityThread.IDS.xml` (108 bytes). No content was read and
no device, backend or journal mutation occurred.

## KidRemote and packaged-code audit

At reporting source `da988f17814edcbd229bdc43a4dd6b721f4b0f8f`, a case-insensitive exact search for
`android.app.ActivityThread.IDS.xml`, `ActivityThread.IDS`, `IDSCount` and `IDS_TAG`
found zero references in the repository, child source/resources, merged outputs and
assembled outputs. The approved physical LAB APK has SHA-256
`f6d2a240fae179343d9eb19dfde7684ae6e241b35cebea8ce491205110f7ad56`.
An independent audit found zero matches in all 531 extracted APK entries, ten
disassembled DEX files, AAPT manifest/resources and all extracted strings. A separate
disassembly of the three merged dependency DEX files also found zero matches. No
KidRemote or bundled-dependency mechanism explicitly creates this preference name.

## Bounded corroboration and decision

Public evidence is corroboration, not Samsung documentation. A third-party Samsung
ROM decompilation identifies `android.app.IdsController`, the exact preference name,
`IDSCount`, and the `IDS_TAG` runtime flow that obtains and updates SharedPreferences.
Independent logs from unrelated ReVanced, KOReader and Meshtastic applications show
the same runtime tag retrieving application SharedPreferences and updating an IDS
count. The exact filename has also been reported in private app data on Samsung and
on a Galaxy Tab S9. Sources:
[third-party ROM listing](https://pastebin.com/Zqp38w5M),
[structural filename report](https://stackoverflow.com/questions/78496457/what-is-android-app-activitythread-ids-xml-in-shared-prefs),
[ReVanced log](https://github.com/ReVanced/revanced-manager/issues/2207),
[KOReader log](https://github.com/koreader/koreader/issues/14902), and
[Meshtastic log](https://github.com/meshtastic/Meshtastic-Android/issues/2349).
No official Samsung IDS documentation was found; AOSP absence is not used as proof.

Together, the physical structural observation, complete negative packaged-code audit
and unrelated Samsung-runtime corroboration support the structural classification
`runtime_samsung_ids`: an OEM-managed runtime SharedPreferences artifact whose
presence does not represent KidRemote identity, pairing, accounting or policy state.
This decision says nothing about the unread contents.

Acceptance is limited to the exact case-sensitive path, a regular non-symlink file,
and `samsung` / `SM-X400` / Android 16 / API 36 / `BP4A.251205.006` / patch
`2026-07-05`. Another manufacturer, model, build, patch, filename, entry type or any
second unknown file remains fail-closed. The generic ProductRuntime catalog remains
unchanged.

## Derived current review

Applying that exact overlay makes the five observed files known and derives
`NO_UNKNOWN_FILES=true`. Combined with the preserved LAB package, absent backend
device/saved pointer/identity/pending/accounting facts, the independent current review
is:

- `LAB_PACKAGE_UNPAIRED`;
- `SAFE_RESUME_FROM_ENROLLMENT`;
- `path=ENROLL`.

The frozen runner must revalidate all live prerequisites before any mutation. This
review does not edit or backfill `e888975a-207a-473f-a442-2a2895f02347` or
`d9157ae6-a6ff-4849-919f-c8f13fe08f7e`; both historical verdicts and cleanup states
remain unchanged.
