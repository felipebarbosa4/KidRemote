# KR-007 — one owner-operated invalid-camera check

OD-45 narrow physical extension. **Prepared, physically UNRUN.** Do not repeat the
virtual-scene investigation or historical NOT_PASSED runs. No real enrollment,
backend, endpoint change, enforcement, KR-003 operation or AC closure.

## Retained host startup failure and bounded correction

### Subsequent owner installation attempt — native result boundary

Owner reported `STOP_STAGE=INSTALL_NEW_ONLY`, `FAILED_CHECK=INSTALL_NEW_ONLY`,
`EXCEPTION_CATEGORY=OTHER`, `INSTALLATION_STATUS=ATTEMPTED_UNVERIFIED` on the next
attempt. Later owner read-only query: SM-X400, exit0, package installed user0=NO.
This establishes absence for user0 **at that later query only**, not the historical
installation error or absence of retained records/other-user installations. Camera
remains UNRUN. No automatic retry, uninstall or security-setting change follows.

Before correction, repository/deployed bytes matched `b2641ab`, SHA256
`374dbf525b6ce4a4695142f5b79d61d944d7d9ab8a01d9e1e2e84d688541c275`.
Retained predecessor: `C:\platform-tools\kr007-physical-invalid-camera.original-374dbf52.ps1`.
Do not execute either historical script copy.

**Reproduced host defect:** a locally compiled synthetic executable writing informational
stderr with an exit-zero success path interrupts the exact former `& executable
@Command 2>&1` wrapper under Windows PowerShell 5.1/Stop. This is a tested possible
failure mechanism; the owner's historical stderr, completion and installer error
remain **UNSPECIFIED**. No Samsung Auto Blocker inference is made.

Use the existing repository's redirected .NET Process pattern: stdout/stderr captured
as separate asynchronous memory-only streams, completed exit code inspected independently.
Nonempty informational stderr with exit0 is not failure; nonzero exit never passes.
No raw stream is printed/persisted. Report stage, numeric native exit (or UNKNOWN),
allowlisted installer error code and safe native category. Unsupported installer
codes remain `UNRECOGNIZED_INSTALL_CODE`, not serialized arbitrary strings.
Start failure, timeout, incomplete stream/termination and nonzero exit remain distinct.
Timeout stops only the host process this invocation started; it cannot prove a
device-side install transaction was cancelled, so ATTEMPTED_UNVERIFIED forbids automatic retry.

Recheck filtered all-user/retained package absence immediately before installation;
keep the original earlier check and uppercase -R. Require exit0, explicit standalone
`Success` and a subsequent exact read-only user0 package-list match before marking
VERIFIED/opening the app. A missing success response or missing/unverified package
does not become an installation PASS.

Executed locally on native Windows 5.1: old-wrapper interference reproduced; six
real native-fixture cases passed (stderr/exit0, rejection exit7 with bounded code,
missing success, absent executable, incomplete execution/timeout, Windows argument
quoting); 21 focused orchestration guard cases passed. The fake process is compiled
with existing Windows .NET compiler in a newly allocated temporary directory and
removed after tests. No native boundary is mocked in those six tests. Orchestration
cases are separately labelled fakes, including immediate-absence race and package
verification failure. Host-only real artifact check passes; APK/QR hashes unchanged.
PowerShell 7 runs the same cases in existing CI. No ADB invocation, emulator, physical
installation, APK rebuild or broader test framework is introduced.

Owner output for the first invocation: `STOP_STAGE=LOCAL_ARTIFACTS`,
`RESULT=STOPPED_OR_UNCERTAIN_NO_AUTOMATIC_RETRY`,
`NEW_INSTALL_VERIFIED_THIS_INVOCATION=False`. No target prompt appeared.
This is **host startup failure, installation NOT_ATTEMPTED, camera UNRUN**.
Source HEAD and deployed script were byte-identical to `2944622`, SHA256
`d6d0a614cbc4276b8128456609b7f1a23d2168345c1aab0c5985afe1b7d91d5c`.
The original deployed file is retained alongside it as
`C:\platform-tools\kr007-physical-invalid-camera.original-d6d0a614.ps1`; do not execute that historical copy.

Native Windows PowerShell 5.1 independently observed: `ADB_TRACE=False`,
`ADB_SERVER_SOCKET=False`, `ANDROID_ADB_SERVER_PORT=False` (presence in the agent's
new Windows process only). The previous owner's process values remain UNSPECIFIED.
`C:\platform-tools\adb.exe` exists/readable; its binary was **not invoked**.
APK and QR exist/readable and match the unchanged hashes below.
**Reproduced failed prerequisite:** `C:\Windows\System32\mspaint.exe` does not exist.
Registered `Microsoft.Paint_8wekyb3d8bbwe` is Store-signed, status Ok, not development;
its existing executable is
`C:\Program Files\WindowsApps\Microsoft.Paint_11.2605.81.0_x64__8wekyb3d8bbwe\PaintApp\mspaint.exe`.
The previous coarse output cannot establish whether an earlier environment guard
also failed, but this missing path independently blocks the published preparation.

