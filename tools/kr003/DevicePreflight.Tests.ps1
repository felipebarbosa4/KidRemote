Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'DevicePreflight.psm1') -Force
$script:Checks=0
function Assert-Equal($Actual,$Expected){$script:Checks++;if($Actual -cne $Expected){throw "Expected $Expected; got $Actual"}}
function Assert-Reject([scriptblock]$Action,[string]$Expected){$caught=$null;try{&$Action}catch{$caught=$_.Exception.Message};Assert-Equal $caught $Expected}

Assert-Equal (Convert-KRDeviceText ' samsung ' TEXT) 'samsung'
Assert-Equal (Convert-KRDeviceText 'SM-X000' TEXT) 'SM-X000'
Assert-Equal (Convert-KRDeviceText '36' API) '36'
Assert-Equal (Convert-KRDeviceText '36x' API) 'UNSPECIFIED'
Assert-Equal (Convert-KRDeviceText '2026-08-05' PATCH) '2026-08-05'
Assert-Equal (Convert-KRDeviceText '2026/08/05' PATCH) 'UNSPECIFIED'
Assert-Equal (Convert-KRDeviceText 'serial`r`nleak' TEXT) 'UNSPECIFIED'
Assert-Equal (Convert-KRBooleanSetting '1') 'ENABLED'
Assert-Equal (Convert-KRBooleanSetting '0') 'DISABLED'
Assert-Equal (Convert-KRBooleanSetting 'null') 'UNSPECIFIED'
$notInstalled=Get-KRRequiredPermissionState $false $null $null $null
Assert-Equal $notInstalled.UsageAccess 'NOT_APPLICABLE_CANDIDATE_NOT_INSTALLED'
Assert-Equal $notInstalled.AccessibilityService 'NOT_APPLICABLE_CANDIDATE_NOT_INSTALLED'
# Android 10/AOSP-style app-op output and short flattened component.
$granted=Get-KRRequiredPermissionState $true 'GET_USAGE_STATS: allow' 'other/service:dev.kidremote.spike.enforcement/.EnforcementAccessibilityService' '1'
Assert-Equal $granted.UsageAccess 'GRANTED';Assert-Equal $granted.AccessibilityService 'GRANTED'
$denied=Get-KRRequiredPermissionState $true 'GET_USAGE_STATS: ignore' 'other.package/.Service' '1'
Assert-Equal $denied.UsageAccess 'NOT_GRANTED';Assert-Equal $denied.AccessibilityService 'NOT_GRANTED'
$usage16=Get-KRUsageAccessVerification 'Uid mode: GET_USAGE_STATS: allow; time=+2m3s'
Assert-Equal $usage16.RunnerState 'ENABLED';Assert-Equal $usage16.ParseResult 'MODE_ALLOWED'
$full=Get-KRAccessibilityVerification 'other/service:dev.kidremote.spike.enforcement/dev.kidremote.spike.enforcement.EnforcementAccessibilityService' '1'
Assert-Equal $full.RunnerState 'ENABLED';Assert-Equal $full.ParseResult 'GLOBAL_ENABLED_COMPONENT_MATCH_FULL'
$short=Get-KRAccessibilityVerification 'dev.kidremote.spike.enforcement/.EnforcementAccessibilityService' '1'
Assert-Equal $short.RunnerState 'ENABLED';Assert-Equal $short.ParseResult 'GLOBAL_ENABLED_COMPONENT_MATCH_SHORT'
$accessDisabled=Get-KRAccessibilityVerification 'other.package/.Service' '1'
Assert-Equal $accessDisabled.RunnerState 'DISABLED';Assert-Equal $accessDisabled.ParseResult 'COMPONENT_ABSENT'
$accessUnknown=Get-KRAccessibilityVerification 'not-a-component' '1'
Assert-Equal $accessUnknown.RunnerState 'UNKNOWN';Assert-Equal $accessUnknown.ParseResult 'COMPONENT_LIST_UNPARSEABLE'
$globalUnknown=Get-KRAccessibilityVerification 'dev.kidremote.spike.enforcement/.EnforcementAccessibilityService' 'unexpected'
Assert-Equal $globalUnknown.RunnerState 'UNKNOWN';Assert-Equal $globalUnknown.ParseResult 'GLOBAL_STATE_UNPARSEABLE_OR_MISSING'
$usageUnknown=Get-KRUsageAccessVerification 'GET_USAGE_STATS: vendor-new-mode'
Assert-Equal $usageUnknown.RunnerState 'UNKNOWN';Assert-Equal $usageUnknown.ParseResult 'UNPARSEABLE_OR_MISSING'
$metadata=New-KRDeviceMetadataRecord 'Samsung' 'SM-X000' '16' '36' '2026-08-05' 'BP2A.260805.001' '0' '1' '1' $false $null $null $null
Assert-Equal (Test-KRDeviceMetadataComplete $metadata) $true
Assert-Equal $metadata.Schema 2
Assert-Equal $metadata.BatteryManagement.BatterySaver 'DISABLED'
Assert-Equal $metadata.RequiredPermissionState.UsageAccess 'NOT_APPLICABLE_CANDIDATE_NOT_INSTALLED'
$runner=Get-KRRequiredPermissionVerification $true 'GET_USAGE_STATS: allow' 'dev.kidremote.spike.enforcement/dev.kidremote.spike.enforcement.EnforcementAccessibilityService' '1'
$healthySnapshot=[PSCustomObject]@{usage=$true;accessibility=$true;heartbeat=$true;eligible=$true;uncertain=$false;adapter='NOT_REQUIRED'}
$healthy=New-KRCalibrationPermissionDiagnostic $runner $healthySnapshot
Assert-Equal $healthy.UsageAccessRunner 'ENABLED';Assert-Equal $healthy.AccessibilityRunner 'ENABLED'
Assert-Equal $healthy.ServiceHeartbeat 'FRESH';Assert-Equal $healthy.CandidateHealth 'HEALTHY';Assert-Equal $healthy.CandidateEligible 'ELIGIBLE'
Assert-Equal (Get-KRRequiredPermissionFailure $healthy $false) $null
$stale=New-KRCalibrationPermissionDiagnostic $runner ([PSCustomObject]@{usage=$true;accessibility=$true;heartbeat=$false;eligible=$true;uncertain=$false;adapter='NOT_REQUIRED'})
Assert-Equal $stale.ServiceHeartbeat 'STALE';Assert-Equal $stale.CandidateHealth 'ENFORCEMENT_DEGRADED'
Assert-Equal (Get-KRRequiredPermissionFailure $stale $false) 'INVALID:SERVICE_HEARTBEAT_NOT_FRESH'
$revokedRunner=Get-KRRequiredPermissionVerification $true 'GET_USAGE_STATS: ignore' 'other.package/.Service' '1'
$revoked=New-KRCalibrationPermissionDiagnostic $revokedRunner ([PSCustomObject]@{usage=$false;accessibility=$false;heartbeat=$false;eligible=$true;uncertain=$false;adapter='NOT_REQUIRED'})
Assert-Equal (Get-KRRequiredPermissionFailure $revoked $true) 'FAIL:PERMISSION_OR_SERVICE_LOST'
$unknown=New-KRCalibrationPermissionDiagnostic (Get-KRRequiredPermissionVerification $true 'unexpected' 'not-a-component' 'unexpected') $healthySnapshot
Assert-Equal (Get-KRRequiredPermissionFailure $unknown $false) 'INVALID:USAGE_ACCESS_RUNNER_UNKNOWN'
$metadata.Model='UNSPECIFIED';Assert-Equal (Test-KRDeviceMetadataComplete $metadata) $false
$record=New-KRDeviceOperationRecord 'DEVICE_METADATA' 0 'NONE'
Assert-Equal (($record.PSObject.Properties.Name)-join ',') 'OperationCategory,ExitCode,StderrClass'
Assert-Reject {New-KRDeviceOperationRecord 'ADB_DEVICES_RAW' 0 'NONE'} 'INVALID:DEVICE_OPERATION_CATEGORY'
Assert-Reject {New-KRDeviceOperationRecord 'INPUT_TAP' 0 'RAW'} 'INVALID:DEVICE_STDERR_CLASS'
Assert-Equal (Get-KRDeviceTransportVerdict $true $true $true $true $true 7 8 $null) 'PASSED_TRANSPORT_PREFLIGHT'
Assert-Equal (Get-KRDeviceTransportVerdict $true $true $true $true $true 7 7 $null) 'FAIL'
Assert-Equal (Get-KRDeviceTransportVerdict $true $true $true $true $true 7 8 'INPUT_TAP') 'INVALID'
Assert-Equal (Get-KROracleCalibrationVerdict $true $true $true 'PASS' $true 0) 'PASSED_ORACLE_CALIBRATION_THIS_CONFIGURATION_ONLY'
Assert-Equal (Get-KROracleCalibrationVerdict $true $false $true 'PASS' $true 0) 'FAIL'
Assert-Equal (Get-KROracleCalibrationVerdict $true $true $true 'INVALID' $true 0) 'INVALID'
Assert-Equal (Get-KROracleCalibrationVerdict $true $true $true 'PASS' $true 1) 'INVALID'
$tokens=$null;$errors=$null
$ast=[Management.Automation.Language.Parser]::ParseFile((Join-Path $PSScriptRoot 'Test-KR003-DeviceTransport.ps1'),[ref]$tokens,[ref]$errors)
Assert-Equal $errors.Count 0
$source=$ast.Extent.Text
Assert-Equal ([bool]($source -match "Invoke-DeviceAdb 'INPUT_TAP' @\('shell','input','tap'")) $true
Assert-Equal ([bool]($source -match 'Build\.SERIAL|getSerial|ANDROID_ID|ro\.serialno|ro\.build\.fingerprint|adb.+devices|screencap|uiautomator|dumpsys\s+window|\buninstall\b|\breboot\b|pm[^\r\n]+clear|appops[^\r\n]+set|svc[^\r\n]+disable')) $false
Assert-Equal ([bool]($source -match "'CANDIDATE_INSTALL'")) $false
Write-Host "$script:Checks device-preflight assertions passed; no device command was executed."
