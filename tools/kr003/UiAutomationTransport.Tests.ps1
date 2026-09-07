# Goal: exercise the real tiny runner orchestration without Android calls.
# Context: input acceptance cannot substitute for fixture delivery. Constraints: fixed synthetic replies/temp files only.
# Done when: pass, denial, wrong count, stale reply, partial/host error and cleanup-result paths are checked.
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'Qualification.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'OracleTransport.psm1') -Force
$script:Checks=0
function Assert-Equal($Actual,$Expected) { $script:Checks++; if($Actual -cne $Expected){throw "Expected $Expected; got $Actual"} }
function Assert-Reject([scriptblock]$Action,[string]$Expected) { $caught=$null; try{&$Action}catch{$caught=$_.Exception.Message}; Assert-Equal $caught $Expected }
$ok="INSTRUMENTATION_RESULT: kr003_probe=v1,12,COMPLETE,INJECTED,true,true,FRAMEWORK_FINISH`r`nINSTRUMENTATION_CODE: -1`r`n"
Assert-Equal (Convert-KRUiAutomationReply $ok 12).Outcome 'INJECTED'
Assert-Reject { Convert-KRUiAutomationReply $ok 13 } 'INVALID:PROBE_REQUEST'
Assert-Reject { Convert-KRUiAutomationReply ($ok+$ok) 12 } 'INVALID:PROBE_REPLY'
Assert-Reject { Convert-KRUiAutomationReply ($ok.Replace('INSTRUMENTATION_CODE: -1','')) 12 } 'INVALID:PROBE_FINISH'
Assert-Reject { Convert-KRUiAutomationReply ($ok.Replace('INJECTED','raw detail')) 12 } 'INVALID:PROBE_REPLY'

