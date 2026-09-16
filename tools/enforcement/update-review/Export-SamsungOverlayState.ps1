# Test-only export of the fixed exact-configuration metadata program; no device/ADB execution.
Import-Module (Join-Path $PSScriptRoot 'Review.psm1') -Force
$configuration=[ordered]@{manufacturer='samsung';model='SM-X400';android='16';api='36';build='BP4A.251205.006';patch='2026-07-05'}
[Console]::Write((Get-ReviewStateScript $true $configuration))
