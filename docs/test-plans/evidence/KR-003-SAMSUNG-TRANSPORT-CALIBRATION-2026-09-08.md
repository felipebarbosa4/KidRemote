# KR-003 Samsung transport PASS and calibration INVALID evidence — 2026-09-08

- **Goal:** Preserve and classify the owner-provided Samsung transport and oracle-calibration evidence without promoting an invalid calibration into enforcement evidence.
- **Context:** The owner ran the superseding generic bundles from source `5a46f75e3dad68ccbf520bce327a6d1f1c03c77c` on one authorized Samsung Galaxy Tab S10 Lite, model SM-X400, One UI 8.5.
- **Constraints:** Direct `/mnt/c` ingestion only; no serial, account, screenshot, content, package-history or raw AppOps/settings/dumpsys retention; no permission mutation, rerun, 100 samples, cross-device transfer or KR-004 work.
- **Done when:** Exact sanitized metadata, hashes, typed results, failed sub-check, evidence limits and matrix mapping are recorded, and all three calibration attempts remain INVALID with zero calibration/qualification samples.

## Exact configuration and transport

Mounted directory: `C:\platform-tools\kr003-device-preflight\device-20260908-092640-d3b5053b`.

| Field | Captured value |
| --- | --- |
| Manufacturer / model | `samsung` / `SM-X400` |
| Owner-observed product / UI | Galaxy Tab S10 Lite / One UI 8.5 |
| Android / API | `16` / `36` |
| Security patch / build ID | `2026-07-05` / `BP4A.251205.006` |
| Battery saver / adaptive battery / app standby | `DISABLED` / `UNSPECIFIED` / `ENABLED` |
| OEM battery management | **UNSPECIFIED** |
| Source / fixture | `5a46f75e3dad68ccbf520bce327a6d1f1c03c77c` / `223219c17a31439b52698e769bdf03ead0998bbbe8bbb5c1b0ff5be3cfaf21dc` |
| Counter | `0 → 1` after exactly one accepted shell tap |
| Result | `PASSED_TRANSPORT_PREFLIGHT:FIXTURE_COUNTER_INCREMENTED_ONCE` |
| Candidate / timer / qualification | candidate not installed by runner; timer unused; `0` qualification samples |

Strict `ingest.mjs device` validation passed. `device.json`, `operations.json` and `summary.json` SHA-256 values are respectively
`e14837ade8cd72b48186ebc1bbdec439bb1ba1be263a8b6204696333db485ae7`,
`8ace5b31c48f7ddf766d2739534b53e4faa2bdc436b582be7c59c5396ca3acaa`, and
`1c71bed50bc7a6540e9ea647162a91891269815f8a031801b41b684f2eeb2d3b`.

This PASS establishes shell-input transport and exactly one fixture-counter increment only on this exact configuration. It says nothing about Mi 8, another device/build, candidate blocking, latency, safety, lifecycle or Play approval.

## Three preserved INVALID attempts

| Mounted directory | UTC interval | Candidate snapshots | Final runner permission state | Result |
| --- | --- | ---: | --- | --- |
| `calibration-20260908-092820-3bf0a2a8` | 13:28:20–13:29:38 | 223 | Usage `GRANTED`; Accessibility `NOT_GRANTED` | `INVALID:REQUIRED_PERMISSION_STATE_NOT_VERIFIED` |
| `calibration-20260908-092947-d30a9d94` | 13:29:47–13:29:54 | 5 | Usage `GRANTED`; Accessibility `NOT_GRANTED` | `INVALID:REQUIRED_PERMISSION_STATE_NOT_VERIFIED` |
| `calibration-20260908-093046-b9c627db` | 13:30:46–13:30:52 | 5 | Usage `GRANTED`; Accessibility `NOT_GRANTED` | `INVALID:REQUIRED_PERMISSION_STATE_NOT_VERIFIED` |

The owner-supplied third suffix was `b9c627ab`; that path does not exist under the mounted evidence root. The exact sibling actually present is
`b9c627db`, with the stated 09:30:46 timestamp and matching typed result. The repository records the mounted name and does not rename or rewrite it.

All three strict `ingest.mjs calibration` validations passed as INVALID. Candidate and fixture APK hashes remained
`5b27c891fe155ee4d26e4da68f8323f178f7116e73d8097ce07199e5800e318b` and
`223219c17a31439b52698e769bdf03ead0998bbbe8bbb5c1b0ff5be3cfaf21dc`.
Each attempt retained zero latency/calibration samples, zero qualification samples, no physical agreement response, and verified cleanup.

