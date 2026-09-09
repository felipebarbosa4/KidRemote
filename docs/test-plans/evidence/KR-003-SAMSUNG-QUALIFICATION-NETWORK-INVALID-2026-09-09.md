# KR-003 Samsung qualification network-preflight INVALID — 2026-09-09

- **Goal:** Preserve and classify the first physical configuration-bound qualification attempt without turning a host/ADB preflight stop into enforcement evidence.
- **Context:** The owner invoked runner-v8 on the already calibrated Samsung configuration. Run `run-20260909-003140-758ee7f6` stopped `INVALID:ADB_REJECTED` during reversible offline setup.
- **Constraints:** One independent INVALID run; no pooling, replacement, raw ADB output, serial/account/content/package-history/screenshot capture, enforcement PASS/FAIL inference, qualification row, rerun or KR-004 work.
- **Done when:** Artifact hashes, operation boundary, network mutations/restoration, candidate/cycle/checkpoint state and retained unknowns are explicit and strict ingestion returns zero cycles.

## Verdict

Strict ingestion of `/mnt/c/platform-tools/kr003-qualification/run-20260909-003140-758ee7f6` returns source `33c2b36564d4d164d1992e41a9327a7968e44787`, `INVALID:ADB_REJECTED`, zero active-oracle qualification cycles, zero owner checkpoint sessions, `partial=true`, and `kr003Complete=false`. This is a pre-cycle ADB/network-isolation INVALID, not an enforcement result.

Captured system metadata is `samsung` / `SM-X400` / Android `16` / API `36` / build `BP4A.251205.006` / security patch `2026-07-05`. `Galaxy Tab S10 Lite` and `One UI 8.5` remain owner-provided labels. The manifest binds the previously passed calibration and exact candidate/fixture hashes.

## OBSERVED

| Question | Retained result |
| --- | --- |
| Initial network flags | `wifi_on=1`, `mobile_data=1`, `airplane_mode_on=0` |
| Rejected operation class | Mobile-data isolation branch, after the Wi-Fi disable/readback boundary and after `mobile_data` was journalled as touched |
| Exact command | **UNSPECIFIED** between `shell svc data disable` and the following `shell settings get global mobile_data` readback |
| Exit code / stderr class | **UNSPECIFIED**; runner-v8 discarded both |
| Wi-Fi mutation | Disable and `wifi_on=0` readback completed before the runner entered the mobile-data branch; finalization later observed the original `wifi_on=1` restored |
| Mobile-data mutation | **UNSPECIFIED**; it was journalled before command dispatch, but the retained evidence cannot distinguish command rejection from readback rejection |
| Finalization | Ran. Diagnostic lab CLEAR was `VERIFIED`; the one pre-existing latency sample was preserved |
| Network restoration | Overall `RESTORE_FAILED_OWNER_ACTION_REQUIRED`; Wi-Fi `VERIFIED` at original `1`; mobile-data observed state **UNSPECIFIED**, `RESTORE_OR_READ_FAILED` |
| Candidate state before stop | Permission verifier: Usage `ENABLED`, Accessibility `ENABLED`, heartbeat `FRESH`, health `HEALTHY`, eligibility `ELIGIBLE`; prior candidate state unarmed/unrestricted/unattached |
| ARM / restriction / expiry | No ARM attempt and no evidence of an armed timer, attached restriction, blocked hold, denial oracle or expiry |
| Qualification rows | `attempts.json=[]`; zero calibration rows in this qualification run and zero qualification rows |
| Owner checkpoints | `human-checkpoints.json=[]`; offline confirmation was not reached |

The v8 journal order is material: `network-touched.json` contains `wifi_on` then `mobile_data`. In the hash-bound v8 source, the second entry cannot be written until the Wi-Fi disable returns and its `wifi_on=0` readback succeeds. That source-plus-journal fact establishes the Wi-Fi boundary; it does not establish which of the next two ADB calls rejected.

## INFERRED

