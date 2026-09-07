<#
Goal: Test one Monkey touch event in a separate shell process with an independent fixture counter.
Context: The Mi 8 rejects shell input with SECURITY_EXCEPTION; its security-debug switch is disabled and SIM-gated.
Constraints: Fixture only; no candidate command, restriction, radio/permission/configuration change, raw stderr/stdout evidence or destructive action.
Done when: The fixture receiver works and exactly one injected tap increments its independent counter, or the rejected operation is safely classified.
#>
param([string]$Adb='C:\platform-tools\adb.exe',[string]$OutputRoot='C:\platform-tools\kr003-monkey-transport')
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'Qualification.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'OracleTransport.psm1') -Force

$fixturePackage='dev.kidremote.spike.ordinary'
$fixtureReceiver="$fixturePackage/.FixtureReceiver"
$fixtureActivity="$fixturePackage/.FixtureActivity"
$runId='transport-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '-' + [Guid]::NewGuid().ToString('N').Substring(0,8)
$runDirectory=Join-Path $OutputRoot $runId
$script:Operations=@(); $script:Request=0L
$script:RejectedOperation=$null; $script:RejectedExitCode=$null; $script:RejectedStderrClass=$null
$script:ReceiverWorked=$false; $script:BeforeTaps=$null; $script:AfterTaps=$null
$script:Status='INVALID'; $script:Reason='NOT_STARTED'
$script:Bundle=$null; $script:ProbeResult=$null
$script:HelperPushAttempted=$false; $script:HelperCleanup='NOT_NEEDED'
$remoteApk='/data/local/tmp/kr003-monkey-'+[Guid]::NewGuid().ToString('N')+'.apk'
$startedUtc=[DateTime]::UtcNow.ToString('o')

function Write-TransportJson([string]$Name,$Value) {
    [IO.File]::WriteAllText((Join-Path $runDirectory $Name),(ConvertTo-Json -InputObject $Value -Depth 12),(New-Object Text.UTF8Encoding($false)))
}
function Save-TransportOperations { Write-TransportJson 'operations.json' @($script:Operations) }

