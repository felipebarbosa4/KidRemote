# Test-only export of the actual fixed metadata program; no device/ADB execution.
Import-Module (Join-Path $PSScriptRoot 'Review.psm1') -Force
[Console]::Write((Get-ReviewStateScript))
