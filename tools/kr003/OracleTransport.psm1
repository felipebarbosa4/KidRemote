Set-StrictMode -Version Latest

function Get-KRTransportStderrClass {
    param([AllowEmptyString()][string]$Stderr)
    if ([string]::IsNullOrWhiteSpace($Stderr)) { return 'NONE' }
    if ($Stderr -match '(?i)SecurityException') { return 'SECURITY_EXCEPTION' }
    if ($Stderr -match '(?i)Permission[ :_-]+Denied|Permission Denial') { return 'PERMISSION_DENIAL' }
    return 'OTHER'
}

function New-KRTransportOperationRecord {
    param([string]$Category, [int]$ExitCode, [string]$StderrClass)
    $categories=@('DEVICE_STATE','FIXTURE_INSTALL','FIXTURE_OPEN','FIXTURE_STATE','INPUT_TAP')
    if ($Category -notin $categories) { throw 'INVALID:TRANSPORT_OPERATION_CATEGORY' }
    if ($StderrClass -notin @('NONE','SECURITY_EXCEPTION','PERMISSION_DENIAL','OTHER')) { throw 'INVALID:TRANSPORT_STDERR_CLASS' }
    [PSCustomObject]@{ OperationCategory=$Category; ExitCode=$ExitCode; StderrClass=$StderrClass }
}

function Get-KRTransportVerdict {
    param([bool]$ReceiverWorked, [long]$BeforeTaps, [long]$AfterTaps, [AllowNull()][string]$RejectedOperation)
    if (-not [string]::IsNullOrEmpty($RejectedOperation)) { return 'INVALID' }
    if (-not $ReceiverWorked) { return 'INVALID' }
    if ($AfterTaps -eq $BeforeTaps + 1) { return 'PASSED_TRANSPORT_PREFLIGHT' }
    return 'FAILED'
}

Export-ModuleMember -Function Get-KRTransportStderrClass, New-KRTransportOperationRecord, Get-KRTransportVerdict
