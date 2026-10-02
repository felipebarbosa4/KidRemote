Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot '../update-review/ProductRuntimeCatalog.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'MetadataObservation.psm1') -Force
Write-Output (Get-Od51MetadataScript (Get-ReviewStatePaths $true))
