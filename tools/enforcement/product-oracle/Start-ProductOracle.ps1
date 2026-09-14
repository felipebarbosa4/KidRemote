<#
Goal: One future canonical-control / independent-fixture product slice.
Context: OD-49, existing draft PR #24. NOT an owner-ready physical bundle.
Constraints: No product debug controls, installation/update, settings changes or capture.
Done when: Only a validated product transport/provenance/cleanup path can reach an independent verdict.
#>
param([string]$Manifest)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'ProductOracle.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'ProductTransport.psm1') -Force
# Intentionally before manifest access, network, ADB discovery or device commands.
# This is a reviewable blocked entrypoint, not an executable physical handoff.
Assert-ProductPhysicalReadiness
