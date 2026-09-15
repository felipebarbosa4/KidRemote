# Product partial preparation reconciliation — OD-50/51

## Contract / immutable history

See [task](../../exec-plans/PRODUCT-RESUME-RECONCILIATION.md). No Samsung/ADB,
Windows executable, interop repair, emulator or physical runner was executed by this task.
The historical attempt `d9157ae6-a6ff-4849-919f-c8f13fe08f7e` remains exactly
**INVALID:PAIRING_TIMEOUT / cleanup UNVERIFIED**. OBSERVED host artifacts confirm
source `3693034816039de67087066f077e6e02a9507dd6`, final admission ENROLLMENT_ADMITTED,
OWN_REVERSE_REMOVED and STOPPED_SYNTHETIC_LEASE_AND_ENROLLMENT_RETAINED. No policy,
Lock or Unlock admission. Historical files/bundles are not rewritten.

## Compatibility / current state

OBSERVED: 15 canonical backend inputs (all SQL migrations, function implementations,
local gateway and protocol contract), plus the format-1 lease schema discriminator,
have SHA-256 digest `6b29bd9c8f90c007ea903e836a40078692a8b5bbc36634e0f38140c1c808b1a9`
at both exact historical source 3693034 and e8be9cf/current source. Tests independently
read historical git objects. Host QR files/docs are excluded. Execution source and
ownership source remain distinct; exact original Docker labels and SQL lease identity
are still checked. No arbitrary source mismatch waiver or resource adoption.

INFERRED: current tablet is LAB_PACKAGE_UNPAIRED / SAFE_RESUME_FROM_ENROLLMENT,
based on owner observation and the completed failed pairing attempt. Live private
metadata, exact installed provenance, permissions/reverse, owned backend sessions,
device/credential existence still require the future runner's readback. No private
identity blob, credential or child database content is read.

## Implemented boundaries

Package states are independent from saved backend device presence. Exact installed
lab bytes are retained for ENROLL / RESET_ENROLL / VERIFY_REUSE. A separate fsynced
RESUME_REVIEW records source/bundle/digest/path without changing historical cleanup.
The narrow historical no-policy attempt may be reviewed; Lock/policy history or
ambiguous ownership is not bypassed. Concurrent runners remain lease-lock excluded.

Metadata-only paired reuse is followed by fresh authenticated ACK sequence/receipt
verification, through normal app resume/sync, before any canonical policy mutation.
No product hook or credential extraction. Only incomplete, attributable unconfigured,
unreported enrollment can take automatic repair: canonical finish_pairing revocation,
exact package data clear and empty-state verification. Configured/reported ambiguous
states fail closed for review. Abandoned own sessions are canonically cancelled;
a concurrent redemption is not silently ignored. New QR uses the unchanged READY gate.

Consent instructions are skipped when corresponding permission is already enabled.
A successful new PASS/verified independent cleanup can resolve the historical gate
for later consistent reuse without rewriting old rows. The independent fixture oracle
and canonical desired/applied distinction remain unchanged.

## Validation (in progress)

OBSERVED local: 57 resume model/admission/failure assertions; four compatibility tests;
14 lease tests; 43 host/reuse checks; 75 replacement; 36 replacement transport;
72 prerequisites; 64 independent oracle; 43 host-preflight; frozen module/closure parse
and journal seam passed. Repository validator and diff whitespace check passed.

Preserved partial local check: PreflightEntrypoint.Tests.ps1 requires Windows host
environment paths; direct Linux invocation failed on null Path. It is not a physical
attempt or native Windows PASS. Native Windows/SQL/build CI is required before freezing.

PRODUCT_PHYSICAL_ORACLE remains **BLOCKED pending full validation and bundle freeze**.
No new owner command yet. Existing 3693034/e8be9cf commands are retired for current
partial state; no separate owner diagnostic is requested.

### Preserved CI attempt 1

Run 34985676649 / source 27455b5: native QR 32 PS5.1 + 32 PS7 passed;
PS5.1 resume 57, native DPAPI/lock 20 and existing host suites passed. Real Docker
reconciliation/lifecycle and SQL job passed. Windows compatibility tests failed 2/18:
checkout CRLF bytes hashed differently from exact historical LF git objects. This is
not ignored or normalized at runtime. Repository attributes now pin backend-critical
text to LF across checkouts; runtime still rejects any differing bytes. PS7 later
steps of this failed run were not executed. Preserve this run independently.

The product-only metadata option also inventories exact AndroidX WorkManager DB/
sidecars and ProfileInstaller constants, verified in the approved f6d2a240 APK DEX
and locally preserved AndroidX bytecode. It reads only existence/size. Default old
review semantics remain unchanged: the historical two unknown files remain UNKNOWN.
