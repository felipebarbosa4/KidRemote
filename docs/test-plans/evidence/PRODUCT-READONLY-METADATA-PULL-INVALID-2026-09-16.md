# OD-51 read-only metadata probe pull INVALID and correction

[Task contract](../../exec-plans/PRODUCT-READONLY-METADATA-PULL-FIX.md).

## Immutable physical observation

Owner-operated read-only attempt `78bf058e-280f-4ee1-9384-a51a75a395e5` used frozen
source `bcac31838720a8aee77488ccf4b1ca9ad4b7929e` and manifest SHA-256
`0b163526cbab5b19aee2ca08434a5889753d77e3996d7bef1833165dc6fccba1`.
The durable 1,842-byte JSON is retained outside the repository at the authorized
metadata-observation result location. Its SHA-256 is
`cceff69add0a467aa5429f0f5331e98d75f4a856f56d95e4b2e4caadae9c1cee`.

OBSERVED, without reinterpretation:

- exact Samsung configuration matched and `configurationProvenance=PASS`;
- `reverseAbsent=true`;
- `deviceMutation=false`, `backendMutation=false`, and
  `mutationJournalCreated=false`;
- `packageProvenance=INVALID`, `fixtureProvenance=INVALID`, metadata remained
  `UNSPECIFIED`, and `probeStatus=INVALID`;
- `failureReason=ADB_READ_FAILED` and `hostTemporaryApk=HOST_TEMP_DELETED`.

The old control flow created the host temporary directory, invoked the exact child
base-APK pull and immediately passed its process result to the generic read validator.
Only that validator could throw `ADB_READ_FAILED` before local hash/signer checks and
before child/fixture serialization. The exact observed failure stage is therefore
`CHILD_APK_PULL`. The old process result retained no exit code category, stderr
category or bounds category in durable evidence. The lower-level ADB reason is
**UNKNOWN** and is not backfilled.

The attempt and frozen source are retired for physical reuse. This correction never
changes their bytes or classification.

## Verified seam and bounded correction

The official ADB sync client reports pull progress and the final transfer summary as
informational lines through `LinePrinter`; `LinePrinter` writes those lines to stderr,
including its Windows implementation. References reviewed at AOSP commit
`1cf2f017d312f73b3dc53bda85ef2610e35a80e9`:

- [`file_sync_client.cpp`](https://android.googlesource.com/platform/packages/modules/adb/+/1cf2f017d312f73b3dc53bda85ef2610e35a80e9/client/file_sync_client.cpp#202)
- [`line_printer.cpp`](https://android.googlesource.com/platform/packages/modules/adb/+/1cf2f017d312f73b3dc53bda85ef2610e35a80e9/client/line_printer.cpp#64)

The replacement uses a dedicated pull-result validator. Only the fixed allowlisted
child base-APK pull may accept bounded nonempty stderr with exit code zero. It never
parses, returns or persists that text. Successful provenance still requires the exact
pre-authorized destination, a present regular non-reparse file, size 1..200 MiB,
SHA-256 equality with the already read device base APK and the exact approved signer.
Every ordinary ADB read continues to reject any stderr.

Sanitized `failureStage` distinguishes bundle/device/configuration/package/fixture/
reverse reads, child pull, local APK validation, signer validation, metadata run-as and
metadata parsing. ADB failures distinguish `ADB_EXIT_NONZERO`, `ADB_STDERR_PRESENT`,
`ADB_OUTPUT_TOO_LARGE`, `ADB_TIMEOUT` and `ADB_PROCESS_FAILED` without raw stderr.

## Validation and replacement handoff

Preparation-time local results, with no ADB, emulator or physical device:

- Windows PowerShell 5.1 parser/allowlist: **117 checks PASS**;
- Windows-native fake-ADB entrypoint under PowerShell 5.1: **194 checks PASS**,
  including both successful pull stderr variants and every typed pull/local/signer
  failure listed above;
- PowerShell 7 parser/allowlist: **117 checks PASS**;
- Windows-native fake-ADB entrypoint under PowerShell 7: **194 checks PASS**;
- fixed metadata-only shell fixtures: **4 PASS**;
- static freezer/no-mutation capability: **2/2 PASS**;
- ProductRuntime/update-review: **84 checks PASS**;
- native Windows ACL/DPAPI regression: **49 checks PASS**;
- isolated Gradle test/build/lint: **BUILD SUCCESSFUL, 274 tasks**; audit:
  **24/24 JVM**, all debug/release manifests and release DEX isolation PASS;
- repository validation and patch whitespace: **PASS**.

Required CI
[35137531678](https://github.com/felipebarbosa4/KidRemote/actions/runs/35137531678)
on exact probe source `8ebcc89e0b483af1f5d3cf3a081fca640da37e10` completed
**6/6 jobs SUCCESS**. It also passed real SQL/RLS/Auth/backend suites, the persistent
synthetic lease, QR, complete Android build/lint and security/privacy isolation gates.
No physical action is inferred from these device-free tests.

The host-only freezer then created 489 inventoried files at:

`%LOCALAPPDATA%\KidRemote\read-only-metadata-probes\8ebcc89e0b483af1f5d3cf3a081fca640da37e10`

- probe source: `8ebcc89e0b483af1f5d3cf3a081fca640da37e10`;
- required CI: `35137531678`;
- `bundle.json` SHA-256:
  `e4d8ab75d9b6c44ca08d3c5cb3958e3992afa4a254518f4fdebb450ba0cc29ee`;
- `Read-CurrentMetadata.ps1` SHA-256:
  `4faf78c521837bf28ad4ed03a3d08c4e5dbbeb64a3bc5ed6ec5c2ef88f042930`;
- physical execution: **NOT_RUN**.

Independent recalculation matched both hashes; the inventory contains no symlink or
incomplete marker. The frozen manifest keeps device/backend/private-state/history
mutation and content/capture capabilities false. The single replacement command is:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:LOCALAPPDATA\KidRemote\read-only-metadata-probes\8ebcc89e0b483af1f5d3cf3a081fca640da37e10\Read-CurrentMetadata.ps1" -Adb "C:\platform-tools\adb.exe" -ExpectedManifestHash "e4d8ab75d9b6c44ca08d3c5cb3958e3992afa4a254518f4fdebb450ba0cc29ee"
```

After validation and freeze, the physical attempt file still has its original
SHA-256, 1,842-byte size and timestamp. No product-slice bundle was frozen.

## Gates

`READ_ONLY_METADATA_PROBE = READY_FOR_ONE_OWNER_RUN`.

`PRODUCT_PHYSICAL_ORACLE = BLOCKED`.
