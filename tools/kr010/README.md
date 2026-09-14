# KR-010 local parent controls — OD-48

- **Goal:** Actual Compose parent→authenticated canonical operation→child Room/sync/ACK→parent report/status, without enforcement or push.
- **Context:** Existing KR-006 parent/Auth, KR-007 enrollment and KR-009 local gateway; draft PR #23, Issue #10.
- **Constraints:** Exact existing owned emulator only, synthetic accounts, no camera execution/screenshots/physical/Samsung, provider, deployment or merge. No child package/history collection.
- **Done when:** Focused JVM/SQL/HTTP/Android, regressions and CI execute; independent failures/APK identities and cleanup are recorded.

## Run

Use the existing owner manifest and Windows emulator lifecycle helper documented in
[KR-006](../../apps/parent-mobile/README.md). Never discover or substitute another ADB
serial. The backend runner verifies disposable resource ownership before cleanup.

Build from a recorded source with the existing Gradle wrapper and installed/licensed
SDK 37 / build-tools 37.0.0, JDK 17:

```sh
ANDROID_HOME=/path/to/installed/sdk spikes/android-enforcement/gradlew -p apps/parent-mobile --no-daemon testDebugUnitTest lintDebug assembleDebug assembleDebugAndroidTest lintRelease assembleRelease
```

Put the four actual APKs (`app-debug.apk`, `app-debug-androidTest.apk`,
`child-debug.apk`, `child-debug-androidTest.apk`) in a new `apks-kr010-<source-prefix>`
directory beneath that owner directory; retain their source, SHA-256, package/version
and certificate metadata. Do not overwrite prior source bundles. The local tests
uninstall/reinstall only these task packages; this is not update-path evidence.

```sh
KR010_RUNTIME=1 KR010_APK_SOURCE=<full-build-source-sha> KR006_RUNTIME_DIRECTORY=<existing-owned-directory> node tools/kr004/test-local-db.mjs <local-docker-cli> <explicit-local-engine-endpoint> --sync-runtime
```

The runner executes existing SQL/Auth/enrollment/rotation/pagination tests and the
new real parent projection HTTP checks. Compose creates/validates a synthetic Auth
account and QR; generated QR pixels use the existing decoder without camera capture.
Actual child credentials, Room and HTTP ACK are used. One explicitly controlled
eligible interval sets used_ms to 3,600,000; it is not physical UsageStats evidence.

Each instrumented stage starts a new app process. The existing debug marker suppresses
automatic child measurement/scheduling so controlled clocks remain deterministic;
parent automatic refresh is suppressed only in this fixture. The parent clicks real
buttons; the child explicitly executes existing sync/ACK. HTTP operation response
loss is injected after a real successful response is parsed and before its result
reaches the model; it is not packet-level loss. Concurrency uses a separate own-actor
SQL transaction between the parent read and tap. Staleness ages only the fixture's
server receipt. Permission/update flags use isolated rendering fixtures, not invented
OS/adapter evidence. No FCM callback or fake ACK participates.

KR-006 Auth regression reuses the same APK bundle with `KR010_AUTH_REGRESSION=1`,
`KR010_APK_SOURCE` and `KR006_RUNTIME_DIRECTORY`, using `--parent-runtime`.
The host clears only task app/test data and removes task backend resources. Stop the
verified emulator through its owner helper afterward. Historical APK/AVD/evidence
are retained. See [independent evidence](../../docs/test-plans/evidence/KR-010-LOCAL-2026-09-14.md).

The `layout` instrumentation step is a pure actual-Action component fixture with
controlled emulator font/input mode and no backend. It is separated from the real
product flow; keyboard focus does not establish physical TalkBack acceptance.
