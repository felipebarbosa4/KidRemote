# OD-49 local product adapter validation

- **Goal:** Validate the existing KR-003 candidate in the actual child and scoped ACK path.
- **Context:** Issues #3/#10; stacked draft PR #24; OD-49.
- **Constraints:** Existing task-owned emulator only. No physical, capture, FCM, merge or distribution.
- **Done when:** Classified evidence covers actual local behavior and explicitly retains unrun physical criteria.

`emulator-service.py <full-source-sha>` reuses the existing owner-manifest guard,
fixed emulator-5584, actual child APK and KR-003 ordinary fixture. APKs must already
exist in the source-specific `apks-kr010-<prefix>` folder. It installs task packages,
executes service instrumentation, retains an independent JSON attempt and cleans
only task package data. No package/window content is exported.

For the actual parent/SQL/gateway/Room/service/ACK test, use the existing KR-009
`--sync-runtime` harness with `KR_ENFORCEMENT_RUNTIME=1`, `KR009_APK_SOURCE` and
`KR006_RUNTIME_DIRECTORY`. This bounded mode requires the existing ordinary fixture
installed on the owned emulator and source-specific `apks-kr009-<prefix>` APKs.
Without the flag, the existing KR-009 suite runs unchanged. No physical runner is
provided: the existing Samsung oracle is bound to spike package/hash and ARM/CLEAR;
its permission and oracle calibration do not transfer to this product service.

`emulator-service.py <full-source-sha> death` retains an intentional kill and a
separate restart-instrumentation stage. This scenario currently has two preserved
NOT_PASSED attempts: service reconnection was not observed within 15 seconds. It is
not an automatic-restart acceptance test that has passed. The host always restores
its emulator settings and clears only owned test data, including after expected death.

OD-49 host diagnosis extension: `host-recovery.py <full-source-sha> no-restart`
uses the same task-owned emulator and immutable source-specific APK directory.
It opens the product only during setup, runs the existing self-kill through
`am instrument --no-restart`, then observes up to 60 seconds without instrumentation
or app/service/permission intervention. A new PID alone is insufficient: the known
Accessibility service metadata and exact component's received system binding must
agree. Only then may verification attach without restarting the process.

Omitting `no-restart` retains the old instrumentation lifecycle as a separate
diagnostic control. App reopen occurs only after the automatic window failed and
is classified separately. Cleanup runs after observation/verification, never inside
the automatic window. All attempts retain independent sanitized JSON; raw OS dumps
and credentials are not exported. Times start when the expected-death command
returns and are polling observations, not callback latency or an acceptance SLA.

The real backend harness supports `KR_ENFORCEMENT_RECOVERY=1` with the existing
KR-009 source/runtime variables. It seeds authenticated identity/Lock, invokes the
host in `network` mode, and verifies the observed post-recovery ACK through the
parent status API. Standalone fixture confirmations do not claim network evidence.
See the separate PRODUCT-RECOVERY-HOST evidence report; historical NOT_PASSED
instrumentation attempts remain unchanged.
