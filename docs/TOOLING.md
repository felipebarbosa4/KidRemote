# Tooling and scaffold status

## KR-006 prospective local bootstrap (OD-44, 2026-09-11)

The parent now has a separate build in `apps/parent-mobile`: AGP 9.4.0 / unchanged
Gradle 9.6.0 wrapper / JDK 17 / built-in Kotlin and Compose compiler 2.2.10;
Compose BOM 2026.09.00, Activity Compose 1.13.0, Lifecycle 2.10.0. Compile SDK 37,
Build Tools 37.0.0, target 36/minimum 28. Current Compose AAR metadata rejected
compile SDK 36; CI then compiled/tested/linted the parent with preinstalled API 37.
These are local bootstrap pins, not production identity/support or a KR-003 migration.
No local Android SDK or emulator is established; no licence/host privilege change.
[Sources and commands](../apps/parent-mobile/README.md),
[execution evidence](test-plans/evidence/KR-006-LOCAL-PARENT-2026-09-11.md).

Digest-pinned local Auth v2.196.0, PostgREST v14.17 and Mailpit v1.31.1 extend the
existing disposable database runner; no cloud project/deployment. Android CI debug
APK upload uses official upload-artifact v7.0.1 at
`043fb46d1a93c77aae656e7c1c64a875d1fc6a0a`; only the debug APK is retained, never mail,
accounts, service environments or media. Remaining historical scaffold descriptions
below are preserved and do not revoke OD-44's narrow local bootstrap permission.

## Historical scaffold and KR-003 tooling

- **Goal:** Make the architecture scaffold verifiable without prematurely selecting app SDKs.
- **Context:** Initial pass on 2026-09-05 in an existing Git repository.
- **Constraints:** Exact framework/SDK/library versions stay **UNSPECIFIED** unless required and verified.
- **Done when:** Planning checks run and subsequent app bootstrap knows what remains unchosen.

Native Kotlin/Compose parent and native Kotlin child are approved. No production Gradle/Android/Supabase project is bootstrapped,
and production application library/toolchain versions remain **UNSPECIFIED**.
KR-003 has a deliberately isolated Gradle Android test harness under `spikes/android-enforcement`; its pins do not silently select production versions.
No production SQL/Edge function or application feature exists.

CI exception required to create the requested runnable workflow:
actions/checkout **v7.0.1**, official release published 2026-07-20, pinned to
`3d3c42e5aac5ba805825da76410c181273ba90b1`.
Verified via GitHub release/tag API and official repository README on 2026-09-05.
The action documents its Node runtime/runner requirements; use a current GitHub-hosted runner and keep permissions read-only.
[Official checkout release](https://github.com/actions/checkout/releases/tag/v7.0.1),
[README](https://github.com/actions/checkout/blob/v7.0.1/README.md),
[secure workflows](https://docs.github.com/en/actions/reference/security/secure-use).

The dependency-free validator uses installed Node built-ins (Node 18+ syntax; no application Node dependency is selected).
Local tools rechecked 2026-09-05 under WSL2: Node 22.23.1 and gh 2.96.0.
Initially Java, javac, Gradle, adb, sdkmanager, avdmanager and emulator were not found in PATH. The Docker launcher reports that Docker is not installed in this WSL2 distro.
For KR-003 only, verified open-source archives were installed outside the repository at `/home/felby/.cache/kidremote-toolchains`:
Eclipse Temurin 17.0.20.1+1 and Gradle 9.6.0. Publisher SHA-256 checks passed. No local Android SDK was installed and no Google SDK licence was accepted by the agent.
No emulator/physical device/backend test was run.

```sh
node tools/validate.mjs
git diff --check
node tools/publish-planning.mjs
node tools/setup-project.mjs
```

Both planning publishers default to dry-run. Apply modes mutate only the configured repository/Project planning scope.
Issue Forms file uses JSON flow syntax, valid YAML, to allow dependency-free parsing and exact field validation.
The workflow and Issue Form are now present on default branch `main` after merged PR #11.

At app/bootstrap time verify current stable Kotlin, Compose/Material, AGP/Gradle/JDK, Room, Android SDK,
Supabase CLI/client/Edge and FCM SDK compatibility from official sources; record dates and lockfiles.
The disposable KR-003 harness verified and pins AGP 9.4.0, Gradle 9.6.0, JDK 17, compile/target API 36,
candidate minimum API 28 and Build Tools 36.0.0 on 2026-09-05. AGP 9.4 built-in Kotlin is used.
The Gradle wrapper distribution SHA-256 is `bbaeb2fef8710818cf0e261201dab964c572f92b942812df0c3620d62a529a01`;
the wrapper JAR SHA-256 is `497c8c2a7e5031f6aa847f88104aa80a93532ec32ee17bdb8d1d2f67a194a9c7`.
Current mobile Play submissions require target API 36+ from 2026-08-31; the production target remains **UNSPECIFIED**.
[Play target API](https://support.google.com/googleplay/android-developer/answer/11926878?hl=en).

AGP's current compatibility table requires/defaults Gradle 9.6.0, Build Tools 36.0.0 and JDK 17.
[AGP 9.4](https://developer.android.com/build/releases/agp-9-4-0-release-notes),
[built-in Kotlin](https://developer.android.com/build/migrate-to-built-in-kotlin),
[Java toolchains](https://developer.android.com/build/jdks),
[Gradle wrapper](https://docs.gradle.org/9.6.0/userguide/gradle_wrapper.html),
[Temurin release](https://github.com/adoptium/temurin17-binaries/releases/tag/jdk-17.0.20.1%2B1).

CI exception required for the spike's JDK setup: actions/setup-java **v6.0.0**, official release published 2026-08-24,
pinned to verified commit `dd06d9cba3e5552c54d9f8ea23572deb30010f7c`.
[Official setup-java release](https://github.com/actions/setup-java/releases/tag/v6.0.0).
