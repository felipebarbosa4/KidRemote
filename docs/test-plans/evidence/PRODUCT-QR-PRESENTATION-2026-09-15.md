# OD-51 host QR presentation

## Preserved owner attempt

**OBSERVED:** owner reported active Samsung camera/scanner but no QR window, including
Alt+Tab. Exact reason for the missing visible surface on that PC is **UNSPECIFIED**.
Code inspection establishes no window handle/visibility/activation gate and no dedicated
message loop: `Form.Show()` was followed by ADB and synchronous HTTP on the UI thread.
This is a verified harness defect; starvation/focus on the owner PC is **INFERRED**,
not a retrospectively observed window state.

Host-only read of the completed journal/result found attempt
`d9157ae6-a6ff-4849-919f-c8f13fe08f7e`, source
`3693034816039de67087066f077e6e02a9507dd6`:

- hostValidated true;
- original INVALID:PAIRING_TIMEOUT, ENROLLMENT_ADMITTED, replacementAdmitted true;
- cleanup UNVERIFIED;
- backend STOPPED_SYNTHETIC_LEASE_AND_ENROLLMENT_RETAINED;
- reverse OWN_REVERSE_REMOVED;
- labRecovery MANUAL_RECOVERY_REQUIRED.

Journal admission began 2026-09-15T01:25:54.4147947Z; enrollment admission
01:26:10.8195844Z; immutable INVALID verdict 01:30:13.0323780Z and UNVERIFIED cleanup
01:30:13.0592464Z. No SETUP/POLICY/LOCK/UNLOCK admission exists in that journal.
These facts do not promote cleanup to verified. The agent neither interrupted nor
reran the attempt, changed its record, read private app data, nor operated the Samsung.

## Correction and evidence boundary

Host-only C# WinForms helper on a dedicated STA thread, Application.Run message loop,
unique KidRemote title, centered fixed logical QR area, thread-local DPI awareness,
TopMost/taskbar presence, Show/Activate/BringToFront and foreground activation attempt.
Window flash is used if foreground acquisition is denied. The presentation gate reads
input-desktop identity, Form visibility/disposal, actual HWND/IsWindowVisible, title,
TopMost style and on-screen bounds after the UI loop begins. No screenshot, QR payload
text, private QR file or manual owner confirmation is used. Polling cannot starve the UI.

The scan instruction follows QR_WINDOW_READY and a second liveness check after opening
the child. Creation/display/liveness failure becomes INVALID:QR_PRESENTATION_FAILED
before scan instruction; existing pairing timeout remains INVALID:PAIRING_TIMEOUT.
Success, failure and the independent UI timer close/dispose the form/image automatically.
Product QR generation and enrollment requests are unchanged.

A running message loop is required by [Application.Run](https://learn.microsoft.com/en-us/dotnet/api/system.windows.forms.application.run).
Windows may deny foreground acquisition even after activation; this is explicitly not
claimed as guaranteed human visibility ([SetForegroundWindow](https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-setforegroundwindow)).
Actual native window state and continuing event processing are the automated evidence.

## Current restart boundary

The prior UNVERIFIED journal still blocks a new attempt under the existing runner.
A new source also cannot silently adopt the old source-bound persistent lease. The
already-replaced child cannot be treated as the obsolete old-signer package. This QR
slice deliberately does not bypass these gates or invent a partial-setup resume path.
A frozen presentation fix does not by itself establish readiness to resume this tablet.
Agent physical autonomy is authorized conditionally, but does not override FAIL/INVALID
review gates. Windows execution capability from this environment remains subject to the
existing unavailable WSLInterop; no repair or physical execution was attempted.

## Validation

Local synthetic gate: 11 assertions PASS; local native WinForms UI NOT_RUN (Linux).
Native Windows PS5.1/PS7 and full required CI results are retained in the delivery/PR
record for the exact frozen source. Tests use a synthetic 512px image, no real pairing
payload/device, and inspect native state without screen capture. Historical bundles
remain unmodified; the 3693034 command is retired for future execution.

### Failed validation preserved

CI `34927986598`, source `1c5e9e5`: Windows failed with
INVALID:QR_PRESENTATION_FAILED during native QR setup. The first error wrapper hid
the exact phase; no native presentation PASS is claimed. Added bounded phase/type
diagnostics (no native error text or PNG/payload) to identify the failure. Other
completed jobs are not pooled into a passing workflow.

CI `34928137766`, source `b2cbf1b`: the native error phase is now established as
WINDOW_VISIBILITY (not assembly compilation or desktop admission). It remains FAILED.
Add bounded boolean HWND/visibility/title/TopMost/bounds and dimensions diagnostics,
without content or capture, to distinguish the exact failed presentation check.

CI `34928264285`, source `40a7bc3`, still FAILED with WINDOW_VISIBILITY before the
new bounds-failure branch. No bounds diagnosis is inferred. Preserve this attempt and
add UI exception type, pump count, expiry flag and completed assertion count only.

CI `34928383992`, source `175dfa3`: exact native failure
WINDOW_VISIBILITY_PUMP17_EXPIRED1 after 26 completed assertions. Creation, real HWND,
visibility/TopMost/title, independent pump survival, second unique window and close
on successful enrollment had passed. The one-second timeout fixture expired during
initial presentation before READY. Correct the helper to start its scan lifetime on
first confirmed presentation, independently of the bounded startup deadline. This
failed workflow is preserved; partial checks are not an overall PASS.

CI `34928523650`, source `6d8ab2f`: after separating deadlines, the exact failure is
H1/V1/T1/TOP0/FORM1/BOUNDS1, window 560x583 inside desktop work area 1024x720,
65 pump ticks, not expired, 26 checks completed. The third window's native TopMost
style was absent despite the managed property; bounds and visibility were valid.
This refines the earlier timeout observation rather than treating that partial
explanation as complete. Defer final activation until Show/Run initialization, then
apply SetWindowPos(HWND_TOPMOST) to this owned HWND only. The actual native TopMost
check remains mandatory. No setting or other window is modified.

CI `34928691745`, source `868c156`: all 32 native QR checks PASS on PS5.1.
The later, unchanged legacy VisualCaptureWorker synthetic test failed deleting an
open `.png.partial` file; no physical capture was involved. PS7 had not run yet.
Preserve this separate failure, keep the legacy runner unchanged, and isolate the
new QR UI tests in their own PS5.1/PS7 processes before the existing legacy suite.

A read-only Windows PowerShell version probe from the current Linux execution tool
failed with exit 126 / Exec format error. No Windows process or device command was
started. There is no alternative installed Windows execution connector. Owner autonomy
is authorized, but that authorization cannot supply a missing native execution channel.

Local scope regression on `010c1d4`: constructing (but not invoking) the enrollment
callback and inspecting its dynamic module showed New-ProductQrWindow unavailable.
Nested import alone does not populate the GetNewClosure caller scope. Explicitly load
QrPresentation in the owner entrypoint graph and test resolution inside the actual
enrollment closure. This prevents a second missing-command failure before a future
owner run. No ADB/backend callback was invoked by this scope test.