Correction: use System32 Paint when present, otherwise resolve only the installed
Microsoft Paint package with the verified family/status/signature-kind checks and
existing executable. No software install, cloud/default viewer, file association or
APK/QR changes. Resolve before any target prompt/ADB. Emit fixed `FAILED_CHECK`
identifiers and allowlisted `EXCEPTION_CATEGORY`, never exception messages or values.
Installation now reports `NOT_ATTEMPTED`, `ATTEMPTED_UNVERIFIED` or `VERIFIED`.
Local failure no longer implies possible installation.

Actual Windows 5.1 `-HostOnly` returned `HOST_ARTIFACT_CHECKS=PASS_NO_ADB` and
`INSTALLATION_STATUS=NOT_ATTEMPTED`, with no prompt/viewer/device operation.
Eighteen focused fake-boundary cases passed on 5.1, adding Store Paint resolution,
missing viewer/ADB, unreadable APK, both hash failures, each environment override,
host-only early return and installation failure states. All local-failure cases
assert zero ADB calls; original target/package/no-replacement tests remain.
An initial test-harness failure was fixed by loading standard PowerShell modules
before defining mocks, preventing module autoload from replacing test doubles.
This is test scaffolding only, not an app/device defect. PowerShell 7 execution is
tracked in the existing Windows CI job; no local PowerShell 7 installation was found.

Safe optional local-only check (never calls ADB):

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\platform-tools\kr007-physical-invalid-camera.ps1" -HostOnly
```

## Verified existing artifacts

Owner-local root (outside repository/cloud directories):
`C:\Users\3feli\AppData\Local\KidRemote\kr006-runtime\e03b4820-193b-4132-b1fc-f7950eeed7fe`.

| Artifact relative to that root | SHA-256 |
| --- | --- |
| `artifacts-kr007-14d82db\debug\child-debug.apk` | `3ff9962ec6bf55eab20eda993e879112be9c04a3ed7c00e8287fc7660ad63ac9` |
| `camera-storage-2026-09-11T23-02-20-209Z\scene-invalid.png` | `3c9a84602486d7052346116f0e182527578970f36a894a8a733b6515cd1d5287` |

APK source `14d82dbbf764c5a78c2c80393756d5302842958f`, exercised in the
[focused record](evidence/KR-007-CAMERA-BOUNDARY-2026-09-12.json); source CI
34662155724 passed. No rebuild or test-APK installation. Native AAPT2 37.0.0
rechecked the actual APK: application ID `dev.kidremote.child.unassigned.debug`,
activity `dev.kidremote.child.ChildActivity`, version 1 / `0.0.1-local`, target API36,
debuggable. Permissions: `android.permission.CAMERA`, `android.permission.INTERNET`,
and internal `dev.kidremote.child.unassigned.debug.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION`.
No Accessibility/Usage Access/overlay/device admin/storage/photo-library permission.
The APK still contains its original debug emulator endpoint; do not change it or
start a backend. It is not a release/real-use identity.

The PNG was generated by existing `prepareCameraQr` -> `pairingBitmap` with `{}`,
not a pairing secret. It is 512x512; local deterministic pixel inspection rechecked
white borders of 77/77/78/78 pixels. Exact hash matches the PNG that passed the
separate real Android decoder/schema fixture control. Reuse it unchanged; no
new generation or emulator invocation needed. Display at 100% or larger on the PC,
with all four white borders visible; do not crop, blur or scan any other code.

## Owner command — preflight, conditional install, open, then manual check

Run once in **Windows PowerShell**, without a transcript/log recorder. Connect only
the authorized Samsung by USB, unlocked and ordinarily usable. If a KR-003
restriction prevents this, stop; do not use this procedure to change that restriction.
The script requires manual `SM-X400` confirmation, one authorized device, exact
Samsung/SM-X400/Android16/API36 and primary Android user0. It emits only these coarse
metadata, stages and booleans, never the serial or package list. Mismatch/unknown stops.

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\platform-tools\kr007-physical-invalid-camera.ps1"
```

This is a checked copy of [the short owner script](../../tools/kr007/physical-invalid-camera.ps1),
not a rebuilt APK/bundle or a new diagnostic framework. Its exact guarded ADB actions
are listed below for review, **not a second independent sequence to rerun**. The
in-memory `$selectedDevice` comes from the sole USB target and is never printed:

