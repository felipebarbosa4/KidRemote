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

function Convert-KRComponentName {
    param([AllowNull()][AllowEmptyString()][string]$Raw)
    $value = if ($null -eq $Raw) { '' } else { $Raw.Trim() }
    if ($value -notmatch '^([A-Za-z0-9_]+(?:\.[A-Za-z0-9_]+)+)/([A-Za-z0-9_.$]+|\.[A-Za-z0-9_.$]+)$') { return $null }
    $packageName=$Matches[1];$className=$Matches[2]
    if($className.StartsWith('.')){$className=$packageName+$className}
    [PSCustomObject]@{PackageName=$packageName;ClassName=$className;Form=$(if($Matches[2].StartsWith('.')){'SHORT'}else{'FULL'})}
}

function Get-KRUsageAccessVerification {
    param([AllowNull()][AllowEmptyString()][string]$UsageAccessOutput)
    $source='CMD_APPOPS_GET_GET_USAGE_STATS'
    $value=if($null -eq $UsageAccessOutput){''}else{$UsageAccessOutput.Trim()}
    if($value -match '(?im)(?:GET_USAGE_STATS|android:get_usage_stats)\s*:\s*(?:mode=)?\s*(allow|allowed)(?:\s*[;,]|\s*$)'){
        return [PSCustomObject]@{RunnerState='ENABLED';VerificationSource=$source;ParseResult='MODE_ALLOWED'}
    }
    if($value -match '(?im)(?:GET_USAGE_STATS|android:get_usage_stats)\s*:\s*(?:mode=)?\s*(default|ignore|ignored|deny|denied|foreground|errored)(?:\s*[;,]|\s*$)' -or $value -match '(?im)^\s*No operations\.?\s*$'){
        return [PSCustomObject]@{RunnerState='DISABLED';VerificationSource=$source;ParseResult='MODE_NOT_ALLOWED'}
    }
    [PSCustomObject]@{RunnerState='UNKNOWN';VerificationSource=$source;ParseResult='UNPARSEABLE_OR_MISSING'}
}

function Get-KRAccessibilityVerification {
    param(
        [AllowNull()][AllowEmptyString()][string]$EnabledServicesOutput,
        [AllowNull()][AllowEmptyString()][string]$AccessibilityEnabledOutput,
        [string]$CandidateService = 'dev.kidremote.spike.enforcement/.EnforcementAccessibilityService'
    )
    $source='SECURE_SETTINGS_CURRENT_USER_COMPONENT_NAME'
    $global=Convert-KRBooleanSetting $AccessibilityEnabledOutput
    $expected=Convert-KRComponentName $CandidateService
    if($null -eq $expected){return [PSCustomObject]@{RunnerState='UNKNOWN';VerificationSource=$source;ParseResult='EXPECTED_COMPONENT_INVALID'}}
    $value=if($null -eq $EnabledServicesOutput){''}else{$EnabledServicesOutput.Trim()}
    $match=$null;$unparseable=$false;$validCount=0
    if(-not [string]::IsNullOrWhiteSpace($value) -and $value -notmatch '^(?i:null)$'){
        foreach($token in @($value -split ':')){
            $component=Convert-KRComponentName $token
            if($null -eq $component){$unparseable=$true;continue}
            $validCount++
            if($component.PackageName -ceq $expected.PackageName -and $component.ClassName -ceq $expected.ClassName){$match=$component}
        }
    }
    if($global -eq 'ENABLED' -and $null -ne $match){
        return [PSCustomObject]@{RunnerState='ENABLED';VerificationSource=$source;ParseResult=('GLOBAL_ENABLED_COMPONENT_MATCH_'+$match.Form)}
    }
    if($global -eq 'UNSPECIFIED'){
        return [PSCustomObject]@{RunnerState='UNKNOWN';VerificationSource=$source;ParseResult='GLOBAL_STATE_UNPARSEABLE_OR_MISSING'}
    }
    if($null -ne $match){
        return [PSCustomObject]@{RunnerState='UNKNOWN';VerificationSource=$source;ParseResult='GLOBAL_COMPONENT_STATE_INCONSISTENT'}
    }
    if($unparseable){
        return [PSCustomObject]@{RunnerState='UNKNOWN';VerificationSource=$source;ParseResult='COMPONENT_LIST_UNPARSEABLE'}
    }
    [PSCustomObject]@{RunnerState='DISABLED';VerificationSource=$source;ParseResult=$(if($validCount -eq 0){'COMPONENT_LIST_EMPTY'}else{'COMPONENT_ABSENT'})}
}

