# Tooling and verification map

- **Goal:** Reuse the working local product toolchain and run validation relevant to the current change.
- **Context:** The local development stack extends beyond the original architecture scaffold. Start with [current execution](exec-plans/TASK-CONTRACT.md#current-execution).
- **Constraints:** No dependency reselection for routine work; no licence acceptance, host privilege/configuration changes, WSLInterop repair or physical operation to repair a documentation check.
- **Done when:** The agent identifies the applicable command, required environment and evidence boundary without treating a historical inventory as current capability.

## Current repository routes

| Component | Build/test instructions and authoritative pins |
| --- | --- |
| Parent Android and shared child build | [Parent README](../apps/parent-mobile/README.md), [parent build](../apps/parent-mobile/app/build.gradle.kts), [settings](../apps/parent-mobile/settings.gradle.kts) |
| Child enrollment/accounting/enforcement | [Child README](../apps/child-android/README.md), [child build](../apps/child-android/build.gradle.kts) |
| Disposable local database/Auth/gateway | [SQL tests](../supabase/tests/README.md), [existing local check](../tools/kr004/check-local.mjs) |
| Accounting/sync/controls runtime | [KR-008](../tools/kr008/README.md), [KR-009](../tools/kr009/README.md), [KR-010](../tools/kr010/README.md) |
| Windows synthetic physical lab | [Product oracle](../tools/enforcement/product-oracle/README.md), [enforcement tools](../tools/enforcement/README.md), exact active task |
| Isolated historical feasibility spike | [Spike README](../spikes/android-enforcement/README.md); separate from product-binary acceptance |

Versioned build files and recorded bootstrap evidence are authoritative for repository pins. Verify current official compatibility before changing a dependency; do not treat old “all versions UNSPECIFIED” prose as a reason to rebootstrap an existing implementation.

## Execution environment is a live prerequisite

The [previous inventory](https://github.com/felipebarbosa4/KidRemote/blob/e066e87df50c03fa25a8df78f0135fe5b4505428/docs/TOOLING.md) is preserved at its original revision. Its September 5/11 statements about missing SDK/emulator/backend tools are dated observations, not permanent prohibitions or current host discovery.

Inspect available tools read-only. Use only verified task-owned synthetic databases/emulators and explicitly authorized devices. The current physical lab and permissions are in the task/decision records; a prior Mi 8 result does not authorize or qualify Samsung, and neither qualifies other Android configurations. Physical Windows ADB uses `C:\platform-tools\adb.exe` only within the authorized handoff; do not repair WSLInterop or alter another service's settings.

## Baseline checks

Repository-local shell, from the active checkout root:

```sh
node --test tools/validate-guidance.test.mjs
node tools/validate.mjs
git diff --check
```

Use [verification routing](exec-plans/TASK-CONTRACT.md#verification-routing) for the additional component checks. The [existing full CI](../.github/workflows/planning.yml) is retained, including native Windows tests and release isolation. Guidance lint is not a test of agent behavior, product runtime, physical enforcement, database authorization or store acceptance.

Planning publishers remain dry-run by default. Do not apply them from an older checkout: stale local issue/project records must not overwrite current GitHub state. Reconcile the intended existing Issue/PR first; do not create duplicate issues or treat a successful publication as completed product acceptance.
