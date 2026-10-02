Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'ReplacementAdb.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'EnrollmentHost.psm1') -Force
$script:n=0
function Check($b){$script:n++;if(-not $b){throw "TRANSPORT_CHECK_$script:n"}}
function Reject($f){$yes=$false;try{&$f}catch{$yes=$true};Check $yes}
Check ((Get-ReplacementCommand Uninstall '') -join ' ' -ceq 'uninstall dev.kidremote.child.unassigned.debug')
Check ((Get-ReplacementCommand Reverse '') -join ' ' -ceq 'reverse --no-rebind tcp:47366 tcp:47366')
foreach($name in @('Clear','FactoryReset','Grant','SettingsPut','UninstallOther','Root','Reboot','ForceStop','shell input tap 1 1')){Reject {Get-ReplacementCommand $name ''}}
Reject {Get-ReplacementCommand Install 'relative.apk'}
Reject {Invoke-ReplacementAdb 'NOT_REAL' 'x;bad' Uninstall '' {throw 'SHOULD_NOT_RUN'}}
foreach($action in @('Uninstall','Install','Reverse','OpenUsage','OpenAccessibility','OpenChild')){
 if($action -ne 'Install'){
  $run={param($e,$a,$i) [pscustomobject]@{stdout='Failure [SYNTHETIC]';stderr='DENIED'}}
  Reject {Invoke-ReplacementAdb 'NOT_REAL' SYNTHETIC $action '' $run}
 }
}
$r=Invoke-ReplacementAdb 'NOT_REAL' SYNTHETIC Uninstall '' {param($e,$a,$i) [pscustomobject]@{stdout='Success';stderr=''}}
Check ($r -ceq 'Success')
Reject {Invoke-ReplacementAdb 'NOT_REAL' SYNTHETIC Uninstall '' {param($e,$a,$i) [pscustomobject]@{stdout="Success`nSuccess";stderr=''}}}
Assert-LabReverse '' $false;Check $true
Assert-LabReverse "SYNTHETIC tcp:47366 tcp:47366`n" $true;Check $true
foreach($raw in @('SYNTHETIC tcp:47366 tcp:1',"SYNTHETIC tcp:47366 tcp:47366`nSYNTHETIC tcp:47366 tcp:47366",'AMBIGUOUS tcp:47366')){Reject {Assert-LabReverse $raw $true}}
Reject {Assert-LabReverse 'SYNTHETIC tcp:47366 tcp:47366' $false}
$jwt=ConvertTo-SecureString SYNTHETIC -AsPlainText -Force
$q=@{device_id='11111111-1111-4111-8111-111111111111';operation_id='22222222-2222-4222-8222-222222222222';expected_version=1;kind='LOCK'}
foreach($kind in @('LOCK','UNLOCK')){
 $q.kind=$kind;$script:seen=@();$wire={param($s,$p,$m,$b,$j) $script:seen+=,($b|ConvertTo-Json -Compress);if($script:seen.Count -eq 1){throw 'INVALID:HTTP_TIMEOUT_OR_REFUSED'};return @{status='accepted'}}
 $r=Invoke-StableLabOperation $wire $jwt $q
 Check ($script:seen.Count -eq 2 -and $script:seen[0] -ceq $script:seen[1] -and $r.status -ceq 'accepted')
}
foreach($errorCode in @('INVALID:HTTP_401','INVALID:HTTP_403','INVALID:HTTP_409','INVALID:HTTP_JSON')){
 $count=@{n=0};$wire={param($s,$p,$m,$b,$j) $count.n++;throw $errorCode}.GetNewClosure()
 Reject {Invoke-StableLabOperation $wire $jwt $q};Check ($count.n -eq 1)
}
Write-Output "REPLACEMENT_TRANSPORT_CHECKS=$script:n;ADB=FAKE_CALLBACK_ONLY"