function Get-KRRequiredPermissionVerification {
    param(
        [bool]$CandidateInstalled,
        [AllowNull()][AllowEmptyString()][string]$UsageAccessOutput,
        [AllowNull()][AllowEmptyString()][string]$EnabledServicesOutput,
        [AllowNull()][AllowEmptyString()][string]$AccessibilityEnabledOutput,
        [string]$CandidateService = 'dev.kidremote.spike.enforcement/.EnforcementAccessibilityService'
    )
    if(-not $CandidateInstalled){
        return [PSCustomObject]@{
            UsageAccessRunner='NOT_APPLICABLE';AccessibilityRunner='NOT_APPLICABLE'
            UsageAccessVerificationSource='NOT_APPLICABLE_CANDIDATE_NOT_INSTALLED';AccessibilityVerificationSource='NOT_APPLICABLE_CANDIDATE_NOT_INSTALLED'
            UsageAccessParseResult='NOT_APPLICABLE';AccessibilityParseResult='NOT_APPLICABLE'
        }
    }
    $usage=Get-KRUsageAccessVerification $UsageAccessOutput
    $accessibility=Get-KRAccessibilityVerification $EnabledServicesOutput $AccessibilityEnabledOutput $CandidateService
    [PSCustomObject]@{
        UsageAccessRunner=$usage.RunnerState;AccessibilityRunner=$accessibility.RunnerState
        UsageAccessVerificationSource=$usage.VerificationSource;AccessibilityVerificationSource=$accessibility.VerificationSource
        UsageAccessParseResult=$usage.ParseResult;AccessibilityParseResult=$accessibility.ParseResult
    }
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
    $verification=Get-KRRequiredPermissionVerification $CandidateInstalled $UsageAccessOutput $EnabledServicesOutput $AccessibilityEnabledOutput $CandidateService
    $usage=switch($verification.UsageAccessRunner){'ENABLED'{'GRANTED'}'DISABLED'{'NOT_GRANTED'}default{'UNSPECIFIED'}}
    $accessibility=switch($verification.AccessibilityRunner){'ENABLED'{'GRANTED'}'DISABLED'{'NOT_GRANTED'}default{'UNSPECIFIED'}}
    [PSCustomObject]@{UsageAccess=$usage;AccessibilityService=$accessibility}
}

function New-KRDeviceMetadataRecord {
    param(
        [AllowNull()][string]$Manufacturer,[AllowNull()][string]$Model,[AllowNull()][string]$AndroidVersion,[AllowNull()][string]$ApiLevel,
        [AllowNull()][string]$SecurityPatch,[AllowNull()][string]$BuildId,[AllowNull()][string]$BatterySaver,[AllowNull()][string]$AdaptiveBattery,
        [AllowNull()][string]$AppStandby,[bool]$CandidateInstalled,[AllowNull()][string]$UsageAccessOutput,
        [AllowNull()][string]$EnabledServicesOutput,[AllowNull()][string]$AccessibilityEnabledOutput,
        [string]$CandidateService='dev.kidremote.spike.enforcement/.EnforcementAccessibilityService'
    )
    $verification=Get-KRRequiredPermissionVerification $CandidateInstalled $UsageAccessOutput $EnabledServicesOutput $AccessibilityEnabledOutput $CandidateService
    [PSCustomObject]@{
        Schema=2
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
        RunnerPermissionVerification=$verification
    }
}

function Test-KRDeviceMetadataComplete {
    param($Device)
    if ($null -eq $Device -or $Device.Schema -notin @(1,2)) { return $false }
    foreach($name in @('Manufacturer','Model','AndroidVersion','ApiLevel','SecurityPatch','BuildId')) {
        if ($Device.$name -eq 'UNSPECIFIED') { return $false }
    }
    return $true
}

function New-KRCalibrationPermissionDiagnostic {
    param($RunnerVerification,$Snapshot)
    $unknownRunner=[PSCustomObject]@{
        UsageAccessRunner='UNKNOWN';AccessibilityRunner='UNKNOWN';UsageAccessVerificationSource='UNAVAILABLE'
        AccessibilityVerificationSource='UNAVAILABLE';UsageAccessParseResult='UNAVAILABLE';AccessibilityParseResult='UNAVAILABLE'
    }
    $runner=if($null -eq $RunnerVerification){$unknownRunner}else{$RunnerVerification}
    $names=if($null -eq $Snapshot){@()}else{@($Snapshot.PSObject.Properties.Name)}
    $heartbeat=if('heartbeat' -notin $names -or $Snapshot.heartbeat -isnot [bool]){'UNKNOWN'}elseif($Snapshot.heartbeat){'FRESH'}else{'STALE'}
    $eligible=if('eligible' -notin $names -or $Snapshot.eligible -isnot [bool]){'UNKNOWN'}elseif($Snapshot.eligible){'ELIGIBLE'}else{'INELIGIBLE'}
    $healthRequired=@('usage','accessibility','heartbeat','uncertain','adapter')
    $health=if($null -eq $Snapshot -or @($healthRequired|Where-Object{$_ -notin $names}).Count -gt 0 -or
        $Snapshot.usage -isnot [bool] -or $Snapshot.accessibility -isnot [bool] -or $Snapshot.heartbeat -isnot [bool] -or $Snapshot.uncertain -isnot [bool]){'UNKNOWN'}
        elseif(-not $Snapshot.usage -or -not $Snapshot.accessibility){'PERMISSION_REQUIRED'}
        elseif($Snapshot.uncertain -or -not $Snapshot.heartbeat -or $Snapshot.adapter -ceq 'OVERLAY_FAILED'){'ENFORCEMENT_DEGRADED'}
        else{'HEALTHY'}
    [PSCustomObject]@{
        UsageAccessRunner=$runner.UsageAccessRunner;AccessibilityRunner=$runner.AccessibilityRunner
        ServiceHeartbeat=$heartbeat;CandidateHealth=$health;CandidateEligible=$eligible
        UsageAccessVerificationSource=$runner.UsageAccessVerificationSource;AccessibilityVerificationSource=$runner.AccessibilityVerificationSource
        UsageAccessParseResult=$runner.UsageAccessParseResult;AccessibilityParseResult=$runner.AccessibilityParseResult
    }
}

