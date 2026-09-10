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
    $categories=@('DEVICE_STATE','FIXTURE_INSTALL','FIXTURE_OPEN','FIXTURE_STATE','INPUT_TAP','PROBE_INSTALL','UIAUTOMATION_TAP','MONKEY_TOOL_CHECK','HELPER_PUSH','MONKEY_TOUCH','HELPER_REMOVE','HELPER_ABSENCE')
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

function Convert-KRUiAutomationReply {
    param([string]$Raw, [long]$Request)
    $pattern='(?m)^INSTRUMENTATION_RESULT: kr003_probe=v1,([0-9]+),(ARGUMENTS|CONNECT|CONFIGURE|DOWN|UP|COMPLETE),(INVALID_ARGUMENTS|CONNECT_UNAVAILABLE|INJECTED|INPUT_REJECTED|SECURITY_EXCEPTION|OTHER),(true|false),(true|false),(FRAMEWORK_FINISH)\r?$'
    $matchesFound=[regex]::Matches($Raw,$pattern)
    if ($matchesFound.Count -ne 1 -or ([regex]::Matches($Raw,'kr003_probe=')).Count -ne 1) { throw 'INVALID:PROBE_REPLY' }
    $m=$matchesFound[0]
    if ([long]$m.Groups[1].Value -ne $Request) { throw 'INVALID:PROBE_REQUEST' }
    $expectedCode=if($m.Groups[3].Value -eq 'INJECTED'){'-1'}else{'0'}
    if (([regex]::Matches($Raw,'(?m)^INSTRUMENTATION_CODE: '+$expectedCode+'\r?$')).Count -ne 1 -or ([regex]::Matches($Raw,'INSTRUMENTATION_CODE:')).Count -ne 1) { throw 'INVALID:PROBE_FINISH' }
    [PSCustomObject]@{ Request=$Request; Stage=$m.Groups[2].Value; Outcome=$m.Groups[3].Value; DownAccepted=($m.Groups[4].Value -eq 'true'); UpAccepted=($m.Groups[5].Value -eq 'true'); Cleanup=$m.Groups[6].Value }
}

function Convert-KRMonkeyReply {
    param([string]$Raw,[long]$Request)
    $pattern='(?m)^KR003_MONKEY:v1,([0-9]+),(ARGUMENTS|RESOLVE|DOWN|UP|COMPLETE),(INJECTED|INPUT_REJECTED|SECURITY_EXCEPTION|UNSUPPORTED|OTHER|INVALID_ARGUMENTS),(true|false),(true|false)\r?$'
    $found=[regex]::Matches($Raw,$pattern)
    if($found.Count -ne 1 -or ([regex]::Matches($Raw,'KR003_MONKEY:')).Count -ne 1){throw 'INVALID:MONKEY_REPLY'}
    $m=$found[0]
    if([long]$m.Groups[1].Value -ne $Request){throw 'INVALID:MONKEY_REQUEST'}
    [PSCustomObject]@{Request=$Request;Stage=$m.Groups[2].Value;Outcome=$m.Groups[3].Value;DownAccepted=($m.Groups[4].Value -eq 'true');UpAccepted=($m.Groups[5].Value -eq 'true')}
}

Export-ModuleMember -Function Get-KRTransportStderrClass, New-KRTransportOperationRecord, Get-KRTransportVerdict, Convert-KRUiAutomationReply, Convert-KRMonkeyReply
