# Native orchestration test double ONLY. Copied to a synthetic bundle; never imported by production.
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
function Write-MockEvent($Name){Add-Content -LiteralPath $env:KR_SYNC_TEST_LOG -Value $Name}
function Test-Path {
 param([string]$LiteralPath,[string]$Path,[string]$PathType)
 if($LiteralPath -ceq 'C:\platform-tools\adb.exe'){return $true}
 Microsoft.PowerShell.Management\Test-Path @PSBoundParameters
}
function Get-Od51RetryScript {return 'SYNTHETIC_FIXED_SCRIPT'}
function Select-Od51Target($Raw){return 'SYNTHETIC_TARGET'}
function Get-Od51AdbText($R,$Absent=$false){return $R.stdout}
function Invoke-Od51Adb($Adb,$Serial,$Arguments,$InputText,$Fixed,$Pull=''){
 Write-MockEvent ('READ_'+$Arguments[0])
 if($Arguments[0] -ceq 'pull'){[IO.File]::WriteAllText($Arguments[2],'SYNTHETIC_APK')}
 $s=if($Arguments[0] -ceq 'reverse' -and $env:KR_SYNC_TEST_MODE -ceq 'reverse'){'SYNTHETIC_TARGET tcp:47366 tcp:47366'}else{''}
 return [pscustomobject]@{exitCode=0;stdout=$s;stderrPresent=$false;outputTooLarge=$false}
}
function Get-Od51Configuration($Read){return [pscustomobject]@{manufacturer='samsung';model='SM-X400';android='16';api='36';build='BP4A.251205.006';securityPatch='2026-07-05'}}
function Get-Od51Package($Package,$Read){return [pscustomobject]@{installed=$true;sha256=('a'*64);basePath='/data/app/synthetic/base.apk';versionCode='2';versionName='0.0.2-local-physical-lab'}}
function Assert-Od51PullResult($R,$P,$A){}
function Assert-Od51LocalApk($P,$A,$H){}
function Get-Od51Signer($Java,$Jar,$Apk){if($env:KR_SYNC_TEST_MODE -ceq 'signer'){return 'b'*64};return 'c'*64}
function Convert-Od51RetryProcessResult($Raw){return [pscustomobject]@{status=$(if($env:KR_SYNC_TEST_MODE -ceq 'retry'){'INVALID'}else{'OBSERVED'});checksumValidity='VALID';schemaValidity='VALID';pending=$true;stopped=$false;reason='NONE';delayMs=0;attemptCount=0;failureCode='NONE'}}
function Assert-LabReverse([string]$Raw,[bool]$Present){if([bool]$Raw.Trim() -ne $Present){throw 'INVALID:SYNC_REVERSE_MISMATCH'}}
function Start-ProductBackend($Root,$Bundle,$Source,[switch]$RequireExisting){
 if(-not $RequireExisting){throw 'INVALID:TEST_RETAINED_REQUIRED'};Write-MockEvent 'BACKEND_START'
 $review=[IO.File]::ReadAllText((Join-Path $Root 'docs/test-plans/evidence/PRODUCT-INITIAL-REPORT-TIMEOUT-2026-09-30.json'))|ConvertFrom-Json
 $id=$review.backendObservation.review.devices[0].id;$epoch=$review.backendObservation.review.devices[0].epoch
 if($env:KR_SYNC_TEST_MODE -ceq 'retained'){$id='33333333-3333-4333-8333-333333333333'}
 return @{local=[pscustomobject]@{device=[pscustomobject]@{id=$id;policy_epoch=$epoch}};review=[pscustomobject]@{owners=1;households=1;devices=@([pscustomobject]@{id=$id;epoch=$epoch;configured=$true;manualLock=$false;usable=$true});sessions=@()};jwt=(ConvertTo-SecureString 'SYNTHETIC_TOKEN' -AsPlainText -Force);process=[pscustomobject]@{HasExited=$false}}
}
function Stop-ProductBackend($Backend){Write-MockEvent 'BACKEND_STOP';return 'STOPPED_SYNTHETIC_LEASE_AND_ENROLLMENT_RETAINED'}
function Invoke-LabWire($Service,$Path,$Method,$Body,$Jwt){
 if($Service -cne 'rest' -or $Path -cne '/rpc/parent_devices' -or $Method -cne 'POST' -or @($Body.Keys).Count -ne 1 -or $null -ne $Body.p_after){throw 'INVALID:TEST_NETWORK_SCOPE'}
 $count=if(Microsoft.PowerShell.Management\Test-Path -LiteralPath $env:KR_SYNC_TEST_COUNT){[int][IO.File]::ReadAllText($env:KR_SYNC_TEST_COUNT)}else{0}
 [IO.File]::WriteAllText($env:KR_SYNC_TEST_COUNT,[string]($count+1));Write-MockEvent 'PARENT_READ'
 if($count -gt 0 -and $env:KR_SYNC_TEST_MODE -ceq 'readFailure'){throw 'INVALID:HTTP_503'}
 $p=[IO.File]::ReadAllText($env:KR_SYNC_TEST_PAGE)|ConvertFrom-Json
 if($env:KR_SYNC_TEST_MODE -ceq 'badpolicy'){$p.devices[0].version=2}
 if($count -eq 0){$p.devices[0].report=$null}
 return $p
}
function Invoke-ReviewProcess($Exe,$Arguments,$InputText){
 $line=($Arguments|Select-Object -Skip 2) -join ' '
 switch -Exact ($line){
 'reverse --list' {return [pscustomobject]@{stdout=$(if(Microsoft.PowerShell.Management\Test-Path -LiteralPath $env:KR_SYNC_TEST_TUNNEL){'SYNTHETIC_TARGET tcp:47366 tcp:47366'}else{''});stderr=''}}
 'reverse --no-rebind tcp:47366 tcp:47366' {Write-MockEvent 'CONNECT';if($env:KR_SYNC_TEST_MODE -ceq 'connect'){throw 'INVALID:SYNC_CREATE_FAILED'};[IO.File]::WriteAllText($env:KR_SYNC_TEST_TUNNEL,'OWNED');return [pscustomobject]@{stdout='';stderr=''}}
 'reverse --remove tcp:47366' {Write-MockEvent 'DISCONNECT';if($env:KR_SYNC_TEST_MODE -ceq 'disconnect'){throw 'INVALID:SYNC_REMOVE_FAILED'};Remove-Item -LiteralPath $env:KR_SYNC_TEST_TUNNEL;return [pscustomobject]@{stdout='';stderr=''}}
 'shell am start -W -n dev.kidremote.child.unassigned.debug/dev.kidremote.child.ChildActivity' {Write-MockEvent 'RESUME';if($env:KR_SYNC_TEST_MODE -ceq 'resume'){throw 'INVALID:SYNC_LAUNCH_FAILED'};return [pscustomobject]@{stdout='Status: ok';stderr=''}}
 default {throw 'INVALID:TEST_ADB_SCOPE'}
 }
}
Export-ModuleMember -Function *