function Invoke-TransportAdb {
    param([string]$Category,[string[]]$Arguments)
    $process=New-Object Diagnostics.Process
    $process.StartInfo=New-Object Diagnostics.ProcessStartInfo
    $process.StartInfo.FileName=$Adb
    $process.StartInfo.UseShellExecute=$false
    $process.StartInfo.RedirectStandardOutput=$true
    $process.StartInfo.RedirectStandardError=$true
    $process.StartInfo.CreateNoWindow=$true
    $quoted=foreach($argument in $Arguments) {
        if ($argument.Contains('"') -or $argument.Contains([string][char]13) -or $argument.Contains([string][char]10) -or $argument.EndsWith('\')) { throw 'INVALID:ADB_ARGUMENT' }
        '"' + $argument + '"'
    }
    $process.StartInfo.Arguments=$quoted -join ' '
    try {
        [void]$process.Start()
        $stdoutTask=$process.StandardOutput.ReadToEndAsync(); $stderrTask=$process.StandardError.ReadToEndAsync()
        if (-not $process.WaitForExit(30000)) {
            $process.Kill()
            $script:Operations += New-KRTransportOperationRecord $Category -1 'OTHER'; Save-TransportOperations
            $script:RejectedOperation=$Category; $script:RejectedExitCode=-1; $script:RejectedStderrClass='OTHER'
            throw 'INVALID:ADB_TIMEOUT'
        }
        $stdout=$stdoutTask.GetAwaiter().GetResult(); $stderr=$stderrTask.GetAwaiter().GetResult()
        $stderrClass=Get-KRTransportStderrClass $stderr
        $script:Operations += New-KRTransportOperationRecord $Category $process.ExitCode $stderrClass
        Save-TransportOperations
        if ($process.ExitCode -ne 0 -or $stderrClass -in @('SECURITY_EXCEPTION','PERMISSION_DENIAL')) {
            $script:RejectedOperation=$Category; $script:RejectedExitCode=$process.ExitCode; $script:RejectedStderrClass=$stderrClass
            throw 'INVALID:ADB_OPERATION_REJECTED'
        }
        return $stdout
    } finally { $process.Dispose() }
}

function Get-TransportFixtureState {
    $script:Request++
    $raw=Invoke-TransportAdb 'FIXTURE_STATE' @('shell','am','broadcast','--receiver-foreground','-n',$fixtureReceiver,'--el','request',"$script:Request")
    $state=Convert-KRReply -Raw $raw -Request $script:Request -Fixture
    if ($state.schema -ne 2) { throw 'INVALID:FIXTURE_SCHEMA' }
    $script:ReceiverWorked=$true
    return $state
}

try {
    New-Item -ItemType Directory -Path $runDirectory | Out-Null
    if (-not (Test-Path -LiteralPath $Adb)) { throw 'INVALID:ADB_MISSING' }
    $script:Bundle=Get-Content -LiteralPath (Join-Path $PSScriptRoot 'bundle.json') -Raw | ConvertFrom-Json
    if ($script:Bundle.schema -ne 1 -or $script:Bundle.protocol -ne 'KR003-MONKEY-TRANSPORT-PREFLIGHT' -or $script:Bundle.runnerVersion -ne 1 -or -not $script:Bundle.diagnosticOnly) { throw 'INVALID:BUNDLE_SCHEMA' }
    foreach($entry in $script:Bundle.files) {
        if ($entry.name -notmatch '^[A-Za-z0-9_.-]+$') { throw 'INVALID:BUNDLE_PATH' }
        if ((Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $PSScriptRoot $entry.name)).Hash.ToLowerInvariant() -cne $entry.sha256) { throw 'INVALID:BUNDLE_INTEGRITY' }
    }
    if ((Invoke-TransportAdb 'DEVICE_STATE' @('get-state')).Trim() -ne 'device') { throw 'INVALID:DEVICE_UNAVAILABLE' }
    $null=Invoke-TransportAdb 'FIXTURE_INSTALL' @('install','-r',(Join-Path $PSScriptRoot 'ordinary-fixture.apk'))
    $null=Invoke-TransportAdb 'MONKEY_TOOL_CHECK' @('shell','test','-r','/system/framework/monkey.jar')
    $script:HelperPushAttempted=$true
    $null=Invoke-TransportAdb 'HELPER_PUSH' @('push',(Join-Path $PSScriptRoot 'input-probe.apk'),$remoteApk)
    $null=Invoke-TransportAdb 'FIXTURE_OPEN' @('shell','am','start','-n',$fixtureActivity)
    $watch=[Diagnostics.Stopwatch]::StartNew()
    do {
        $before=Get-TransportFixtureState
        if ($before.probeReady -and $before.focused -and $before.resumed) { break }
        Start-Sleep -Milliseconds 100
    } while($watch.Elapsed.TotalSeconds -lt 5)
    if (-not $before.probeReady -or -not $before.focused -or -not $before.resumed) { throw 'INVALID:FIXTURE_NOT_READY' }
    $script:BeforeTaps=[long]$before.taps
    Write-TransportJson 'fixture-before.json' $before
    $probeRequest=Get-Random -Minimum 1 -Maximum 2147483647
    $probeRaw=Invoke-TransportAdb 'MONKEY_TOUCH' @('shell','/system/bin/toybox','timeout','-k','2','15','env',('CLASSPATH='+$remoteApk+':/system/framework/monkey.jar'),'app_process','/system/bin','dev.kidremote.spike.inputprobe.MonkeyTouchMain',([string]$before.probeX),([string]$before.probeY),([string]$probeRequest))
    $script:ProbeResult=Convert-KRMonkeyReply $probeRaw $probeRequest
    Write-TransportJson 'probe.json' $script:ProbeResult
    $watch=[Diagnostics.Stopwatch]::StartNew()
    do {
        $after=Get-TransportFixtureState
        Write-TransportJson 'fixture-after.json' $after
        if ($after.instance -ne $before.instance -or $after.probeX -ne $before.probeX -or $after.probeY -ne $before.probeY) { throw 'INVALID:FIXTURE_CHANGED' }
        $script:AfterTaps=[long]$after.taps
        if ($script:AfterTaps -ne $script:BeforeTaps) { break }
        Start-Sleep -Milliseconds 100
    } while($watch.Elapsed.TotalSeconds -lt 3)
    if ($script:ProbeResult.Outcome -ne 'INJECTED' -or -not $script:ProbeResult.DownAccepted -or -not $script:ProbeResult.UpAccepted) {
        throw 'INVALID:MONKEY_INJECTION'
    }
    if (-not $after.focused -or -not $after.resumed -or -not $after.probeReady) { throw 'INVALID:FIXTURE_LOST_FOCUS' }
    $script:Status=Get-KRTransportVerdict $script:ReceiverWorked $script:BeforeTaps $script:AfterTaps $script:RejectedOperation
    if ($script:Status -ne 'PASSED_TRANSPORT_PREFLIGHT') { throw 'FAIL:INPUT_NOT_DELIVERED' }
    $script:Reason='FIXTURE_COUNTER_INCREMENTED_ONCE'
} catch {
    $message=$_.Exception.Message
    if ($message -notmatch '^(FAIL|INVALID):[A-Z0-9_]+$') { $message='INVALID:HOST_EXCEPTION' }
    $parts=$message.Split(':'); $script:Status=$parts[0]; $script:Reason=$parts[1]
} finally {
    if ($script:HelperPushAttempted) {
        $rejectedBefore=@($script:RejectedOperation,$script:RejectedExitCode,$script:RejectedStderrClass)
        try {
            if ($remoteApk -notmatch '^/data/local/tmp/kr003-monkey-[a-f0-9]{32}\.apk$') { throw 'INVALID:HELPER_PATH' }
            $null=Invoke-TransportAdb 'HELPER_REMOVE' @('shell','rm','-f',$remoteApk)
            $null=Invoke-TransportAdb 'HELPER_ABSENCE' @('shell','test','!','-e',$remoteApk)
            $script:HelperCleanup='REMOVED_AND_VERIFIED'
        } catch {
            $script:HelperCleanup='UNVERIFIED'
            if ($script:Status -eq 'PASSED_TRANSPORT_PREFLIGHT') { $script:Status='INVALID'; $script:Reason='HELPER_CLEANUP' }
        } finally {
            $script:RejectedOperation=$rejectedBefore[0]; $script:RejectedExitCode=$rejectedBefore[1]; $script:RejectedStderrClass=$rejectedBefore[2]
        }
    }
    if (Test-Path -LiteralPath $runDirectory) {
        try { Save-TransportOperations } catch { }
        $summary=[PSCustomObject]@{
            Protocol='KR003-MONKEY-TRANSPORT-PREFLIGHT'; Status=$script:Status; Reason=$script:Reason
            SourceCommit=$(if($null -eq $script:Bundle){$null}else{$script:Bundle.sourceCommit})
            HelperSha256=$(if($null -eq $script:Bundle){$null}else{$script:Bundle.helperSha256})
            HelperCleanup=$script:HelperCleanup
            ProbeResult=$script:ProbeResult
            FixtureSha256=$(if($null -eq $script:Bundle){$null}else{$script:Bundle.fixtureSha256})
            StartedUtc=$startedUtc; EndedUtc=[DateTime]::UtcNow.ToString('o')
            FixtureReceiverWorked=$script:ReceiverWorked; BeforeTaps=$script:BeforeTaps; AfterTaps=$script:AfterTaps
            CounterIncremented=$(if($null -eq $script:BeforeTaps -or $null -eq $script:AfterTaps){$false}else{$script:AfterTaps -eq $script:BeforeTaps+1})
            RejectedOperation=$script:RejectedOperation; RejectedExitCode=$script:RejectedExitCode; RejectedStderrClass=$script:RejectedStderrClass
            RestrictionChanged=$false; RadiosChanged=$false; PermissionsChanged=$false; DestructiveAction=$false; Q7Samples=0
        }
        try { Write-TransportJson 'summary.json' $summary } catch { }
        Write-Host ('Evidence saved: ' + $runDirectory); Write-Host ('Primary result: ' + $script:Status + ':' + $script:Reason)
        if ($null -ne $script:RejectedOperation) { Write-Host ('Rejected operation: ' + $script:RejectedOperation + '; exit=' + $script:RejectedExitCode + '; stderrClass=' + $script:RejectedStderrClass) }
    }
}
if ($script:Status -eq 'PASSED_TRANSPORT_PREFLIGHT') { exit 0 }
exit 2
