Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'Journal.psm1')
$n=0;function Check([bool]$v){$script:n++;if(-not $v){throw "SYNC_NATIVE_CHECK_$script:n"}}
$root=Join-Path ([IO.Path]::GetTempPath()) ('kr-sync-native-'+[Guid]::NewGuid());[void][IO.Directory]::CreateDirectory($root)
$prior=@{};foreach($k in @('LOCALAPPDATA','KR_SYNC_TEST_MODE','KR_SYNC_TEST_LOG','KR_SYNC_TEST_PAGE','KR_SYNC_TEST_COUNT','KR_SYNC_TEST_TUNNEL')){$prior[$k]=[Environment]::GetEnvironmentVariable($k)}
try{
 $bundle=Join-Path $root 'bundle';$src=Join-Path $bundle 'source';[void][IO.Directory]::CreateDirectory($src)
 Copy-Item -LiteralPath (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path -Destination (Join-Path $src 'tools') -Recurse
 $modules=Join-Path $src 'tools/enforcement/product-oracle'
 Copy-Item (Join-Path $PSScriptRoot 'Observe-SyncReadiness.ps1') (Join-Path $bundle 'Observe-SyncReadiness.ps1')
 $fake=Join-Path $PSScriptRoot 'SyncReadinessFixture.psm1'
 foreach($name in @('BackendHost','Canonical','ReplacementAdb')){Copy-Item $fake (Join-Path $modules ($name+'.psm1')) -Force}
 foreach($name in @('MetadataObservation','SyncRetryDiagnostic')){Copy-Item $fake (Join-Path $src ('tools/enforcement/metadata-observation/'+$name+'.psm1')) -Force}
 Copy-Item $fake (Join-Path $src 'tools/enforcement/update-review/Review.psm1') -Force
 $template=Join-Path $root 'history';$jdir=New-ProductJournal $template ('a'*40) ('b'*64) ('c'*64) ('d'*64)
 $id=Split-Path $jdir -Leaf
 foreach($stage in @('BEGIN','PAIRING_CLEANUP_ADMITTED','REVERSE_ADMITTED','ENROLLMENT_ADMITTED','SETUP_ADMITTED','POLICY_ADMITTED','VERDICT','CLEANUP')){
  $value=switch($stage){'BEGIN'{'STARTED'} 'VERDICT'{'INVALID'} 'CLEANUP'{'NOT_REQUIRED'} default{'OD51_FIXED_SCOPE'}}
  $null=Add-ProductJournal $jdir ([Guid]::NewGuid().ToString()) $stage $value
 }
 $inventory=@{};foreach($f in Get-ChildItem -LiteralPath $jdir -File){$inventory[$f.Name]=(Get-FileHash $f.FullName).Hash.ToLowerInvariant()}
 $device='11111111-1111-4111-8111-111111111111';$epoch='22222222-2222-4222-8222-222222222222'
 $review=@{attempt=$id;observedResult=@{primaryReason='INITIAL_REPORT_TIMEOUT'};durableJournal=@{inventory=$inventory;rows=(Read-ProductJournal $jdir).rows};backendObservation=@{review=@{devices=@(@{id=$device;epoch=$epoch});sessions=@()}}}
 $evidence=Join-Path $src 'docs/test-plans/evidence';[void][IO.Directory]::CreateDirectory($evidence)
 [IO.File]::WriteAllText((Join-Path $evidence 'PRODUCT-INITIAL-REPORT-TIMEOUT-2026-09-30.json'),($review|ConvertTo-Json -Depth 10))
 $files=@(Get-ChildItem $bundle -File -Recurse|ForEach-Object{@{name=$_.FullName.Substring($bundle.Length+1).Replace('\','/');sha256=(Get-FileHash $_.FullName).Hash.ToLowerInvariant()}})
 $m=@{scope='OD51_RETAINED_SYNC_READINESS';source=('e'*40);readiness='READY_FOR_ONE_OWNER_RUN';files=$files;observation=@{maximumMs=360000;initialMs=30000};samsung=@{manufacturer='samsung';model='SM-X400';android='16';api='36';build='BP4A.251205.006';patch='2026-07-05'};lab=@{sha256=('a'*64);signer=('c'*64);versionCode=2;versionName='0.0.2-local-physical-lab'};fixture=@{sha256=('a'*64)}}
 $manifest=Join-Path $bundle 'bundle.json';[IO.File]::WriteAllText($manifest,($m|ConvertTo-Json -Depth 8));$hash=(Get-FileHash $manifest).Hash.ToLowerInvariant()
 $page=@{protocol_version=1;server_utc='2026-10-01T18:00:00Z';devices=@(@{id=$device;policy_epoch=$epoch;revoked=$false;policy_configured=$true;version=1;daily_limit_seconds=3600;period_key='1:2026-10-01';report=@{version=1;sequence=1;period_key='1:2026-10-01';received_at='2026-10-01T18:00:00Z';used_ms=0;remaining_ms=3600000;bonus_seconds=0;manual_lock=$false;restriction_required=$false;restriction_applied=$false;health='ENFORCEMENT_UNAVAILABLE:NONE'}})}
 $env:KR_SYNC_TEST_PAGE=Join-Path $root 'page.json';[IO.File]::WriteAllText($env:KR_SYNC_TEST_PAGE,($page|ConvertTo-Json -Depth 8))
 $shell=Join-Path $PSHOME $(if($PSVersionTable.PSEdition -ceq 'Core'){'pwsh.exe'}else{'powershell.exe'})
 function Run-Entry {
  $p=New-Object Diagnostics.Process;$p.StartInfo.FileName=$shell;$p.StartInfo.UseShellExecute=$false;$p.StartInfo.CreateNoWindow=$true;$p.StartInfo.RedirectStandardOutput=$true;$p.StartInfo.RedirectStandardError=$true
  $p.StartInfo.Arguments='-NoProfile -ExecutionPolicy Bypass -File "'+(Join-Path $bundle 'Observe-SyncReadiness.ps1')+'" -ExpectedManifestHash '+$hash
  try{[void]$p.Start();$stdout=$p.StandardOutput.ReadToEndAsync();$stderr=$p.StandardError.ReadToEndAsync();if(-not $p.WaitForExit(30000)){$p.Kill();throw 'NATIVE_TEST_TIMEOUT'};$text=$stdout.GetAwaiter().GetResult();$err=$stderr.GetAwaiter().GetResult();Check (-not $err.Trim());Check ($text -notmatch 'SYNTHETIC_TOKEN|SYNTHETIC_TARGET|PRIVATE_');$at=$text.IndexOf('{');Check ($at -ge 0);return $text.Substring($at)|ConvertFrom-Json}finally{$p.Dispose()}
 }
 foreach($mode in @('success','badpolicy','signer','retry','retained','reverse','connect','resume','readFailure','disconnect')){
  $env:KR_SYNC_TEST_MODE=$mode;$env:LOCALAPPDATA=Join-Path $root $mode;$kid=Join-Path $env:LOCALAPPDATA 'KidRemote'
  $h=Join-Path $kid 'product-slice-attempts';[void][IO.Directory]::CreateDirectory($h);Copy-Item -LiteralPath $jdir -Destination (Join-Path $h $id) -Recurse
  $lease=Join-Path $kid 'physical-lab';[void][IO.Directory]::CreateDirectory($lease)
  foreach($f in @('lease.dpapi','resources.json')){[IO.File]::WriteAllText((Join-Path $lease $f),'SYNTHETIC_NOT_DECRYPTED')}
  $env:KR_SYNC_TEST_LOG=Join-Path $env:LOCALAPPDATA 'calls';$env:KR_SYNC_TEST_COUNT=Join-Path $env:LOCALAPPDATA 'count';$env:KR_SYNC_TEST_TUNNEL=Join-Path $env:LOCALAPPDATA 'tunnel'
  $result=Run-Entry;$r=$result.result;$calls=@(Get-Content -LiteralPath $env:KR_SYNC_TEST_LOG)
  Check ($r.scope -ceq 'OD51_RETAINED_SYNC_READINESS');Check (-not $r.physicalEnforcementAcceptance);Check ($r.targetPolicyOperationsSent -eq 0);Check ($r.targetEnrollmentOperationsSent -eq 0);Check (-not $r.directPrivateWrites)
  Check ($r.historicalEvidence -ceq 'VERIFIED_UNCHANGED')
  if($mode -ceq 'success'){Check ($r.status -ceq 'OBSERVED');Check ($r.observation.finding -ceq 'FRESH_AUTHENTICATED_REPORT');Check ($r.reverseCleanup -ceq 'OWN_REVERSE_REMOVED');Check ($r.backendCleanup -ceq 'STOPPED_SYNTHETIC_LEASE_AND_ENROLLMENT_RETAINED')}
  else{Check ($r.status -ceq 'INVALID')}
  if($mode -in @('badpolicy','signer','retry','retained','reverse')){Check ($calls -cnotcontains 'CONNECT')}
  if($mode -in @('signer','retry','reverse')){Check ($calls -cnotcontains 'BACKEND_START')}
  if($mode -in @('success','resume','readFailure','disconnect')){Check ($calls -ccontains 'DISCONNECT');Check ($calls -ccontains 'BACKEND_STOP')}
  if($mode -ceq 'connect'){Check ($r.reverseCleanup -ceq 'UNVERIFIED');Check ($calls -cnotcontains 'DISCONNECT')}
  $codes=@{badpolicy='SYNC_POLICY_CHANGED';signer='SYNC_SIGNER_MISMATCH';retry='SYNC_RETRY_UNVERIFIED';retained='SYNC_RETAINED_DEVICE_CHANGED';reverse='SYNC_REVERSE_MISMATCH';connect='SYNC_CREATE_FAILED';resume='SYNC_LAUNCH_FAILED';readFailure='HTTP_503'}
  if($codes.ContainsKey($mode)){Check ($r.failureCode -ceq $codes[$mode])}
  if($mode -ceq 'disconnect'){Check ($r.reverseCleanup -ceq 'UNVERIFIED');Check ($r.observation.status -ceq 'OBSERVED');Check ($r.failureCode -ceq 'SYNC_REVERSE_CLEANUP_UNVERIFIED')}
  foreach($f in Get-ChildItem (Join-Path $h $id) -File){Check ((Get-FileHash $f.FullName).Hash.ToLowerInvariant() -ceq $inventory[$f.Name])}
  $saved=Join-Path $kid ('sync-readiness-attempts/'+$result.attempt+'/result.json');Check (Test-Path -LiteralPath $saved)
  Check (([IO.File]::ReadAllText($saved)) -notmatch 'SYNTHETIC_TOKEN|SYNTHETIC_TARGET|PRIVATE_')
  if($mode -ceq 'success'){
   $before=[IO.File]::ReadAllText($env:KR_SYNC_TEST_LOG);$repeat=Run-Entry
   Check ($repeat.result.failureCode -ceq 'PRIOR_SYNC_READINESS_REVIEW_REQUIRED')
   Check ([IO.File]::ReadAllText($env:KR_SYNC_TEST_LOG) -ceq $before)
  }
 }
 # Bad bundle/history must be rejected without another boundary call.
 $unchangedCalls=[IO.File]::ReadAllText($env:KR_SYNC_TEST_LOG)
 $goodHash=$hash;$hash='f'*64;$bad=Run-Entry;$hash=$goodHash
 Check ($bad.result.failureCode -ceq 'SYNC_BUNDLE_HASH')
 Check ([IO.File]::ReadAllText($env:KR_SYNC_TEST_LOG) -ceq $unchangedCalls)
 $stateFile=Join-Path $h ($id+'/000000.json');$originalBytes=[IO.File]::ReadAllBytes($stateFile)
 try{
  [IO.File]::WriteAllText($stateFile,'{}');$bad=Run-Entry
  Check ($bad.result.status -ceq 'INVALID');Check ($bad.result.failureStage -ceq 'HISTORY_VERIFY')
  Check ([IO.File]::ReadAllText($env:KR_SYNC_TEST_LOG) -ceq $unchangedCalls)
 }finally{[IO.File]::WriteAllBytes($stateFile,$originalBytes)}
 Write-Output "SYNC_READINESS_NATIVE_CHECKS=$n;SHELL=$($PSVersionTable.PSEdition);ALL_BOUNDARIES=TEST_DOUBLES;DEVICE=NOT_INVOKED"
}finally{
 foreach($k in $prior.Keys){[Environment]::SetEnvironmentVariable($k,$prior[$k])}
 Remove-Item -LiteralPath $root -Recurse -Force
}
