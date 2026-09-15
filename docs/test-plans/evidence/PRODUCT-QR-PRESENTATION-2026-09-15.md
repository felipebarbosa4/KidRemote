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
