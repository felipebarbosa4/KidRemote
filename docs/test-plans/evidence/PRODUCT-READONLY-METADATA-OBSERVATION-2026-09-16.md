# OD-51 current read-only metadata observation preparation

[Task contract](../../exec-plans/PRODUCT-READONLY-METADATA-OBSERVATION.md).

## Evidence boundary

Historical attempt `e888975a-207a-473f-a442-2a2895f02347` remains independently
`INVALID_HOST_PREFLIGHT / INVALID_PARTIAL_STATE_REVIEW_REQUIRED`, with
`noUnknownFiles=false` and `metadataKnown=UNSPECIFIED`. Historical attempt
`d9157ae6-a6ff-4849-919f-c8f13fe08f7e` remains `INVALID:PAIRING_TIMEOUT / cleanup
UNVERIFIED`. This preparation does not change, reinterpret or backfill either attempt.

The owner authorized one independent current read-only observation on the existing
Samsung lab tablet. Codex did not execute ADB, an emulator or a physical device while
preparing it. `PRODUCT_PHYSICAL_ORACLE` remains **BLOCKED** before and after freezing
the diagnostic probe.

## Probe design

The dedicated entrypoint imports only its metadata module and the shared
`ProductRuntimeCatalog.psm1`. It contains no product runner, backend, enrollment,
policy/control, input, screenshot or journal module. Before private metadata it:

1. requires exactly one authorized non-emulator target and keeps its serial in memory;
2. verifies Android user 0 and exact Samsung manufacturer/model/Android/API/build/
   security-patch values;
3. verifies the installed LAB child hash, signer and version using device SHA-256 plus
   a host-temporary APK pull and frozen SDK `apksigner`;
4. verifies the ordinary fixture APK SHA-256;
5. reads only `reverse --list` and requires no mapping for TCP 47366;
6. creates no mutation journal and imports no historical evidence path.

Only then may the fixed `run-as dev.kidremote.child.unassigned.debug sh` program run.
The script is generated from `Get-ReviewStatePaths($true)`. It uses metadata operations
only (`find`, regular-file/type checks and `stat` size); it never reads file contents.
It enumerates only `no_backup/`, `files/`, `databases/` and `shared_prefs/`, rejects
symlinks/nonregular entries, traversal, unsafe characters and paths over 200
characters, and stops before emitting a 65th unexpected entry.

Known paths become repository logical kinds. A valid parse with extra regular files
sets `metadataStatus=METADATA_ONLY`, `metadataFinding=UNKNOWN_DURABLE_FILES_PRESENT`
and returns only authorized directory, relative structural name and byte size. No
unexpected entry is returned for a failed metadata read. Raw stderr, serial, APK path,
file content, database rows, XML/preferences, credentials and timestamps are excluded.

Typed metadata failures are `RUN_AS_FAILED`, `PRIVATE_DIRECTORY_UNREADABLE`,
`SYMLINK_OR_NONREGULAR_ENTRY`, `METADATA_OUTPUT_SCHEMA_INVALID` and
`METADATA_OUTPUT_BOUNDS`. A successful valid parse is `METADATA_ONLY`; unexpected
files are distinguished by `metadataFinding` without weakening that parse result.

## Runtime command boundary

The runtime allowlist contains only: `devices`; exact current-user and fixed `getprop`
reads; `pm path`/`dumpsys package` for the child or fixture; SHA-256 of a strictly
validated installed base APK; exact `reverse --list`; one child base-APK pull to the
unique host temporary destination; and the exact fixed metadata-only `run-as` script.

Tests reject install, uninstall, `pm clear`, reverse creation/removal, `am start`,
`settings put`, `appops set`, input, rm/mv/cp/touch/mkdir, sqlite3, cat, content queries,
capture and arbitrary `run-as` input. There is no HTTP client or LOCK/UNLOCK path.
The pulled APK is deleted from host temporary storage after signer verification.

## Validation before physical execution

Preparation-time results and final CI/bundle identities are recorded below after the
committed source passes all gates. No result in this section is physical evidence.

- PowerShell 5.1 parser/allowlist fixtures: **95 checks PASS**; device not invoked.
- Windows-native fake-ADB entrypoint: **65 checks PASS** under PowerShell 5.1; device
  not invoked. Empty, unexpected-file, redacted run-as-failure and pre-existing-reverse
  outputs were exercised; the reverse refusal never entered private metadata.
