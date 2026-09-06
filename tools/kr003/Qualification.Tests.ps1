Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'Qualification.psm1') -Force
$script:Checks = 0
function Assert-Equal($Actual, $Expected) {
    $script:Checks++
    if ($Actual -cne $Expected) { throw "Expected $Expected; received $Actual" }
}
function Assert-Reject([scriptblock]$Action, [string]$Expected) {
    $caught = $null
    try { & $Action | Out-Null } catch { $caught = $_.Exception.Message }
    Assert-Equal $caught $Expected
}
function Encode-Reply($Value) {
    'Broadcast completed: result=0, data="KR003:' + [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes(($Value | ConvertTo-Json -Depth 8 -Compress))) + '"'
}
function New-Snapshot {
    [PSCustomObject]@{
        schema=1; request=1; elapsed=20000; versionCode=1; versionName='0.0.1-spike'; api=29
        revision=2; remaining=0; armed=$true; restriction=$true; uncertain=$false
        usage=$true; accessibility=$true; heartbeat=$true; eligible=$true; adapter='APPLIED'
        sampledAt=19990; sampledRevision=2; disposition='ORDINARY_APP'; attached=$true
        eligibilityLost=$false; firstAttachedAt=10100; removals=0; recordedRevision=2
        samples=@(123); sampleCount=1; p50=123; p95=123; max=123; traceHead=0; traceLost=$false; events=@()
    }
}

Assert-Equal (Get-KRStatistics @()).Count 0
Assert-Equal (Get-KRStatistics @(1..100)).P95 95
Assert-Equal (Get-KRStatistics @(263,1,123)).P50 123
Assert-Reject { Get-KRStatistics @(-1) } 'INVALID:NEGATIVE_LATENCY'
$s = New-Snapshot
Assert-Equal (Convert-KRReply (Encode-Reply $s) 1).sampleCount 1
Assert-Reject { Convert-KRReply (Encode-Reply $s) 2 } 'INVALID:STALE_REPLY'
Assert-Reject { Convert-KRReply '--------- beginning of main' 1 } 'INVALID:MISSING_OR_AMBIGUOUS_REPLY'
Assert-Reject { Convert-KRReply ((Encode-Reply $s) + (Encode-Reply $s)) 1 } 'INVALID:MISSING_OR_AMBIGUOUS_REPLY'
$s | Add-Member NoteProperty personalText 'should be rejected'
Assert-Reject { Convert-KRReply (Encode-Reply $s) 1 } 'INVALID:REPLY_SCHEMA'
$s = New-Snapshot
$s.events=@([PSCustomObject]@{sequence=1;line='personal app text'})
$s.traceHead=1
Assert-Reject { Convert-KRReply (Encode-Reply $s) 1 } 'INVALID:UNSANITIZED_TRACE'
$s = New-Snapshot
$s.samples=@('123')
Assert-Reject { Convert-KRReply (Encode-Reply $s) 1 } 'INVALID:LATENCY_TYPE'
$s = New-Snapshot
Assert-Equal (Get-KRPairedLatency $s 2 @()) 123
Assert-Reject { Get-KRPairedLatency $s 4 @() } 'INVALID:UNPAIRED_LATENCY'
$s.samples=@(5,123); $s.sampleCount=2
Assert-Reject { Get-KRPairedLatency $s 2 @(6) } 'FAIL:LATENCY_HISTORY_CHANGED'
$s = New-Snapshot
$f = [PSCustomObject]@{focused=$false;taps=0}
Assert-KRHold $s 2 0 $f
$s.removals=1
Assert-Reject { Assert-KRHold $s 2 0 $f } 'FAIL:RESTRICTION_LOST'
$s = New-Snapshot; $s.heartbeat=$false
Assert-Reject { Assert-KRHold $s 2 0 $f } 'FAIL:PERMISSION_OR_SERVICE_LOST'
$s = New-Snapshot; $s.eligibilityLost=$true
Assert-Reject { Assert-KRHold $s 2 0 $f } 'INVALID:ELIGIBILITY_INTERRUPTED'
$s = New-Snapshot; $f.focused=$true
Assert-Reject { Assert-KRHold $s 2 0 $f } 'FAIL:ORDINARY_FIXTURE_ACTIVE'
Assert-Reject { Assert-KRHealth $s 20001 } 'FAIL:CLOCK_DISCONTINUITY'