$tokens=$null;$errors=$null
$ast=[Management.Automation.Language.Parser]::ParseFile((Join-Path $PSScriptRoot 'Test-KR003-UiAutomationTransport.ps1'),[ref]$tokens,[ref]$errors)
Assert-Equal $errors.Count 0
foreach($fn in $ast.FindAll({param($n) $n -is [Management.Automation.Language.FunctionDefinitionAst]},$false)) { Invoke-Expression $fn.Extent.Text }
$mainTry=@($ast.EndBlock.Statements | Where-Object {$_ -is [Management.Automation.Language.TryStatementAst]})
Assert-Equal $mainTry.Count 1
# ScriptBlock.Create has no file-origin automatic PSScriptRoot; supply only that path binding.
$script:TestRunnerRoot=$PSScriptRoot
$caseScript=[scriptblock]::Create($mainTry[0].Extent.Text.Replace('$PSScriptRoot','$script:TestRunnerRoot'))
$temporaryRoot=Join-Path ([IO.Path]::GetTempPath()) ('kr003-uiauto-synthetic-'+[Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $temporaryRoot | Out-Null
# Never call a real executable. The existing file is used only by Test-Path.
$Adb=$PSCommandPath
$fixtureActivity='synthetic-fixture'; $fixtureReceiver='synthetic-receiver'
function Get-Content {
    param([string]$LiteralPath,[switch]$Raw)
    if ($LiteralPath.EndsWith('bundle.json')) {
        return '{"schema":1,"protocol":"KR003-UIAUTOMATION-TRANSPORT-PREFLIGHT","runnerVersion":1,"diagnosticOnly":true,"files":[],"sourceCommit":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","fixtureSha256":"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb","probeSha256":"cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc"}'
    }
    throw 'UNEXPECTED_READ_IN_SYNTHETIC_CASE'
}
function Invoke-TransportAdb {
    param([string]$Category,[string[]]$Arguments)
    $script:Calls+= $Category
    if($script:Scenario -eq 'host-error' -and $Category -eq 'FIXTURE_INSTALL'){throw 'synthetic private detail'}
    $script:Operations+= New-KRTransportOperationRecord $Category 0 'NONE'
    switch($Category) {
        'DEVICE_STATE' { return 'device' }
        'FIXTURE_INSTALL' { return '' }
        'PROBE_INSTALL' { return '' }
        'FIXTURE_OPEN' { return '' }
        'UIAUTOMATION_TAP' {
            Assert-Equal (($Arguments[0..3]) -join ' ') 'shell am instrument -w'
            $script:Tapped=$true
            $requestIndex=[Array]::IndexOf($Arguments,'request')+1
            $requestNumber=[long]$Arguments[$requestIndex]
            if($script:Scenario -eq 'stale'){ $requestNumber++ }
            $result=if($script:Scenario -eq 'security'){'DOWN,SECURITY_EXCEPTION,false,false,FRAMEWORK_FINISH'}else{'COMPLETE,INJECTED,true,true,FRAMEWORK_FINISH'}
            $code=if($script:Scenario -eq 'security'){'0'}else{'-1'}
            if($script:Scenario -eq 'no-finish'){ return "INSTRUMENTATION_RESULT: kr003_probe=v1,$requestNumber,$result`r`n" }
            return "INSTRUMENTATION_RESULT: kr003_probe=v1,$requestNumber,$result`r`nINSTRUMENTATION_CODE: $code`r`n"
        }
        'FIXTURE_STATE' {
            $count=4
            if($script:Tapped -and $script:Scenario -notin @('no-delivery','security')){$count++}
            if($script:Tapped -and $script:Scenario -eq 'double'){$count++}
            $instance=100; if($script:Tapped -and $script:Scenario -eq 'replacement'){$instance++}
            $focused= -not($script:Tapped -and $script:Scenario -eq 'focus-loss')
            $state=@{schema=2;request=$script:Request;elapsed=200;instance=$instance;focused=$focused;resumed=$true;taps=$count;focusGains=1;focusLosses=0;lastFocusChange=100;probeReady=$true;probeX=540;probeY=1956}
            $encoded=[Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes((ConvertTo-Json $state -Compress)))
            return ('Broadcast completed: result=0, data="KR003:'+$encoded+'"')
        }
        default { throw 'UNEXPECTED_DEVICE_OPERATION' }
    }
}
try {
    foreach($scenario in @('pass','security','no-delivery','double','stale','no-finish','replacement','focus-loss','host-error')) {
        $script:Scenario=$scenario; $script:Calls=@(); $script:Tapped=$false
        $runDirectory=Join-Path $temporaryRoot $scenario
        $script:Operations=@();$script:Request=0L;$script:RejectedOperation=$null;$script:RejectedExitCode=$null;$script:RejectedStderrClass=$null
        $script:ReceiverWorked=$false;$script:BeforeTaps=$null;$script:AfterTaps=$null;$script:Status='INVALID';$script:Reason='NOT_STARTED'
        $script:Bundle=$null;$script:ProbeResult=$null;$startedUtc=[DateTime]::UtcNow.ToString('o')
        . $caseScript 6>$null
        $summary=Microsoft.PowerShell.Management\Get-Content -LiteralPath (Join-Path $runDirectory 'summary.json') -Raw | ConvertFrom-Json
        Assert-Equal $summary.Q7Samples 0
        Assert-Equal $summary.RestrictionChanged $false
        Assert-Equal $summary.RadiosChanged $false
        $expected=switch($scenario){
            'pass' {'PASSED_TRANSPORT_PREFLIGHT:FIXTURE_COUNTER_INCREMENTED_ONCE'}
            'security' {'INVALID:UIAUTOMATION_INJECTION_OR_CLEANUP'}
            'no-delivery' {'FAIL:INPUT_NOT_DELIVERED'}
            'double' {'FAIL:INPUT_NOT_DELIVERED'}
            'stale' {'INVALID:PROBE_REQUEST'}
            'no-finish' {'INVALID:PROBE_FINISH'}
            'replacement' {'INVALID:FIXTURE_CHANGED'}
            'focus-loss' {'INVALID:FIXTURE_LOST_FOCUS'}
            'host-error' {'INVALID:HOST_EXCEPTION'}
        }
        Assert-Equal ($summary.Status+':'+$summary.Reason) $expected
        Assert-Equal @($script:Calls|Where-Object {$_ -eq 'UIAUTOMATION_TAP'}).Count $(if($scenario -eq 'host-error'){0}else{1})
        if($scenario -eq 'security') { Assert-Equal $summary.ProbeResult.Outcome 'SECURITY_EXCEPTION' }
    }
} finally {
    Remove-Item -LiteralPath $temporaryRoot -Recurse -Force
}
Write-Host "$script:Checks UiAutomation parser/orchestration assertions passed; device calls were stubbed."