function Get-KRRequiredPermissionFailure {
    param($Diagnostic,[bool]$PreviouslyEstablished=$false)
    if($Diagnostic.UsageAccessRunner -eq 'UNKNOWN'){return 'INVALID:USAGE_ACCESS_RUNNER_UNKNOWN'}
    if($Diagnostic.UsageAccessRunner -ne 'ENABLED'){return $(if($PreviouslyEstablished){'FAIL:PERMISSION_OR_SERVICE_LOST'}else{'INVALID:USAGE_ACCESS_RUNNER_NOT_ENABLED'})}
    if($Diagnostic.AccessibilityRunner -eq 'UNKNOWN'){return 'INVALID:ACCESSIBILITY_RUNNER_UNKNOWN'}
    if($Diagnostic.AccessibilityRunner -ne 'ENABLED'){return $(if($PreviouslyEstablished){'FAIL:PERMISSION_OR_SERVICE_LOST'}else{'INVALID:ACCESSIBILITY_RUNNER_NOT_ENABLED'})}
    if($Diagnostic.ServiceHeartbeat -eq 'UNKNOWN'){return 'INVALID:SERVICE_HEARTBEAT_UNKNOWN'}
    if($Diagnostic.ServiceHeartbeat -ne 'FRESH'){return $(if($PreviouslyEstablished){'FAIL:PERMISSION_OR_SERVICE_LOST'}else{'INVALID:SERVICE_HEARTBEAT_NOT_FRESH'})}
    if($Diagnostic.CandidateHealth -eq 'UNKNOWN'){return 'INVALID:CANDIDATE_HEALTH_UNKNOWN'}
    if($Diagnostic.CandidateHealth -ne 'HEALTHY'){return $(if($PreviouslyEstablished){'FAIL:PERMISSION_OR_SERVICE_LOST'}else{'INVALID:CANDIDATE_HEALTH_NOT_HEALTHY'})}
    if($Diagnostic.CandidateEligible -eq 'UNKNOWN'){return 'INVALID:CANDIDATE_ELIGIBILITY_UNKNOWN'}
    if($Diagnostic.CandidateEligible -ne 'ELIGIBLE'){return 'INVALID:CANDIDATE_NOT_ELIGIBLE'}
    return $null
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
    return 'FAIL'
}

function Get-KROracleCalibrationVerdict {
    param([bool]$PositiveControl,[bool]$BlockedControl,[bool]$ServiceContinuous,[string]$PhysicalAgreement,[bool]$CleanupVerified,[int]$QualificationSamples)
    if ($QualificationSamples -ne 0 -or $PhysicalAgreement -eq 'INVALID') { return 'INVALID' }
    if (-not $PositiveControl -or -not $BlockedControl -or -not $ServiceContinuous -or $PhysicalAgreement -eq 'FAIL' -or -not $CleanupVerified) { return 'FAIL' }
    if ($PhysicalAgreement -ne 'PASS') { return 'INVALID' }
    return 'PASSED_ORACLE_CALIBRATION_THIS_CONFIGURATION_ONLY'
}

Export-ModuleMember -Function Convert-KRDeviceText, Convert-KRBooleanSetting, Convert-KRComponentName, Get-KRUsageAccessVerification, Get-KRAccessibilityVerification, Get-KRRequiredPermissionVerification, Get-KRRequiredPermissionState, New-KRDeviceMetadataRecord, Test-KRDeviceMetadataComplete, New-KRCalibrationPermissionDiagnostic, Get-KRRequiredPermissionFailure, New-KRDeviceOperationRecord, Get-KRDeviceTransportVerdict, Get-KROracleCalibrationVerdict