$rows = @(1..100 | ForEach-Object { [PSCustomObject]@{Revision=$_;Observer='UNRECORDED';Automated='PASS';LatencyMs=123} })
Assert-Equal (Get-KRRunVerdict $rows $true $true) 'INCOMPLETE'
$rows | ForEach-Object { $_.Observer='PASS' }
Assert-Equal (Get-KRRunVerdict $rows $true $true) 'PASSED_THIS_CONFIGURATION_ONLY'
Assert-Equal (Get-KRRunVerdict $rows $true $false) 'ONLINE_ONLY_OFFLINE_GATE_OPEN'
Assert-Equal (Get-KRRunVerdict $rows[0..98] $true $true) 'INCOMPLETE'
Assert-Equal (Get-KRRunVerdict $rows $false $true) 'INCOMPLETE'
$rows[99].Revision=1
Assert-Equal (Get-KRRunVerdict $rows $true $true) 'INCOMPLETE'
$rows[99].Revision=100
$rows[99].Observer='FAIL'
Assert-Equal (Get-KRRunVerdict $rows $true $true) 'FAILED'
$rows[99].Observer='PASS'
# Five slow valid samples leave nearest rank 95 at 123. Six slow samples exceed the gate.
94..99 | ForEach-Object { $rows[$_].LatencyMs=2001 }
Assert-Equal (Get-KRRunVerdict $rows $true $true) 'FAILED_P95'
$rows[94].LatencyMs=123
Assert-Equal (Get-KRRunVerdict $rows $true $true) 'PASSED_THIS_CONFIGURATION_ONLY'

# Parse the actual operator script without executing any device commands.
$tokens=$null; $parseErrors=$null
$ast=[Management.Automation.Language.Parser]::ParseFile((Join-Path $PSScriptRoot 'Start-KR003.ps1'),[ref]$tokens,[ref]$parseErrors)
Assert-Equal $parseErrors.Count 0
$topLevelExits=@($ast.EndBlock.Statements | Where-Object { $_ -is [Management.Automation.Language.ExitStatementAst] })
Assert-Equal $topLevelExits.Count 1
Assert-Equal ($topLevelExits[0].Extent.StartOffset -gt ($ast.EndBlock.Statements | Where-Object { $_ -is [Management.Automation.Language.TryStatementAst] })[-1].Extent.EndOffset) $true

# Exercise actual process argument binding with portable PowerShell as a harmless subprocess, never ADB.
$processAst=$ast.Find({param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq 'Invoke-LabAdb'},$true)
Invoke-Expression $processAst.Extent.Text
$Adb=Join-Path $PSHOME 'pwsh'
Assert-Equal (Invoke-LabAdb @('-NoProfile','-Command','Write-Output synthetic')).Trim() 'synthetic'
Assert-Reject { Invoke-LabAdb @('unsafe"argument') } 'INVALID:ADB_ARGUMENT'