| Attempt | `device.json` | `summary.json` | `telemetry.jsonl` | `trace.jsonl` |
| --- | --- | --- | --- | --- |
| `3bf0a2a8` | `82b094542e4d16e01fc64b424762bc1e365bf896dbbb118ed90875a43001d0a5` | `09ea13c46169cddd4c1f5debee09496d59ac21f6f535b5fb093d318cf83de85c` | `091fde5f84dee408e482a871f0c610ff81f1002c1aae31b4e40884e2007ffa84` | `e95343f4360d68cd5f135c7b04aaee71b9bca0ba93695013fbf2b99bd8e18bfd` |
| `d30a9d94` | `82b094542e4d16e01fc64b424762bc1e365bf896dbbb118ed90875a43001d0a5` | `78e10f59515e0622220de85462a222281461e8a21834f8ac79d7400c6c38ba43` | `64952480219d516b5ac90036e3f5cd8b1a0805b3548a546cace360f5ece753fd` | `39327d57072f859a9a4197b678425d46095989b00e44c9395848ec0769837cda` |
| `b9c627db` | `82b094542e4d16e01fc64b424762bc1e365bf896dbbb118ed90875a43001d0a5` | `1dc09b8d56db6894e2f0663c6efb4ccbe4a2b8183ea464c4da739ef6a7d46bbd` | `a86ec763312ca3d2557ed762680f51bce2770ae2b20499b783561be2b372d832` | `87a49c40bc3452f9521a6a89cd1d1ce93c8fc77f307b3d3b6c222152ed481162` |

## Independent sub-check analysis

### OBSERVED

- Usage Access runner verification passed in every final device record. Every corresponding AppOps operation exited zero without a typed security/permission denial.
- Accessibility runner verification alone failed: the old composite reduced the current-user global flag plus enabled-services token check to `NOT_GRANTED`.
- Attempt 1 progressed from candidate `usage=false/accessibility=false/heartbeat=false` through manual setup to `true/true/true`; its final snapshot was eligible and certain. Attempts 2 and 3 reported `usage=true`, `accessibility=true`, `heartbeat=true`, eligible and certain in every retained snapshot.
- Every attempt's typed trace contains `service_connected`; the last heartbeat sample was fresh. Candidate adapter state was `NOT_REQUIRED`, with timer unarmed and restriction false. These fields support the owner-observed `HEALTHY` UI state.
- The old runner used `cmd appops get <package> GET_USAGE_STATS`, `settings get secure enabled_accessibility_services`, and `settings get secure accessibility_enabled`. It did not invoke or parse `dumpsys accessibility`.
- The old Accessibility parser split the enabled-services value on `:` and required byte-for-byte equality with only `dev.kidremote.spike.enforcement/.EnforcementAccessibilityService`. It collapsed missing, malformed, fully qualified or otherwise unequal tokens into `NOT_GRANTED` instead of preserving `UNKNOWN`.
- Attempts 2 and 3 reproduced the same disagreement after setup was already stable. A one-time privilege-enablement race is therefore not supported by the retained evidence.

### INFERRED

- The immediate software defect is the runner's lexical component comparison. Android `ComponentName` defines both short
  `package/.Service` and full `package/package.Service` strings as the same component; a verifier must parse and compare package/class identity.
- A full-form or otherwise lexically different Samsung enabled-service token is the leading explanation for the old false negative. This is an inference, not a captured device fact, because privacy-minimized v1 evidence intentionally retained neither raw secure-setting value nor the failing parse branch.
- Repetition across attempts makes a persistent serialization/parser difference more likely than a post-consent race. It does not prove a Samsung framework modification.

### UNSPECIFIED

- The exact raw Samsung `enabled_accessibility_services` and `accessibility_enabled` strings, and therefore whether the old mismatch was specifically full-form serialization, whitespace, user scope or another representation, are **UNSPECIFIED**.
- A Samsung-specific Android 16 behavior change is **UNSPECIFIED**. Current AOSP still parses colon-delimited values with `ComponentName.unflattenFromString` and persists short component names; no vendor-only behavior is claimed.
- Candidate enforcement, visible blocked behavior, latency, safety, lifecycle/battery survival, OEM setting and 100-cycle qualification remain **UNSPECIFIED / Not run** on this configuration.

Official sources reviewed 2026-09-08: Android 16's
[AccessibilityManagerService](https://android.googlesource.com/platform/frameworks/base/+/refs/heads/android16-release/services/accessibility/java/com/android/server/accessibility/AccessibilityManagerService.java),
[ComponentName string contract](https://android.googlesource.com/platform/frameworks/base/+/refs/heads/android16-release/core/java/android/content/ComponentName.java),
[AppOps guidance](https://android.googlesource.com/platform/frameworks/base/+/refs/heads/android16-release/core/java/android/app/AppOps.md), and
[current-user testing guidance](https://source.android.com/docs/devices/admin/multi-user-testing).

## Correction and matrix boundary

Runner v2 normalizes short/full component names, explicitly reads secure settings for `--user current`, distinguishes `ENABLED / DISABLED / UNKNOWN`, and records only verification-source/parse-result enums plus `FRESH / STALE / UNKNOWN` heartbeat and candidate-health enums. It rechecks before ARM and after the blocked hold. `UNKNOWN` still rejects; a permission/service loss after initial success remains FAIL.

The physical evidence advances the `New-device metadata / transport` row to transport PASS for this exact configuration. Its metadata also maps the configuration to the Android 16/API 36 row and one exact Samsung OEM-variant row. Because calibration is INVALID, it advances neither row to enforcement/latency PASS and supplies no AC-3/TIME-04 sample.