```powershell
# Read-only preflight (output captured/minimized by script):
& 'C:\platform-tools\adb.exe' devices
& 'C:\platform-tools\adb.exe' -s $selectedDevice shell getprop ro.product.model
& 'C:\platform-tools\adb.exe' -s $selectedDevice shell getprop ro.product.manufacturer
& 'C:\platform-tools\adb.exe' -s $selectedDevice shell getprop ro.build.version.sdk
& 'C:\platform-tools\adb.exe' -s $selectedDevice shell getprop ro.build.version.release
& 'C:\platform-tools\adb.exe' -s $selectedDevice shell am get-current-user
& 'C:\platform-tools\adb.exe' -s $selectedDevice shell pm list packages -u dev.kidremote.child.unassigned.debug
& 'C:\platform-tools\adb.exe' -s $selectedDevice shell cmd package help
# ONLY after every guard passes and package query is empty:
& 'C:\platform-tools\adb.exe' -s $selectedDevice install --no-streaming -R --user 0 $apk
& 'C:\platform-tools\adb.exe' -s $selectedDevice shell am start -W -n 'dev.kidremote.child.unassigned.debug/dev.kidremote.child.ChildActivity'
```

Any existing/retained package record stops before installation. Explicit uppercase
`-R` disables replacement, additionally guarding the install transaction; its support
must be present in captured package help. Never substitute lowercase `-r`, grant `-g`,
update/uninstall/clear, remove a profile or bypass installation security. These flags
and all-user package listing follow [AOSP package-manager source](https://android.googlesource.com/platform/frameworks/base/+/93ff883c7b64dd39c292c4b4c1732ebb2f784df8/services/core/java/com/android/server/pm/PackageManagerShellCommand.java)
and [ADB documentation](https://developer.android.com/tools/adb). Unknown Samsung output
fails closed, not a reason to relax a guard. No package history is printed/persisted;
the device-side query is filtered only to this application ID.

## Physical sequence and evidence meaning

1. Confirm fresh **“Não pareado. Enforcement não disponível.”** with no recovery or
   existing identity. The script also reads only existence bits for the two known
   app-owned identity/pending files; absent/unknown directory is not accepted as empty.
2. The local PNG opens in Paint on the PC. Tap **“Escanear QR do responsável”** on the
   tablet and manually allow camera access while using this app. Do not grant other
   permissions. Aim only at this `{}` QR for at most 30 seconds; one session, no retries.
3. Expected fresh response: **“QR inválido. Use apenas o QR do responsável neste
   ambiente.”** Report P only if it appeared after this camera scan, not merely camera
   opening. Report N for no recognition, E for another error, uncertainty otherwise.
4. The script checks identity and pending-marker absence again without reading their
   contents. Stop camera if still scanning; confirm preview is gone and the Android
   camera indicator no longer reports active camera use by this application. A recent
   access history indicator alone is not active use. Report uncertainty if ambiguous.

**Owner-observed:** fresh UI, camera-triggered invalid response and release indicator.
**Read-only instrumented:** exact model/API and absent identity/pending files before
and after. **Source-derived, not network-instrumented:** in a fresh app, `parseQr({})`
returns null before pending-marker creation, `api.redeem` or credential persistence;
fresh `restore` with no identity makes no network request. Existing debug counters
are process-memory only and not externally readable without instrumentation; they
are not required or reported as physical metrics here. No test APK/debug attachment,
raw logs, frames, screenshots or decoded content is collected.

The success line `OWNER_OBSERVED_INVALID_QR_WITH_EMPTY_LOCAL_IDENTITY` means only
this bounded invalid-input observation plus the stated checks. No recognition leaves
acquisition unproven; do not attribute cause to hardware/framing/app. Missing checks,
blocked installation, stale/nonfresh UI, camera error or uncertain release stop this
attempt. Do not retry automatically. This cannot prove valid enrollment, complete
AC-2, OEM support or enforcement readiness. Historical results remain unchanged.

## Non-destructive finish / bailout

Tap **Parar câmera** if present, otherwise leave the child app using the device's
ordinary navigation, then verify camera use ceased. If a restriction or unavailable
control prevents this, stop and report; do not alter KR-003, lock credentials or
navigation configuration. No automatic uninstall, clear-data or permission revocation.
The newly installed debug app and any permission manually granted remain installed;
if install status was uncertain, report that uncertainty rather than reinstalling.
Close the local Paint viewer without saving changes. Retain the original PNG/APK.

Expected owner effort: approximately 2–3 minutes including installation and at most
30 seconds aiming. Return only sanitized script result lines and your physical
observations; no serial, screenshots, logs or account content.

Preparation validation: Windows PowerShell 5.1 executed eight fake-boundary cases
(success, existing package, multiple devices, foreign model, bad hash, unsupported
no-replace capability, existing identity and unrecognized QR). All ADB/viewer/input
boundaries were stubbed, explicitly not physical evidence. Tests also check that no
mutation precedes guards and no target/package-list output escapes. The same focused
test is included in existing Windows PowerShell 5.1/7 CI jobs; no new Android build
was performed locally and no physical ADB command was invoked.