# Reversible network setup is tested only with in-memory command stubs, never a device.
foreach($name in @('Enter-OfflineNetwork','Restore-Network')) {
    $fn=$ast.Find({param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq $name},$true)
    Invoke-Expression $fn.Extent.Text
}
$script:NetworkCommands=@()
function Invoke-LabAdb { param($Arguments) $script:NetworkCommands+=($Arguments -join ' '); return '' }
function Wait-RadioFlag { param($Key,$Expected) }
function Write-JsonFile { param($Name,$Value) }
function Read-DeviceConfiguration { [PSCustomObject]@{wifi_on='0';mobile_data='0'} }
$script:RadioTouched=@(); $script:RadioRestoreStatus='NOT_CHANGED'
$script:Device=[PSCustomObject]@{wifi_on='1';mobile_data='0'}
Enter-OfflineNetwork
Restore-Network
Assert-Equal ($script:NetworkCommands -join ',') 'shell svc wifi disable,shell svc wifi enable'
Assert-Equal $script:RadioRestoreStatus 'RESTORED_AND_FLAGS_VERIFIED'
$script:Device=[PSCustomObject]@{wifi_on='UNSPECIFIED';mobile_data='1'}
Assert-Reject { Enter-OfflineNetwork } 'INVALID:RADIO_INITIAL_STATE_UNKNOWN'

$focusAst=$ast.Find({param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq 'Wait-FixtureFocus'},$true)
Invoke-Expression $focusAst.Extent.Text
$script:FocusQueries=0
function Get-FixtureState { $script:FocusQueries++; [PSCustomObject]@{focused=($script:FocusQueries -gt 1);resumed=$true} }
function Check-EarlyStop {}
function Start-Sleep {}
Assert-Equal (Wait-FixtureFocus -Focused $true).focused $true
Assert-Equal $script:FocusQueries 2

# Exercise actual cycle orchestration with deterministic synthetic snapshots and an independent observer stub.
# These tests do not write a physical evidence manifest or use ADB.
$functionAst=$ast.Find({param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq 'Invoke-Expiry'},$true)
Invoke-Expression $functionAst.Extent.Text
function Save-Progress {}
function Clear-ToOrdinary {}
function Wait-FixtureFocus { param($Focused) }
function Assert-FixedSettings {}
function Check-EarlyStop {}
function Start-Sleep {}
function Get-FixtureState { [PSCustomObject]@{focused=$false;taps=0} }
function Wait-LabCondition {
    param($Condition,$FailureCode,$TimeoutSeconds)
    $s=New-Snapshot
    $s.revision=$script:SimRevision
    $s.sampledRevision=$script:SimRevision
    $s.recordedRevision=$script:SimRevision
    $s.samples=@($script:SimSamples)
    $s.sampleCount=$s.samples.Count
    $script:SimElapsed=20000
    return $s
}
function Get-LabState {
    param($Operation='SNAPSHOT')
    $s=New-Snapshot
    if($Operation -eq 'ARM') {
        $script:SimRevision++; $script:SimSamples+=123; $s.remaining=10000
        $script:AttachmentRevisions[[string]$script:SimRevision]=1
    }
    $s.revision=$script:SimRevision; $s.sampledRevision=$script:SimRevision; $s.recordedRevision=$script:SimRevision
    $s.samples=@($script:SimSamples); $s.sampleCount=$s.samples.Count
    $script:SimElapsed+=5000; $s.elapsed=$script:SimElapsed; $s.sampledAt=$s.elapsed-10
    return $s
}
function Read-Result {
    param($Prompt)
    if($script:SimObserver -ne 'PASS') { throw 'FAIL:OBSERVER_1' }
    return 'PASS'
}
$script:SimRevision=1; $script:SimSamples=@(); $script:SimElapsed=0
$script:LastRevision=-1; $script:Rows=@(); $script:CurrentRow=$null; $script:SimObserver='PASS'
$script:AttachmentRevisions=@{}
1..100 | ForEach-Object { Invoke-Expiry -Attempt $_ 6>$null }
Assert-Equal $script:Rows.Count 100
Assert-Equal (Get-KRRunVerdict $script:Rows $true $true) 'PASSED_THIS_CONFIGURATION_ONLY'
$script:SimObserver='FAIL'
Assert-Reject { Invoke-Expiry -Attempt 101 6>$null } 'FAIL:OBSERVER_1'
Assert-Equal $script:Rows.Count 100
Assert-Equal $script:CurrentRow.Observer 'UNRECORDED'
Write-Host "$script:Checks PowerShell assertions passed; orchestration used synthetic state, never a device."