- PowerShell 7 parser/allowlist fixtures: **95 checks PASS**; device not invoked.
- Windows-native fake-ADB entrypoint: **65 checks PASS** under PowerShell 7; fake ADB
  only and device not invoked.
- Fixed shell program: **4 tests PASS** for empty/known, one/multiple unexpected,
  symlink/nonregular/unreadable/bounds and unsafe-name behavior; no private content emitted.
- Node freezer/static capability tests: **2/2 PASS**.
- Existing ProductRuntime/update-review regression: **84 checks PASS**.
- Existing resume/review/prerequisite regressions: **99 + 97 + 72 checks PASS**.
- Isolated KR-003 Gradle build/test/lint: **BUILD SUCCESSFUL, 274 tasks**. The audit
  passed **24/24 JVM tests**, both merged-manifest checks and release DEX isolation.
- Repository validation, patch whitespace, QR tests, real SQL/RLS/Auth/backend suites,
  OD-51 persistent synthetic lease and security/privacy gates passed in required CI.

The first preparation run, CI 35111613199 on source `0e422de`, is preserved as
**cancelled** after both new PowerShell tests printed PASS but the native harness left
the expected negative-fixture process exit code in `$LASTEXITCODE`. Commit `bcac318`
normalizes only the successful harness exit after all assertions. Required CI
[35111839403](https://github.com/felipebarbosa4/KidRemote/actions/runs/35111839403)
on exact probe source `bcac31838720a8aee77488ccf4b1ca9ad4b7929e` completed **6/6
jobs SUCCESS**. The Windows job independently ran the 95 parser/allowlist plus 65
native fake-ADB checks under both PowerShell 5.1 and PowerShell 7.

## Immutable probe handoff

The host-only freezer ran only after the exact source above was clean, pushed and had
passing required CI. It invoked no ADB, emulator, physical device or backend. It froze
489 inventoried files at:

`%LOCALAPPDATA%\KidRemote\read-only-metadata-probes\bcac31838720a8aee77488ccf4b1ca9ad4b7929e`

- probe source: `bcac31838720a8aee77488ccf4b1ca9ad4b7929e`;
- required CI: `35111839403`;
- `bundle.json` SHA-256:
  `0b163526cbab5b19aee2ca08434a5889753d77e3996d7bef1833165dc6fccba1`;
- `Read-CurrentMetadata.ps1` SHA-256:
  `10482554105723f5f9038cecdc4e7cd702279e1bb8734f6d465114f2d5826029`;
- physical execution: **NOT_RUN**.

The bundle inventory contains no symlink or incomplete marker. Independent SHA-256
recalculation matched both hashes. The single owner command is:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:LOCALAPPDATA\KidRemote\read-only-metadata-probes\bcac31838720a8aee77488ccf4b1ca9ad4b7929e\Read-CurrentMetadata.ps1" -Adb "C:\platform-tools\adb.exe" -ExpectedManifestHash "0b163526cbab5b19aee2ca08434a5889753d77e3996d7bef1833165dc6fccba1"
```

The owner must return the one sanitized JSON object printed by this command. It is
independent current evidence; it is not a product-slice run.

## Gate

`READ_ONLY_METADATA_PROBE = READY_FOR_ONE_OWNER_RUN`.

`PRODUCT_PHYSICAL_ORACLE = BLOCKED`.

No product-slice bundle was frozen. A successful current observation remains subject
to review and never changes the historical e888975a values.

## Subsequent owner execution

The owner executed this frozen probe once as attempt
`78bf058e-280f-4ee1-9384-a51a75a395e5`. It stopped read-only in the child APK pull
result-validation path with the historical collapsed reason `ADB_READ_FAILED`; no
device/backend mutation or mutation journal occurred, and the host temporary APK was
deleted. Source `bcac31838720a8aee77488ccf4b1ca9ad4b7929e` is retired and must not
be rerun. The immutable result and bounded correction are recorded separately in
[the pull INVALID evidence](PRODUCT-READONLY-METADATA-PULL-INVALID-2026-09-16.md).

Current gate after that execution:
`READ_ONLY_METADATA_PROBE = BLOCKED_PENDING_REPLACEMENT_VALIDATION_AND_FREEZE`.
