# KR-003 Samsung runner-v3 startup failure — 2026-09-08

- **Goal:** Preserve the failed `cf7b2e9` invocation without misclassifying it as device or enforcement evidence.
- **Context:** The owner invoked the published runner-v3 command once on Windows PowerShell; no runner evidence directory was produced.
- **Constraints:** Owner-provided typed console fields only; no raw environment output, device serial, account/content/history, screenshot or invented device action.
- **Done when:** The exact failure boundary, source correlation and zero-device-execution disposition are explicit.

## OBSERVED

- Invoked bundle: `C:\platform-tools\kr003-oracle-calibration-bundles\cf7b2e9`, source `cf7b2e97fa12bd3397ea8ba7a40174456df27ba0`.
- PowerShell stopped immediately with `Cannot overwrite variable Host because it is read-only or constant.`, `CategoryInfo: WriteError`, and `FullyQualifiedErrorId: VariableNotWritable,Test-KR003-OracleCalibration.ps1`.
- The source and copied bundle entrypoint are byte-identical and assign `$script:Host=New-KRCalibrationHostState` at line 30. The protected `try` starts at line 172; output-directory creation is line 174 and the first ADB operation is later.
- No evidence directory was reported. This invocation is not one of the earlier retained calibration evidence directories.

## INFERRED

- PowerShell variable names are case-insensitive; scope-qualifying `$Host` as `$script:Host` does not make it a distinct writable variable. The line-30 assignment is the exact startup defect.
- Because the terminating write error occurs before the protected block, directory creation and every bundle, transport, permission, fixture, candidate, ARM, hold, oracle, prompt, cleanup and finalization action were not reached. No device command ran.

## UNSPECIFIED

- There is no physical-device result to classify. Device state at invocation time is not re-observed by this failed host process and remains outside this record.

## Disposition

This is a host-script startup failure with zero physical execution, zero calibration samples and zero qualification samples. It does not modify or supersede the Samsung transport PASS, three v1 calibration INVALIDs, or runner-v2 `INVALID:HOST_EXCEPTION` evidence.
