Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'

$script:CalibrationHostStages=@(
    'STARTUP','BUNDLE_HASH_VERIFICATION','TRANSPORT_EVIDENCE_INGESTION','ADB_PREFLIGHT','DEVICE_METADATA',
    'APK_VERIFICATION','CANDIDATE_INITIALIZATION','CANDIDATE_STATE_QUERY','PERMISSION_VERIFICATION','FIXTURE_POSITIVE_CONTROL',
    'PRE_ARM_PERMISSION_VERIFICATION','ARM','WAIT_FOR_ATTACHMENT','FIXTURE_ORACLE_QUERY','BLOCKED_HOLD',
    'POST_HOLD_PERMISSION_VERIFICATION','OWNER_PROMPT','CLEANUP','FINALIZATION','COMPLETED'
)
$script:CalibrationCleanupStatuses=@('NOT_ATTEMPTED','NOT_REQUIRED','IN_PROGRESS','VERIFIED','FAILED')
$script:CalibrationFinalizationStatuses=@('NOT_STARTED','IN_PROGRESS','COMPLETED','FAILED')

function New-KRCalibrationHostState {
    [PSCustomObject]@{
        CurrentStage='STARTUP';HostStage='STARTUP';ExceptionClass='NONE';PrimaryReason='INVALID:NOT_STARTED'
        FinalizationStatus='NOT_STARTED';CleanupStatus='NOT_ATTEMPTED'
    }
}

function Set-KRCalibrationHostStage {
    param($State,[string]$Stage)
    if($Stage -notin $script:CalibrationHostStages){throw 'INVALID:HOST_STAGE_ENUM'}
    $State.CurrentStage=$Stage
}

function Get-KRCalibrationExceptionClass {
    param($ErrorRecord)
    if($null -eq $ErrorRecord -or $null -eq $ErrorRecord.Exception){return 'OTHER_HOST_EXCEPTION'}
    $message=[string]$ErrorRecord.Exception.Message
    if($message -match '^(FAIL|INVALID):[A-Z0-9_]+$'){return 'TYPED_RUNNER_RESULT'}
    $id=[string]$ErrorRecord.FullyQualifiedErrorId
    if($id -match 'PropertyNotFound'){return 'PROPERTY_NOT_FOUND_EXCEPTION'}
    if($id -match 'ParameterBinding'){return 'PARAMETER_BINDING_EXCEPTION'}
    if($id -match 'MethodInvocation'){return 'METHOD_INVOCATION_EXCEPTION'}
    $exception=$ErrorRecord.Exception
    if($exception -is [Management.Automation.PipelineStoppedException]){return 'PIPELINE_STOPPED_EXCEPTION'}
    if($exception -is [UnauthorizedAccessException]){return 'UNAUTHORIZED_ACCESS_EXCEPTION'}
    if($exception -is [IO.IOException]){return 'IO_EXCEPTION'}
    if($exception -is [TimeoutException]){return 'TIMEOUT_EXCEPTION'}
    if($exception -is [ArgumentException]){return 'ARGUMENT_EXCEPTION'}
    if($exception -is [InvalidOperationException]){return 'INVALID_OPERATION_EXCEPTION'}
    if($exception -is [Management.Automation.RuntimeException]){return 'POWERSHELL_RUNTIME_EXCEPTION'}
    return 'OTHER_HOST_EXCEPTION'
}

function Set-KRCalibrationHostFailure {
    param($State,$ErrorRecord,[string]$PrimaryReason)
    $message=[string]$ErrorRecord.Exception.Message
    if([string]::IsNullOrWhiteSpace($PrimaryReason)){
        $PrimaryReason=$(if($message -match '^(FAIL|INVALID):[A-Z0-9_]+$'){$message}else{'INVALID:HOST_EXCEPTION'})
    }
    if($PrimaryReason -notmatch '^(FAIL|INVALID):[A-Z0-9_]+$'){throw 'INVALID:PRIMARY_REASON_ENUM'}
    $State.HostStage=$State.CurrentStage
    $State.ExceptionClass=Get-KRCalibrationExceptionClass $ErrorRecord
    $State.PrimaryReason=$PrimaryReason
}

function Set-KRCalibrationCleanupStatus {
    param($State,[string]$Status)
    if($Status -notin $script:CalibrationCleanupStatuses){throw 'INVALID:CLEANUP_STATUS_ENUM'}
    $State.CleanupStatus=$Status
}

function Set-KRCalibrationFinalizationStatus {
    param($State,[string]$Status)
    if($Status -notin $script:CalibrationFinalizationStatuses){throw 'INVALID:FINALIZATION_STATUS_ENUM'}
    $State.FinalizationStatus=$Status
}

function Set-KRCalibrationCleanupFailure {
    param($State,$ErrorRecord,[bool]$PreservePrimary)
    Set-KRCalibrationCleanupStatus $State 'FAILED'
    if(-not $PreservePrimary){
        Set-KRCalibrationHostStage $State 'CLEANUP'
        Set-KRCalibrationHostFailure $State $ErrorRecord 'FAIL:CLEANUP_NOT_VERIFIED'
    }
}

function Set-KRCalibrationFinalizationFailure {
    param($State,$ErrorRecord,[bool]$PreservePrimary)
    Set-KRCalibrationFinalizationStatus $State 'FAILED'
    if(-not $PreservePrimary){
        Set-KRCalibrationHostStage $State 'FINALIZATION'
        Set-KRCalibrationHostFailure $State $ErrorRecord
    }
}

function Get-KRCalibrationHostDiagnostic {
    param($State)
    [PSCustomObject]@{
        Schema=1;HostStage=$State.HostStage;ExceptionClass=$State.ExceptionClass;PrimaryReason=$State.PrimaryReason
        FinalizationStatus=$State.FinalizationStatus;CleanupStatus=$State.CleanupStatus
    }
}

Export-ModuleMember -Function New-KRCalibrationHostState, Set-KRCalibrationHostStage, Get-KRCalibrationExceptionClass, Set-KRCalibrationHostFailure, Set-KRCalibrationCleanupStatus, Set-KRCalibrationFinalizationStatus, Set-KRCalibrationCleanupFailure, Set-KRCalibrationFinalizationFailure, Get-KRCalibrationHostDiagnostic
