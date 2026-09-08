Set-StrictMode -Version Latest

function Convert-KRDeviceText {
    param([AllowNull()][AllowEmptyString()][string]$Raw, [ValidateSet('TEXT','API','PATCH')][string]$Kind = 'TEXT')
    $value = if ($null -eq $Raw) { '' } else { $Raw.Trim() }
    if ([string]::IsNullOrWhiteSpace($value) -or $value -match '^(?i:null|unknown)$') { return 'UNSPECIFIED' }
    if ($Kind -eq 'API') { return $(if ($value -match '^[0-9]{1,3}$') { $value } else { 'UNSPECIFIED' }) }
    if ($Kind -eq 'PATCH') { return $(if ($value -match '^20[0-9]{2}-(0[1-9]|1[0-2])-([0-2][0-9]|3[01])$') { $value } else { 'UNSPECIFIED' }) }
    if ($value.Length -gt 120 -or $value -notmatch '^[A-Za-z0-9][A-Za-z0-9 ._+()/:,-]*$') { return 'UNSPECIFIED' }
    return $value
}

function Convert-KRBooleanSetting {
    param([AllowNull()][AllowEmptyString()][string]$Raw)
    $value = if ($null -eq $Raw) { '' } else { $Raw.Trim() }
    if ($value -ceq '1') { return 'ENABLED' }
    if ($value -ceq '0') { return 'DISABLED' }
    return 'UNSPECIFIED'
}

function Get-KRRequiredPermissionState {
    param(
        [bool]$CandidateInstalled,
        [AllowNull()][AllowEmptyString()][string]$UsageAccessOutput,
        [AllowNull()][AllowEmptyString()][string]$EnabledServicesOutput,
        [AllowNull()][AllowEmptyString()][string]$AccessibilityEnabledOutput,
        [string]$CandidateService = 'dev.kidremote.spike.enforcement/.EnforcementAccessibilityService'
    )
    if (-not $CandidateInstalled) {
        return [PSCustomObject]@{
            UsageAccess = 'NOT_APPLICABLE_CANDIDATE_NOT_INSTALLED'
            AccessibilityService = 'NOT_APPLICABLE_CANDIDATE_NOT_INSTALLED'
        }
    }
    $usage = if ($UsageAccessOutput -match '(?im)GET_USAGE_STATS[^\r\n]*(?:allow|mode=allow)') { 'GRANTED' }
        elseif ($UsageAccessOutput -match '(?im)GET_USAGE_STATS|No operations') { 'NOT_GRANTED' } else { 'UNSPECIFIED' }
    $globalEnabled = (Convert-KRBooleanSetting $AccessibilityEnabledOutput) -eq 'ENABLED'
    $services = if ($null -eq $EnabledServicesOutput) { @() } else { @($EnabledServicesOutput.Trim() -split ':') }
    $serviceEnabled = $globalEnabled -and @($services | Where-Object { $_ -ceq $CandidateService }).Count -eq 1
    [PSCustomObject]@{ UsageAccess = $usage; AccessibilityService = $(if ($serviceEnabled) { 'GRANTED' } else { 'NOT_GRANTED' }) }
}

function New-KRDeviceMetadataRecord {
    param(
        [AllowNull()][string]$Manufacturer,[AllowNull()][string]$Model,[AllowNull()][string]$AndroidVersion,[AllowNull()][string]$ApiLevel,
        [AllowNull()][string]$SecurityPatch,[AllowNull()][string]$BuildId,[AllowNull()][string]$BatterySaver,[AllowNull()][string]$AdaptiveBattery,
        [AllowNull()][string]$AppStandby,[bool]$CandidateInstalled,[AllowNull()][string]$UsageAccessOutput,
        [AllowNull()][string]$EnabledServicesOutput,[AllowNull()][string]$AccessibilityEnabledOutput,
        [string]$CandidateService='dev.kidremote.spike.enforcement/.EnforcementAccessibilityService'
    )
    [PSCustomObject]@{
        Schema=1
        Manufacturer=Convert-KRDeviceText $Manufacturer TEXT
        Model=Convert-KRDeviceText $Model TEXT
        AndroidVersion=Convert-KRDeviceText $AndroidVersion TEXT
        ApiLevel=Convert-KRDeviceText $ApiLevel API
        SecurityPatch=Convert-KRDeviceText $SecurityPatch PATCH
        BuildId=Convert-KRDeviceText $BuildId TEXT
        BatteryManagement=[PSCustomObject]@{
            BatterySaver=Convert-KRBooleanSetting $BatterySaver
            AdaptiveBattery=Convert-KRBooleanSetting $AdaptiveBattery
            AppStandby=Convert-KRBooleanSetting $AppStandby
            OemBatteryManagement='UNSPECIFIED'
        }
        RequiredPermissionState=Get-KRRequiredPermissionState $CandidateInstalled $UsageAccessOutput $EnabledServicesOutput $AccessibilityEnabledOutput $CandidateService
    }
}

