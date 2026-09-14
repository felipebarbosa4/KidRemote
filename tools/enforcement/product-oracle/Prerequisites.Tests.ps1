Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'Journal.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'ReadOnly.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'Canonical.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'ProductOracle.psm1')
$script:n=0
function Eq($a,$b){$script:n++;if($a -cne $b){throw "CHECK_$script:n expected=$b actual=$a"}}
function No($s,$e){$caught='NONE';try{&$s}catch{$caught=$_.Exception.Message};Eq $caught $e}
$root=Join-Path ([IO.Path]::GetTempPath()) ('kr-product-journal-tests-'+[Guid]::NewGuid());[void][IO.Directory]::CreateDirectory($root)
function Journal {New-ProductJournal $root ('a'*40) ('b'*64) ('c'*64) ('d'*64)}
try{
 $d=Journal;Eq (Read-ProductJournal $d).rows.Count 0
 $id=[Guid]::NewGuid().ToString()
 No {Add-ProductJournal $d $id LOCK_ADMITTED EXPECTED_VERSION:1 BEFORE_WRITE} 'INVALID:INJECTED_CRASH'
 Eq (Read-ProductJournal $d).rows.Count 0
 No {Add-ProductJournal $d $id LOCK_ADMITTED EXPECTED_VERSION:1 AFTER_COMMIT} 'INVALID:INJECTED_CRASH'
 Eq (Read-ProductJournal $d).rows.Count 1
 $null=Add-ProductJournal $d $id LOCK_ADMITTED EXPECTED_VERSION:1;Eq (Read-ProductJournal $d).rows.Count 1
 No {Add-ProductJournal $d $id LOCK_ADMITTED EXPECTED_VERSION:2} 'INVALID:JOURNAL_RETRY_CONFLICT'
 $null=Add-ProductJournal $d ([Guid]::NewGuid().ToString()) VERDICT FAIL
 $null=Add-ProductJournal $d ([Guid]::NewGuid().ToString()) CLEANUP UNVERIFIED
 Eq (Read-ProductJournal $d).verdict 'FAIL';Eq (Read-ProductJournal $d).cleanup 'UNVERIFIED'
 No {Add-ProductJournal $d ([Guid]::NewGuid().ToString()) VERDICT PASS} 'INVALID:VERDICT_IMMUTABLE'
 $p=Journal;No {Add-ProductJournal $p $id LOCK_ADMITTED EXPECTED_VERSION:1 TRUNCATE} 'INVALID:INJECTED_CRASH'
 Eq (Read-ProductJournal $p).partial $true;Eq (Read-ProductJournal $p).rows.Count 0
 No {Add-ProductJournal $p $id LOCK_ADMITTED EXPECTED_VERSION:1} 'INVALID:JOURNAL_PARTIAL_REQUIRES_REVIEW'
 Remove-Module Journal;Import-Module (Join-Path $PSScriptRoot 'Journal.psm1') -Force
 Eq (Read-ProductJournal $d).verdict 'FAIL';Eq (Read-ProductJournal $p).partial $true
 No {Add-ProductJournal $d $id OBSERVATION 'Bearer sensitive'} 'INVALID:JOURNAL_SCHEMA'
 $c=Journal;$cb=New-DurableJournalCallback $c
 $j=[pscustomobject]@{attempt=$cb.Attempt;stage='LOCK_ADMITTED';lockId=[Guid]::NewGuid().ToString();unlockId=[Guid]::NewGuid().ToString();cleanupId=[Guid]::NewGuid().ToString();expectedVersion=1;status='FAIL';cleanup='UNVERIFIED'}
 & $cb.Journal $j;Eq (Read-ProductJournal $c).rows[0].value 'EXPECTED_VERSION:1'
 $j.stage='VERDICT';& $cb.Journal $j;$j.stage='UNLOCK_ADMITTED';$j.expectedVersion=2;& $cb.Journal $j
 $j.stage='FINAL';& $cb.Journal $j;Eq (Read-ProductJournal $c).verdict 'FAIL';Eq (Read-ProductJournal $c).cleanup 'UNVERIFIED'
 No {New-DurableJournalCallback $c} 'INVALID:EXISTING_ATTEMPT_REVIEW_REQUIRED'
 $last=Join-Path $c '000003.json';[IO.File]::WriteAllText($last,'{}')
 No {Read-ProductJournal $c} 'INVALID:JOURNAL_CORRUPT'
}finally{# Synthetic test files only, never owner attempt directories.
 Remove-Item -LiteralPath $root -Recurse -Force
}
foreach($cmd in @('install x','shell pm clear dev.kidremote.child.unassigned.debug','shell am force-stop dev.kidremote.child.unassigned.debug','shell am start -n x/y','shell input tap 1 1','reverse tcp:47366 tcp:47366','shell settings put secure accessibility_enabled 1','shell screencap x','reboot','shell svc wifi disable','shell sha256sum /data/app/x/base.apk;reboot')){No {Invoke-InventoryAdb 'DOES_NOT_EXIST' 'SYNTHETIC' ($cmd.Split(' '))} 'INVALID:READ_ONLY_COMMAND_REJECTED'}
Eq (Select-InventoryTarget "List of devices attached`nSYNTHETIC device`n") 'SYNTHETIC'
foreach($s in @('','X unauthorized',"X device`nY device",'emulator-5584 device')){No {Select-InventoryTarget $s} 'INVALID:ONE_AUTHORIZED_TARGET_REQUIRED'}
$script:mode='absent';$script:calls=0
$read={param($a)
 $script:calls++;$line=$a -join ' '
 switch -Regex ($line){
 'am get-current-user$' {return '0'}
 'getprop ro.product.manufacturer$' {return 'samsung'}
 'getprop ro.product.model$' {if($script:mode -eq 'config'){return 'OTHER'};return 'SM-X400'}
 'getprop ro.build.version.release$' {return '16'}
 'getprop ro.build.version.sdk$' {return '36'}
 'getprop ro.build.id$' {return 'BP4A.251205.006'}
 'getprop ro.build.version.security_patch$' {return '2026-07-05'}
 'get global low_power$' {return '0'}
 'get global app_standby_enabled$' {return '1'}
 'pm path' {if($script:mode -in @('absent','retained')){return ''};if($script:mode -eq 'split'){return "package:/data/app/x/base.apk`npackage:/data/app/x/split.apk"};return 'package:/data/app/x/base.apk'}
 'pm list packages -u' {if($script:mode -eq 'absent'){return ''};return ('package:'+$a[-1])}
 'dumpsys package' {return "  versionCode=2 minSdk=28`n  versionName=0.0.2-local`n  User 0: installed=true stopped=false`n dev.kidremote.child.enforcement.ChildEnforcementService"}
 'sha256sum' {if($script:mode -eq 'hashfail'){throw 'PRIVATE_RAW_MUST_NOT_LEAK'};return (('a'*64)+'  /data/app/x/base.apk')}
 'get secure enabled_accessibility_services$' {if($script:mode -eq 'permission'){return 'dev.kidremote.spike.enforcement/.EnforcementAccessibilityService'};return 'dev.kidremote.child.unassigned.debug/dev.kidremote.child.enforcement.ChildEnforcementService'}
 'get secure accessibility_enabled$' {return '1'}
 'appops get' {return 'GET_USAGE_STATS: allow'}
 default {throw 'TEST_UNEXPECTED_READ'}
 }
}
foreach($case in @(@('absent','READY_FOR_INSTALL_REVIEW'),@('retained','PRODUCT_ALREADY_PRESENT_REVIEW_REQUIRED'),@('present','PRODUCT_ALREADY_PRESENT_REVIEW_REQUIRED'),@('permission','PERMISSION_SETUP_REQUIRED'),@('hashfail','PROVENANCE_UNVERIFIED'),@('config','CONFIGURATION_MISMATCH'))){$script:mode=$case[0];$r=Invoke-ReadOnlyInventory $read;Eq $r.classification $case[1];Eq $r.physicalOracle 'BLOCKED'}
$script:mode='present';$r=Invoke-ReadOnlyInventory $read;Eq $r.child.versionCode '2';Eq $r.child.stopped 'false';Eq $r.child.sha256 ('a'*64);Eq $r.child.signerSha256 'UNSPECIFIED'
$script:mode='split';No {Invoke-ReadOnlyInventory $read} 'INVALID:APK_PATH_AMBIGUOUS'
$device='11111111-1111-1111-1111-111111111111';$epoch='22222222-2222-2222-2222-222222222222'
$script:wireMode='normal';$script:requests=[Collections.Generic.List[object]]::new()
$wire={param($service,$path,$method,$body,$jwt)
 if($script:wireMode -in @('401','403','409','timeout','refused','json','outage')){throw ('INVALID:TEST_'+$script:wireMode.ToUpperInvariant())}
 if($path -eq '/rpc/parent_devices'){
  $v=if($script:wireMode -eq 'concurrent'){2}else{1}
  return [pscustomobject]@{protocol_version=1;server_utc='2026-09-14T12:00:00Z';devices=@([pscustomobject]@{id=$device;policy_epoch=$epoch;version=$v;policy_configured=$true;report=[pscustomobject]@{version=1;sequence=1;used_ms=100;remaining_ms=600000;bonus_seconds=0;manual_lock=$false;restriction_required=$false;restriction_applied=$false;health='UNRESTRICTED_OBSERVED:NONE';period_key='1:2026-09-14';received_at=$(if($script:wireMode -eq 'stale'){'2026-09-13T12:00:00Z'}else{'2026-09-14T12:00:00Z'})}})}
 }
 $script:requests.Add($body)
 if($script:wireMode -eq 'lost' -and $script:requests.Count -eq 1){throw 'INVALID:LOST_RESPONSE_AFTER_COMMIT'}
 return [pscustomobject]@{status='accepted';operation_id=$body.operation_id;device_id=$device;policy_epoch=$epoch;version=$body.expected_version+1}
}
$jwt=ConvertTo-SecureString 'SYNTHETIC' -AsPlainText -Force
$ops=New-CanonicalCallbacks $wire $jwt $device $epoch
Eq (& $ops.Initial).version 1
foreach($m in @('401','403','409','timeout','refused','json','outage')){$script:wireMode=$m;No {& $ops.Initial} ('INVALID:TEST_'+$m.ToUpperInvariant())}
foreach($m in @('stale','concurrent')){$script:wireMode=$m;No {& $ops.Initial} 'INVALID:REPORT_STALE_OR_CONCURRENT'}
$script:wireMode='lost';$q=New-ProductOperation ([Guid]::NewGuid().ToString()) $device LOCK 1
No {& $ops.Operation $q} 'INVALID:LOST_RESPONSE_AFTER_COMMIT'
Eq (& $ops.Operation $q).version 2;Eq $script:requests[0].operation_id $script:requests[1].operation_id
Eq ((Get-LabReverseArguments) -join ' ') 'reverse tcp:47366 tcp:47366'
$script:signupEmail=$null
$authWire={param($service,$path,$method,$body,$jwt)
 switch($path){
 '/signup' {$script:signupEmail=$body.email;return @{}}
 '/api/v1/messages' {return [pscustomobject]@{messages=@([pscustomobject]@{ID='test-mail';To=@([pscustomobject]@{Address=$script:signupEmail})})}}
 '/api/v1/message/test-mail' {return [pscustomobject]@{HTML='<a href="http://127.0.0.1:47361/verify?token=abcdef&amp;type=signup">Verify</a>'}}
 '/verify' {if($body.token_hash -cne 'abcdef'){throw 'AUTH_TOKEN'};return [pscustomobject]@{access_token='synthetic.token.signature'}}
 '/rpc/bootstrap_household' {return [pscustomobject]@{household_id='33333333-3333-3333-3333-333333333333'}}
 default {throw 'UNEXPECTED_AUTH_ROUTE'}
 }
}
Eq ((New-LabParent $authWire) -is [Security.SecureString]) $true
Eq ($script:signupEmail -match '^product-lab-[a-f0-9-]+@example.test$') $true
Write-Output "PRODUCT_PREREQUISITES_SYNTHETIC_CHECKS=$script:n;DEVICE_COMMANDS=NONE"
