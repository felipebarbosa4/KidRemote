Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'ProductOracle.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'ProductTransport.psm1') -Force
$script:checks=0
function Equal($a,$b){$script:checks++;if($a -cne $b){throw "Assertion $script:checks expected $b got $a"}}
function Reject($action,$message){$caught=$null;try{&$action}catch{$caught=$_.Exception.Message};Equal $caught $message}
function Fixture($focused,$taps){return [pscustomobject]@{schema=2;instance=1;elapsed=10;probeReady=$true;probeX=100;probeY=200;resumed=$true;focused=$focused;focusGains=1;taps=$taps}}
function Run($mode){
 $state=@{locked=$false;taps=0;requests=[Collections.Generic.List[object]]::new();journal=0;mode=$mode}
 $ops=@{
 Preflight={if($state.mode -eq 'preflight'){throw 'INVALID:PROVENANCE_MISMATCH'}}
 Initial={ [pscustomobject]@{device_id='11111111-1111-1111-1111-111111111111';policy_epoch='epoch';version=1;sequence=1;period_key='2026-09-14';manual_lock=$false;restriction_required=$false;remaining_ms=600000;health='UNRESTRICTED_OBSERVED:NONE'} }
 StartFixture={};Pause={};Sync={}
 Fixture={Fixture (-not $state.locked) $state.taps}
 Tap={param($p) if(-not $state.locked -and $state.mode -ne 'positive'){$state.taps++};if($state.locked -and $state.mode -eq 'leak'){$state.taps++}}
 BlockedFixture={if($state.mode -eq 'focus'){Fixture $true $state.taps}else{Fixture $false $state.taps}}
 Journal={param($j) $state.journal++;if($state.mode -eq 'journal' -and $state.journal -eq 1){throw 'INVALID:JOURNAL_WRITE'}}
 Operation={param($q)
   $state.requests.Add($q)
   if($q.kind -eq 'LOCK'){$state.locked=$true;if($state.mode -eq 'lockloss' -and $state.requests.Count -eq 1){throw 'INVALID:HTTP_RESPONSE_LOST'}}
   else{if($state.mode -eq 'cleanup'){throw 'INVALID:UNLOCK_UNAVAILABLE'};if($state.mode -eq 'unlockloss' -and $state.requests.Count -eq 2){throw 'INVALID:HTTP_RESPONSE_LOST'};$state.locked=$false}
   [pscustomobject]@{status='accepted';operation_id=$q.operation_id;device_id=$q.device_id;policy_epoch='epoch';version=$q.expected_version+1}
 }
 Report={param($v,$r) [pscustomobject]@{version=$v;sequence=$v;period_key='2026-09-14';restriction_required=$r;manual_lock=$r;health='OBSERVED:NONE';remaining_ms=600000}}
 Status={return $true}
 }
 $result=Invoke-ProductSlice $ops
 return [pscustomobject]@{result=$result;state=$state}
}
$r=Run 'pass';Equal $r.result.status 'PASS';Equal $r.result.cleanup 'VERIFIED_CANONICAL_UNLOCK_AND_INDEPENDENT_INPUT';Equal $r.state.requests.Count 2
foreach($m in @('preflight','positive','journal')){$r=Run $m;Equal $r.result.status 'INVALID';Equal $r.state.requests.Count 0}
foreach($m in @('leak','focus')){$r=Run $m;Equal $r.result.status 'FAIL';Equal $r.result.cleanup 'VERIFIED_CANONICAL_UNLOCK_AND_INDEPENDENT_INPUT';Equal $r.result.independentBlocked $false}
$r=Run 'lockloss';Equal $r.result.status 'INVALID';Equal $r.result.cleanup 'VERIFIED_CANONICAL_UNLOCK_AND_INDEPENDENT_INPUT';Equal $r.state.requests[0].operation_id $r.state.requests[1].operation_id
$r=Run 'unlockloss';Equal $r.result.status 'INVALID';Equal $r.result.cleanup 'VERIFIED_CANONICAL_UNLOCK_AND_INDEPENDENT_INPUT';Equal $r.state.requests[1].operation_id $r.state.requests[2].operation_id
$r=Run 'cleanup';Equal $r.result.status 'INVALID';Equal $r.result.cleanup 'UNVERIFIED';Equal $r.result.independentRestored $false
$expected=@{Branch='kr-product-enforcement-integration';Source=('a'*40);ChildHash=('b'*64);FixtureHash=('c'*64);Package='dev.kidremote.child.unassigned.debug';Service='dev.kidremote.child.unassigned.debug/dev.kidremote.child.enforcement.ChildEnforcementService';Manufacturer='samsung';Model='SM-X400';Android='16';Api='36';Build='BP4A.251205.006';Patch='2026-07-05';BatterySaver='DISABLED';AppStandby='ENABLED'}
Assert-ProductProvenance $expected $expected
foreach($key in @($expected.Keys)){$actual=$expected.Clone();$actual[$key]='mismatch';Reject {Assert-ProductProvenance $expected $actual} 'INVALID:PROVENANCE_MISMATCH'}
Assert-ProductPermissions 'GET_USAGE_STATS: allow' $expected.Service '1' $expected.Service
Reject {Assert-ProductPermissions 'GET_USAGE_STATS: allow' 'dev.kidremote.spike.enforcement/.EnforcementAccessibilityService' '1' $expected.Service} 'INVALID:PRODUCT_PERMISSION_SETUP_REQUIRED'
Reject {Assert-ProductPermissions 'GET_USAGE_STATS: ignore' $expected.Service '1' $expected.Service} 'INVALID:PRODUCT_PERMISSION_SETUP_REQUIRED'
foreach($cmd in @('shell settings put secure accessibility_enabled 1','install candidate.apk','shell am force-stop dev.kidremote.child.unassigned.debug','shell pm clear dev.kidremote.child.unassigned.debug','shell am broadcast -a ARM','shell screencap /sdcard/x')){Reject {Invoke-ProductAdb 'NONEXISTENT_ADB' 'SYNTHETIC_ONLY' ($cmd.Split(' '))} 'INVALID:ADB_COMMAND_NOT_ALLOWED'}
Reject {Assert-ProductPhysicalReadiness} 'INVALID:PRODUCT_CHILD_TRANSPORT_NOT_VALIDATED'
Reject {& (Join-Path $PSScriptRoot 'Start-ProductOracle.ps1') -Manifest 'DOES_NOT_EXIST'} 'INVALID:PRODUCT_CHILD_TRANSPORT_NOT_VALIDATED'
Reject {New-ProductOperation ('-'*36) ('1'*36) LOCK 1} 'INVALID:OPERATION_ARGUMENT'
Reject {Invoke-ProductHttp 'http://example.invalid' '/rpc/parent_devices' $null @{}} 'INVALID:BACKEND_ORIGIN'
$f=Fixture $true 0
$f|Add-Member request 7
$f|Add-Member focusLosses 0
$f|Add-Member lastFocusChange 1
function Reply($f){'KR003:'+ [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes(($f|ConvertTo-Json -Compress)))}
Equal (Convert-ProductFixture (Reply $f) 7).request 7
Reject {Convert-ProductFixture (Reply $f) 8} 'INVALID:STALE_REPLY'
Reject {Convert-ProductFixture 'unparseable' 7} 'INVALID:MISSING_OR_AMBIGUOUS_REPLY'
Reject {Convert-ProductFixture ((Reply $f)+"`n"+(Reply $f)) 7} 'INVALID:MISSING_OR_AMBIGUOUS_REPLY'
Reject {Convert-ProductFixture ('x'*16385) 7} 'INVALID:FIXTURE_REPLY_SIZE'
$f.probeReady=$false
Reject {Convert-ProductFixture (Reply $f) 7} 'INVALID:FIXTURE_ORACLE_UNAVAILABLE'
$f.probeReady=$true;$f|Add-Member unexpected 'not accepted'
Reject {Convert-ProductFixture (Reply $f) 7} 'INVALID:REPLY_SCHEMA'
$a=Fixture $true 0;$b=Fixture $true 1;$b.instance=2
Reject {Assert-ProductPositive $a $b} 'INVALID:FIXTURE_CHANGED'
Write-Output "PRODUCT_ORACLE_SYNTHETIC_CHECKS=$script:checks; PHYSICAL_EXECUTION=NOT_RUN"