The runner defect is established: it treated a parseable global `mobile_data` setting value as evidence that a cellular data transport existed. A global setting is state, not a system-feature capability declaration. Samsung's official support page identifies exact model `SM-X400` as the Wi-Fi variant, which is consistent with the unnecessary branch, but runner-v8 captured no telephony feature bit. Accordingly, physical mobile-radio capability from the retained device artifacts alone remains **UNSPECIFIED**.

Runner-v9 uses Android's declared `android.hardware.wifi` and `android.hardware.telephony.data` features. Android defines the latter as support for Telephony data-service APIs, and the package-manager shell returns `true`/exit 0 for a present feature and `false`/exit 1 for an absent feature. An absent path is now explicitly `NOT_APPLICABLE`; a present path must still be disabled and read back; any unknown/unparseable probe fails closed. [Android PackageManager feature constants](https://developer.android.com/reference/android/content/pm/PackageManager), [Android 16 PackageManager source](https://android.googlesource.com/platform/frameworks/base/+/android16-qpr2-release/core/java/android/content/pm/PackageManager.java), [package-manager shell behavior](https://android.googlesource.com/platform/frameworks/base/+/c7498aedb7145c25b8ca4a812019b368e83e8bde/services/core/java/com/android/server/pm/PackageManagerShellCommand.java), [Samsung SM-X400 support page](https://www.samsung.com/sec/support/model/SM-X400NZAEKOO/).

## Artifact integrity

| File | SHA-256 |
| --- | --- |
| `SUMMARY.md` | `3b0d6ac11a45e3587fa37f30aea841f5aa09c2e0cdbfec2f064b3694ba54c864` |
| `attempts.csv` | `fb9af2a71ab4909af4445ade29ead2c6736c5818eb3564055ec2e6a2e797679c` |
| `attempts.json` | `84b1c14e68260082e3e79edff0a78f4ebf1942cfd6c593246044ec2149cbb87d` |
| `diagnostic-bailout.json` | `a7c591bc8d813ccfd33bbf52099d05d5e29b1040f5aa8d972744d4b006f1247c` |
| `human-checkpoints.json` | `84b1c14e68260082e3e79edff0a78f4ebf1942cfd6c593246044ec2149cbb87d` |
| `manifest.json` | `8f677e084ecf4c6007be7d7d5c30b2ab6f0a2a011aaf834f58b70251db4ad842` |
| `network-original.json` | `3fdb16e8230f3c9a6cf707d4574ec513a822755db6c2c85fb3b92bbb2ce413f3` |
| `network-restoration.json` | `be12ea48f7a692e135b736a8a6bda2e95ea87205193d4ed072ae0b9de5c40a55` |
| `network-touched.json` | `e2d08f52439ee355e5fd135c8356767d03789575dcbe6148c4fb8cedc511af3b` |
| `permission-verification.json` | `f3ad4aa9bf56053e02112769110191c09c599478da78cff863c7d0f15deb2b96` |
| `prior-metrics.json` | `6bbec6c15060ef83bf3a9cd92173e0e51913c077ab126316ec23103e8dfb9a83` |
| `summary.json` | `1851f3f01817c606e7ed5291eab6f1f5a21e1ae74e1b32afb75b577e5ec1d0f2` |
| `telemetry.jsonl` | `59c824defb6a6422ead74fd68ad4811dc7426ef76406e38baf06655772366332` |
| `trace.jsonl` | `84544f5c8c1a637905ff3b67419b0449e1d8e4ac3500fbd69819f379599e2580` |

The two retained APKs match the immutable runner-v8 manifest. The source evidence directory remains unmodified.

## Matrix boundary

No KR-003 matrix row advances. The Samsung transport and calibration prerequisites remain passed on the exact configuration. Formal TIME-04 remains open: this attempt never established offline state, never armed, and produced zero of 100 required qualification rows. Lifecycle, permission-revocation, tamper, safety, policy and production gates remain open.
