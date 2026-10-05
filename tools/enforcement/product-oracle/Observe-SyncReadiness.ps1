param([string]$Adb='C:\platform-tools\adb.exe',[Parameter(Mandatory=$true)][string]$ExpectedManifestHash)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
# One retained-state diagnostic. Not a product trial and not read-only: normal app sync may persist policy.
$stage='BUNDLE_VERIFY';$backend=$null;$backendStarted=$false;$serial=$null;$tmp=$null;$dir=$null;$source='UNSPECIFIED'
$reverseAttempted=$false;$reverseOwned=$false;$reverseCleanup='NOT_CREATED';$backendCleanup='NOT_STARTED';$tempCleanup='NOT_CREATED';$history=$null
$out=[ordered]@{scope='OD51_RETAINED_SYNC_READINESS';status='INVALID';failureStage='NONE';failureCode='NONE';retry=$null;observation=$null;directPrivateWrites=$false;targetPolicyOperationsSent=0;targetEnrollmentOperationsSent=0;physicalEnforcementAcceptance=$false;historicalEvidence='NOT_CHECKED';deviceMayPersistExistingPolicy=$true;privateReadScope='SYNC_RETRY_ONLY';privateContentRetained=$false;backendHealthScope='SEPARATE_SYNTHETIC_PROBE_ACCOUNT'}
try{
 $manifestPath=Join-Path $PSScriptRoot 'bundle.json'
 if($ExpectedManifestHash -cnotmatch '^[a-f0-9]{64}$' -or (Get-FileHash -LiteralPath $manifestPath -Algorithm SHA256).Hash.ToLowerInvariant() -cne $ExpectedManifestHash){throw 'INVALID:SYNC_BUNDLE_HASH'}
 $m=[IO.File]::ReadAllText($manifestPath)|ConvertFrom-Json
 if($m.scope -cne 'OD51_RETAINED_SYNC_READINESS' -or $m.source -cnotmatch '^[a-f0-9]{40}$' -or $m.readiness -cne 'READY_FOR_ONE_OWNER_RUN' -or $m.observation.maximumMs -ne 360000 -or $m.observation.initialMs -ne 30000 -or $m.files.Count -lt 10 -or $m.files.Count -gt 5000){throw 'INVALID:SYNC_BUNDLE_SCHEMA'}
 $seen=@{};$actual=@(Get-ChildItem -LiteralPath $PSScriptRoot -Recurse -File|Where-Object{$_.FullName -cne $manifestPath})
 if($actual.Count -ne $m.files.Count -or (Test-Path (Join-Path $PSScriptRoot '.incomplete'))){throw 'INVALID:SYNC_BUNDLE_INVENTORY'}
 foreach($f in $m.files){
  if($f.name -cnotmatch '^[A-Za-z0-9_./-]+$' -or $f.name -match '(^|/)\.\.?(/|$)' -or $seen.ContainsKey($f.name) -or $f.sha256 -cnotmatch '^[a-f0-9]{64}$'){throw 'INVALID:SYNC_BUNDLE_SCHEMA'}
  $p=Join-Path $PSScriptRoot $f.name;$item=Get-Item -LiteralPath $p -Force
  if($item.PSIsContainer -or ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -or (Get-FileHash -LiteralPath $p -Algorithm SHA256).Hash.ToLowerInvariant() -cne $f.sha256){throw 'INVALID:SYNC_BUNDLE_FILE'};$seen[$f.name]=$true
 }
 $source=$m.source;$sourceRoot=Join-Path $PSScriptRoot 'source';$modules=Join-Path $sourceRoot 'tools/enforcement/product-oracle'
 foreach($n in @('SyncReadiness','BackendHost','Canonical','ReplacementAdb')){Import-Module (Join-Path $modules ($n+'.psm1'))}
 Import-Module (Join-Path $sourceRoot 'tools/enforcement/metadata-observation/MetadataObservation.psm1')
 Import-Module (Join-Path $sourceRoot 'tools/enforcement/metadata-observation/SyncRetryDiagnostic.psm1')
 Import-Module (Join-Path $sourceRoot 'tools/enforcement/update-review/Review.psm1')
 if($Adb -cne 'C:\platform-tools\adb.exe' -or -not(Test-Path -LiteralPath $Adb)){throw 'INVALID:SYNC_FIXED_ADB_REQUIRED'}
 $review=[IO.File]::ReadAllText((Join-Path $sourceRoot 'docs/test-plans/evidence/PRODUCT-INITIAL-REPORT-TIMEOUT-2026-09-30.json'))|ConvertFrom-Json
 $expected=[pscustomobject]@{id=$review.backendObservation.review.devices[0].id;epoch=$review.backendObservation.review.devices[0].epoch;version=1;limit=3600}
 $stage='HISTORY_VERIFY';$historyRoot=Join-Path $env:LOCALAPPDATA 'KidRemote\product-slice-attempts';$history=Assert-SyncReadinessHistory $historyRoot $review
 $out.historicalEvidence='VERIFIED_UNCHANGED'
 $attempts=Join-Path $env:LOCALAPPDATA 'KidRemote\sync-readiness-attempts';[void][IO.Directory]::CreateDirectory($attempts)
 if(@(Get-ChildItem -LiteralPath $attempts -Force).Count){throw 'INVALID:PRIOR_SYNC_READINESS_REVIEW_REQUIRED'}
 $dir=Join-Path $attempts ([Guid]::NewGuid().ToString());[void][IO.Directory]::CreateDirectory($dir)
 Write-SyncReadinessEvent (Join-Path $dir 'started.json') ([ordered]@{scope=$out.scope;source=$source;bundle=$ExpectedManifestHash;utc=[DateTime]::UtcNow.ToString('o');physicalAcceptance=$false})
 $stage='DEVICE_PROVENANCE';$fixed=Get-Od51RetryScript
 $serial=Select-Od51Target (Get-Od51AdbText (Invoke-Od51Adb $Adb '' @('devices') '' $fixed))
 $read={param($argsToRead) Get-Od51AdbText (Invoke-Od51Adb $Adb $serial $argsToRead '' $fixed) (($argsToRead -join ' ') -match '^shell pm path ')}.GetNewClosure()
 $c=Get-Od51Configuration $read
 foreach($k in @('manufacturer','model','android','api','build')){if($c.$k -cne $m.samsung.$k){throw 'INVALID:SYNC_CONFIGURATION_MISMATCH'}}
 if($c.securityPatch -cne $m.samsung.patch){throw 'INVALID:SYNC_CONFIGURATION_MISMATCH'}
 $child=Get-Od51Package 'dev.kidremote.child.unassigned.debug' $read;$fixture=Get-Od51Package 'dev.kidremote.spike.ordinary' $read
 if(-not $child.installed -or $child.sha256 -cne $m.lab.sha256 -or $child.versionCode -cne ([string]$m.lab.versionCode) -or $child.versionName -cne $m.lab.versionName -or -not $fixture.installed -or $fixture.sha256 -cne $m.fixture.sha256){throw 'INVALID:SYNC_PACKAGE_MISMATCH'}
 $tmp=Join-Path $dir 'installed-base.apk';$tempCleanup='UNVERIFIED'
 $pull=Invoke-Od51Adb $Adb $serial @('pull',$child.basePath,$tmp) '' $fixed $tmp;Assert-Od51PullResult $pull $tmp $tmp;Assert-Od51LocalApk $tmp $tmp $m.lab.sha256
 if((Get-Od51Signer (Join-Path $PSScriptRoot 'runtime/jbr/bin/java.exe') (Join-Path $PSScriptRoot 'runtime/apksigner.jar') $tmp) -cne $m.lab.signer){throw 'INVALID:SYNC_SIGNER_MISMATCH'}
 Remove-Item -LiteralPath $tmp;$tmp=$null;$tempCleanup='HOST_TEMP_DELETED'
 $stage='REVERSE_ABSENCE';$reverse=& $read @('reverse','--list');Assert-LabReverse $reverse $false
 $stage='RETAINED_RETRY';$raw=$null
 try{$raw=Invoke-Od51Adb $Adb $serial @('shell','-T','run-as','dev.kidremote.child.unassigned.debug','sh') $fixed $fixed;$out.retry=Convert-Od51RetryProcessResult $raw}finally{$raw=$null}
 Assert-SyncReadinessRetry $out.retry
 Write-SyncReadinessEvent (Join-Path $dir 'preflight.json') ([ordered]@{configuration='EXACT';package='EXACT';signer='EXACT';reverse='ABSENT';retry=$out.retry})
 $stage='RETAINED_BACKEND';$leaseRoot=Join-Path $env:LOCALAPPDATA 'KidRemote\physical-lab'
 foreach($name in @('lease.dpapi','resources.json')){if(-not(Test-Path -LiteralPath (Join-Path $leaseRoot $name))){throw 'INVALID:SYNC_RETAINED_LEASE_MISSING'}}
 Write-Host 'Reconectando o laboratorio preservado. Nao sera criado novo pareamento nem enviado Lock/Unlock.'
 Write-SyncReadinessEvent (Join-Path $dir 'backend-admitted.json') ([ordered]@{stage=$stage;requireExisting=$true;newTargetPolicy=$false;utc=[DateTime]::UtcNow.ToString('o')})
 $backend=Start-ProductBackend $sourceRoot $PSScriptRoot $source -RequireExisting;$backendStarted=$true
 Assert-SyncReadinessLease $backend $expected $review
 $readPage={if($backend.process.HasExited){throw 'INVALID:SYNC_BACKEND_EXITED'};Invoke-LabWire rest '/rpc/parent_devices' POST @{p_after=$null} $backend.jwt}.GetNewClosure()
 $stage='BASELINE_REPORT';$baseline=Convert-SyncReadinessPage (& $readPage) $expected
 $action={param([string]$kind)
  $argsToRun=Get-SyncReadinessAction $kind
  $r=Invoke-ReviewProcess $Adb (@('-s',$serial)+$argsToRun) ''
  if($r.stderr.Trim()){throw 'INVALID:SYNC_ADB_STDERR'}
  if($kind -ceq 'Resume' -and ($r.stdout -notmatch '(?m)^Status: ok\r?$' -or $r.stdout -match 'Error:|Exception|Permission Denial')){throw 'INVALID:SYNC_LAUNCH_FAILED'}
  return $r.stdout
 }.GetNewClosure()
 $stage='TRANSPORT_CONNECT';Assert-LabReverse (& $action ReadReverse) $false
 Write-SyncReadinessEvent (Join-Path $dir 'transport-admitted.json') ([ordered]@{stage=$stage;utc=[DateTime]::UtcNow.ToString('o');policyOperations=0})
 $reverseAttempted=$true;$null=& $action Connect;Assert-LabReverse (& $action ReadReverse) $true;$reverseOwned=$true
 $stage='APP_RESUME';Write-SyncReadinessEvent (Join-Path $dir 'resume-admitted.json') ([ordered]@{stage=$stage;utc=[DateTime]::UtcNow.ToString('o');explicitRetryReset=$false})
 $clock=[Diagnostics.Stopwatch]::StartNew();$null=& $action Resume
 $record={param($row) Write-SyncReadinessEvent (Join-Path $dir 'initial-window.json') $row;Write-Host 'Janela inicial registrada. Aguardando o relatorio sem zerar a espera do aplicativo.'}.GetNewClosure()
 $ops=@{Read=$readPage;Elapsed={$clock.ElapsedMilliseconds}.GetNewClosure();Pause={Start-Sleep -Milliseconds 2000};Record=$record}
 Write-Host 'Aguardando sincronizacao automatica por ate seis minutos. Nao feche este PowerShell; o JSON final sera salvo automaticamente.'
 $stage='REPORT_OBSERVATION';$out.observation=Wait-SyncReadinessReport $ops $expected $baseline;$out.status=$out.observation.status
}catch{
 $out.status='INVALID';$out.failureStage=$stage
 $match=[regex]::Match($_.Exception.Message,'^(?:INVALID:)?([A-Z0-9_]{1,100})$')
 $out.failureCode=if($match.Success){$match.Groups[1].Value}else{'SYNC_INTERNAL_FAILURE'}
 if($_.Exception.Data.Contains('hostStage') -and [string]$_.Exception.Data['hostStage'] -cmatch '^[A-Z0-9_]{1,100}$'){$out.failureStage=[string]$_.Exception.Data['hostStage']}
 if($_.Exception.Data.Contains('hostCode') -and [string]$_.Exception.Data['hostCode'] -cmatch '^[A-Z0-9_]{1,100}$'){$out.failureCode=[string]$_.Exception.Data['hostCode']}
}finally{
 if($reverseAttempted){$reverseCleanup='UNVERIFIED'}
 if($reverseOwned){try{Assert-LabReverse (& $action ReadReverse) $true;$null=& $action Disconnect;Assert-LabReverse (& $action ReadReverse) $false;$reverseCleanup='OWN_REVERSE_REMOVED'}catch{$reverseCleanup='UNVERIFIED'}}
 if($backend){try{$backendCleanup=Stop-ProductBackend $backend}catch{$backendCleanup='UNVERIFIED'}}
 elseif($stage -ceq 'RETAINED_BACKEND'){$backendCleanup='START_FAILED_REVIEW_REQUIRED'}
 if($tmp){try{Remove-Item -LiteralPath $tmp -Force;$tempCleanup='HOST_TEMP_DELETED'}catch{$tempCleanup='UNVERIFIED'}}
 $serial=$null;$raw=$null
 if($history){try{
  $after=Assert-SyncReadinessHistory $historyRoot $review
  if($after.Count -ne $history.Count){throw 'changed'}
  foreach($k in $history.Keys){if($after[$k] -cne $history[$k]){throw 'changed'}}
  $out.historicalEvidence='VERIFIED_UNCHANGED'
 }catch{$out.historicalEvidence='UNVERIFIED';$out.status='INVALID'}}
}
$out.backendCleanup=$backendCleanup;$out.reverseCleanup=$reverseCleanup;$out.hostTemporaryApk=$tempCleanup
foreach($cleanup in @(
 @(($out.historicalEvidence -ceq 'UNVERIFIED'),'HISTORY_RECHECK','SYNC_HISTORY_CHANGED'),
 @(($reverseCleanup -ceq 'UNVERIFIED'),'REVERSE_CLEANUP','SYNC_REVERSE_CLEANUP_UNVERIFIED'),
 @(($backendCleanup -in @('UNVERIFIED','START_FAILED_REVIEW_REQUIRED')),'BACKEND_CLEANUP','SYNC_BACKEND_CLEANUP_UNVERIFIED'),
 @(($tempCleanup -ceq 'UNVERIFIED'),'HOST_TEMP_CLEANUP','SYNC_HOST_TEMP_CLEANUP_UNVERIFIED')
)){
 if($cleanup[0]){$out.status='INVALID';if($out.failureCode -ceq 'NONE'){$out.failureStage=$cleanup[1];$out.failureCode=$cleanup[2]}}
}
$final=[ordered]@{attempt=$(if($dir){Split-Path $dir -Leaf}else{'NOT_CREATED'});utc=[DateTime]::UtcNow.ToString('o');source=$source;result=$out}
try{if($dir){Write-SyncReadinessEvent (Join-Path $dir 'result.json') $final}}catch{$out.status='INVALID';$out.failureStage='EVIDENCE_WRITE';$out.failureCode='SYNC_EVIDENCE_WRITE_FAILED'}
Write-Output ($final|ConvertTo-Json -Depth 9)
if($out.status -cne 'OBSERVED'){exit 1}
