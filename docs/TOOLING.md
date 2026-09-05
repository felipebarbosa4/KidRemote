# Tooling and scaffold status

- **Goal:** Make the architecture scaffold verifiable without prematurely selecting app SDKs.
- **Context:** Initial pass on 2026-09-05 in an existing Git repository.
- **Constraints:** Exact framework/SDK/library versions stay **UNSPECIFIED** unless required and verified.
- **Done when:** Planning checks run and subsequent app bootstrap knows what remains unchosen.

Native Kotlin/Compose parent and native Kotlin child are approved, but no Gradle/Android/Supabase project is bootstrapped.
Application library/toolchain versions remain **UNSPECIFIED** until the KR-003 bootstrap verifies current compatible releases.
Placeholders explain module responsibilities. No production SQL/Edge function or application feature exists.

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
Java, javac, Gradle, adb, sdkmanager, avdmanager and emulator were not found in PATH. The Docker launcher reports that Docker is not installed in this WSL2 distro.
These observations are environment facts, not project version pins.
No emulator/physical device/backend tests were run.

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
Current mobile Play submissions require target API 36+ from 2026-08-31; actual selected target remains **UNSPECIFIED**.
[Play target API](https://support.google.com/googleplay/android-developer/answer/11926878?hl=en).