function Test-KRDeviceMetadataComplete {
    param($Device)
    if ($null -eq $Device -or $Device.Schema -ne 1) { return $false }
    foreach($name in @('Manufacturer','Model','AndroidVersion','ApiLevel','SecurityPatch','BuildId')) {
        if ($Device.$name -eq 'UNSPECIFIED') { return $false }
    }
    return $true
}

function New-KRDeviceOperationRecord {
    param([string]$Category, [int]$ExitCode, [string]$StderrClass)
    $categories = @(
        'ADB_STATE','DEVICE_METADATA','BATTERY_STATE','CANDIDATE_INSTALL_STATE','USAGE_ACCESS_STATE','ACCESSIBILITY_STATE',
        'FIXTURE_INSTALL','FIXTURE_PATH','FIXTURE_PULL','FIXTURE_OPEN','FIXTURE_STATE','INPUT_TAP','CANDIDATE_INSTALL',
        'CANDIDATE_PATH','CANDIDATE_PULL','CANDIDATE_OPEN','CANDIDATE_STATE','CANDIDATE_CLEAR','CANDIDATE_ARM'
    )
    if ($Category -notin $categories) { throw 'INVALID:DEVICE_OPERATION_CATEGORY' }
    if ($StderrClass -notin @('NONE','SECURITY_EXCEPTION','PERMISSION_DENIAL','OTHER')) { throw 'INVALID:DEVICE_STDERR_CLASS' }
    [PSCustomObject]@{ OperationCategory=$Category; ExitCode=$ExitCode; StderrClass=$StderrClass }
}

function Get-KRDeviceTransportVerdict {
    param([bool]$Authorized,[bool]$MetadataComplete,[bool]$BundleVerified,[bool]$InstalledHashVerified,[bool]$FixtureReady,[long]$BeforeTaps,[long]$AfterTaps,[AllowNull()][string]$RejectedOperation)
    if (-not $Authorized -or -not $MetadataComplete -or -not $BundleVerified -or -not $InstalledHashVerified -or -not $FixtureReady -or -not [string]::IsNullOrEmpty($RejectedOperation)) { return 'INVALID' }
    if ($AfterTaps -eq $BeforeTaps + 1) { return 'PASSED_TRANSPORT_PREFLIGHT' }
    return 'FAILED'
}

function Get-KROracleCalibrationVerdict {
    param([bool]$PositiveControl,[bool]$BlockedControl,[bool]$ServiceContinuous,[string]$PhysicalAgreement,[bool]$CleanupVerified,[int]$QualificationSamples)
    if ($QualificationSamples -ne 0 -or $PhysicalAgreement -eq 'INVALID') { return 'INVALID' }
    if (-not $PositiveControl -or -not $BlockedControl -or -not $ServiceContinuous -or $PhysicalAgreement -eq 'FAIL' -or -not $CleanupVerified) { return 'FAILED' }
    if ($PhysicalAgreement -ne 'PASS') { return 'INVALID' }
    return 'PASSED_ORACLE_CALIBRATION_THIS_CONFIGURATION_ONLY'
}

Export-ModuleMember -Function Convert-KRDeviceText, Convert-KRBooleanSetting, Get-KRRequiredPermissionState, New-KRDeviceMetadataRecord, Test-KRDeviceMetadataComplete, New-KRDeviceOperationRecord, Get-KRDeviceTransportVerdict, Get-KROracleCalibrationVerdict
