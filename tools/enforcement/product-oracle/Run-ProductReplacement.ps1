param([string]$Adb='C:\platform-tools\adb.exe',[string]$ExpectedManifestHash)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
# OD-51: frozen files + native live host gate precede every device mutation.
# Frozen entrypoint is copied to bundle root. No ADB/HTTP until manifest/tool validation.
$directory=$null;$backend=$null;$live=$null;$serial=$null;$temporary=$null;$primary=$null;$backendCleanup='NOT_STARTED';$reverseCleanup='NOT_CREATED';$recovery='NOT_REQUIRED';$source='UNSPECIFIED';$hostValidated=$false;$reuse=$false;$hostFailureStage='UNSPECIFIED'
try{
 $manifestPath=Join-Path $PSScriptRoot 'bundle.json'
 if($ExpectedManifestHash -cnotmatch '^[a-f0-9]{64}$' -or (Get-FileHash -LiteralPath $manifestPath).Hash.ToLowerInvariant() -cne $ExpectedManifestHash){throw 'INVALID:BUNDLE_HASH'}
 $m=[IO.File]::ReadAllText($manifestPath)|ConvertFrom-Json
 if($m.scope -cne 'OD51_ONE_PERSISTENT_LAB_PRODUCT_SLICE' -or $m.source -cnotmatch '^[a-f0-9]{40}$' -or $m.readiness -cne 'READY_FOR_ONE_OWNER_RUN' -or $m.files.Count -lt 10 -or $m.files.Count -gt 5000){throw 'INVALID:BUNDLE_SCHEMA'}
 $seen=@{}
 foreach($f in $m.files){
  if($f.name -cnotmatch '^[A-Za-z0-9_./-]+$' -or $f.name -match '(^|/)\.\.?(/|$)' -or $seen.ContainsKey($f.name) -or $f.sha256 -cnotmatch '^[a-f0-9]{64}$'){throw 'INVALID:BUNDLE_FILE_SCHEMA'}
  $seen[$f.name]=$true
  if((Get-FileHash -LiteralPath (Join-Path $PSScriptRoot $f.name)).Hash.ToLowerInvariant() -cne $f.sha256){throw 'INVALID:BUNDLE_FILE_HASH'}
 }
 if(-not $seen.ContainsKey('Start-ProductSlice.ps1') -or -not $seen.ContainsKey('lab-reference.apk') -or -not $seen.ContainsKey('host-qr.jar') -or -not $seen.ContainsKey('zxing-core.jar')){throw 'INVALID:BUNDLE_REQUIRED_FILES'}
 $source=$m.source;$sourceRoot=Join-Path $PSScriptRoot 'source';$modules=Join-Path $sourceRoot 'tools/enforcement/product-oracle'
 foreach($n in @('Reuse','BackendHost','Journal','Replacement','ReplacementAdb','ReadOnly','Canonical','EnrollmentHost','LivePreparation','LiveSlice','ProductOracle','ProductTransport')){Import-Module (Join-Path $modules ($n+'.psm1')) -Force}
 Import-Module (Join-Path $sourceRoot 'tools/enforcement/update-review/Review.psm1') -Force
 $java=Join-Path $PSScriptRoot 'runtime\jbr\bin\java.exe';$jar=Join-Path $PSScriptRoot 'runtime\apksigner.jar'
 if((Get-FileHash -LiteralPath $java).Hash.ToLowerInvariant() -cne $m.javaSha256 -or (Get-FileHash -LiteralPath $jar).Hash.ToLowerInvariant() -cne $m.apksignerSha256){throw 'INVALID:SDK_PROVENANCE'}
 if($Adb -cne 'C:\platform-tools\adb.exe'){throw 'INVALID:FIXED_ADB_REQUIRED'}
 $root=Join-Path $env:LOCALAPPDATA 'KidRemote\product-slice-attempts';[void][IO.Directory]::CreateDirectory($root)
 # Restart is review-only. No new uninstall can hide an unfinished/ambiguous attempt.
 foreach($old in @(Get-ChildItem -LiteralPath $root -Directory)){
  $previous=Read-ProductJournal $old.FullName
  if($previous.partial -or -not $previous.verdict -or $previous.cleanup -ceq 'UNVERIFIED'){throw 'INVALID:PRIOR_ATTEMPT_REVIEW_REQUIRED'}
 }
 $directory=New-ProductJournal $root $source $ExpectedManifestHash 'f6d2a240fae179343d9eb19dfde7684ae6e241b35cebea8ce491205110f7ad56' '223219c17a31439b52698e769bdf03ead0998bbbe8bbb5c1b0ff5be3cfaf21dc' $true
 $temporary=Join-Path $directory 'temporary';[void][IO.Directory]::CreateDirectory($temporary)
 Write-Host 'Preparando backend local isolado; nenhuma substituição do tablet foi admitida ainda.'
 $wire={param($s,$p,$method,$body,$jwt) Invoke-LabWire $s $p $method $body $jwt}
 $h=@{backend=$null;serial=$null;live=$null;reuse=$false}
 $gate=@{
  Bundle={if($seen.Count -ne $m.files.Count){throw 'INVALID:BUNDLE_INCOMPLETE'}}
  Tools={if(-not(Test-Path -LiteralPath $Adb) -or -not(Test-Path -LiteralPath (Join-Path $PSScriptRoot 'runtime/node.exe'))){throw 'INVALID:NATIVE_TOOLS'}}
  Lease={$h.backend=Start-ProductBackend $sourceRoot $PSScriptRoot $source}
  LiveHealth={if(-not $h.backend.jwt){throw 'INVALID:LIVE_HEALTH'};$null=Get-OnlyLabChild $wire $h.backend.jwt}
  Ports={if($h.backend.process.HasExited){throw 'INVALID:OWN_BACKEND_EXITED'}}
  Artifacts={
   $r=Invoke-ReviewProcess $java @('--enable-native-access=ALL-UNNAMED','-jar',$jar,'verify','--verbose','--print-certs',(Join-Path $PSScriptRoot 'lab-reference.apk')) ''
   if($r.stderr.Trim() -or (Convert-ReviewSigner $r.stdout) -cne '638dfa66379788415c313d7a3ca96dcfcaf7e643c12bb0c4950b3046a3f76beb'){throw 'INVALID:LAB_SIGNER'}
  }
  Journal={$null=Read-ProductJournal $directory}
  ReadOnlyTarget={
   $h.serial=Select-InventoryTarget (Invoke-InventoryAdb $Adb '' @('devices'))
   $h.reuse=$null -ne $h.backend.local.device
   $h.live=New-LivePreparation $Adb $h.serial $PSScriptRoot $temporary $h.backend.jwt $h.reuse $h.backend.local.device $directory
   & $h.live.ops.HostReady;& $h.live.ops.Configuration
   if((& $h.live.ops.FixtureHash) -cne '223219c17a31439b52698e769bdf03ead0998bbbe8bbb5c1b0ff5be3cfaf21dc'){throw 'INVALID:FIXTURE_PROVENANCE'}
   Assert-ReplacementRecord (& $h.live.ops.Installed) (-not $h.reuse)
   if($h.reuse){& $h.live.ops.ReuseIdentityPermissions}
  }
 }
 try{Invoke-ProductHostGate $gate;$hostValidated=$true}finally{$backend=$h.backend;$serial=$h.serial;$live=$h.live;$reuse=$h.reuse}
 $jwt=$backend.jwt
 if(-not $hostValidated){throw 'INVALID:INVALID_HOST_PREFLIGHT'}
 $prepared=if($reuse){Invoke-ReusePreparation $directory $live.ops}else{Invoke-ReplacementPreparation $directory $live.ops}
 if($prepared.status -ceq 'PREPARED_NOT_PASS'){Save-ProductLabDevice $backend $live.state.device}
 if($prepared.status -cne 'PREPARED_NOT_PASS'){$primary=$prepared}
 else{
  $ops=New-LiveSliceCallbacks $Adb $serial $wire $jwt $live.state.device $directory
  $read=$live.read
  $ops.Preflight={
   $i=Invoke-ReadOnlyInventory $read
   if($i.classification -ceq 'CONFIGURATION_MISMATCH' -or $i.child.sha256 -cne 'f6d2a240fae179343d9eb19dfde7684ae6e241b35cebea8ce491205110f7ad56' -or $i.fixture.sha256 -cne '223219c17a31439b52698e769bdf03ead0998bbbe8bbb5c1b0ff5be3cfaf21dc' -or $i.accessibility -cne 'ENABLED' -or $i.usageAccess -cne 'ENABLED'){throw 'INVALID:FINAL_SETUP_PROVENANCE'}
  }.GetNewClosure()
  Write-Host 'Executando controle positivo, LOCK canônico, oráculo independente e UNLOCK.'
  $primary=Invoke-ProductSlice $ops
  if($primary.cleanup -ceq 'UNVERIFIED'){
   $recovery='MANUAL_RECOVERY_REQUIRED'
   & $live.action OpenAccessibility
   Write-Host 'LAB RECOVERY: desative manualmente somente a Acessibilidade do KidRemote para restaurar uso. O resultado original não muda.'
  }
 }
}catch{
 if($_.Exception.Data.Contains('hostStage')){$hostFailureStage=[string]$_.Exception.Data['hostStage']}
 $reason=[string]$_.Exception.Message;if(-not $hostValidated){$reason='INVALID:INVALID_HOST_PREFLIGHT'};if($reason -cnotmatch '^INVALID:[A-Z0-9_]+$'){$reason='INVALID:HOST_OR_TRANSPORT_FAILURE'}
 if($null -eq $primary){$primary=[pscustomobject]@{status='INVALID';reason=$reason;cleanup='UNVERIFIED'}}
 if($directory){try{$j=Read-ProductJournal $directory;if(-not $j.verdict){$meta=[IO.File]::ReadAllText((Join-Path $directory 'provenance'))|ConvertFrom-Json;$null=Add-ProductJournal $directory $meta.attempt VERDICT INVALID;if(-not ($j.rows|Where-Object{$_.stage -in @('UNINSTALL_ADMITTED','INSTALL_ADMITTED','REVERSE_ADMITTED','POLICY_ADMITTED','LOCK_ADMITTED')})){$null=Add-ProductJournal $directory ([Guid]::NewGuid().ToString()) CLEANUP NOT_REQUIRED}}}catch{}}
}finally{
 if($hostValidated -and $live -and $primary -and $primary.cleanup -ceq 'UNVERIFIED' -and $recovery -ceq 'NOT_REQUIRED'){
  $recovery='MANUAL_RECOVERY_REQUIRED'
  try{& $live.action OpenAccessibility}catch{}
  Write-Host 'LAB RECOVERY: se houver restrição, desative manualmente somente a Acessibilidade do KidRemote. O resultado original permanece inalterado.'
 }
 if($live -and $live.state.reverseAttempted){$reverseCleanup='UNVERIFIED'}
 if($live -and $live.state.reverse){
  try{
   # Only remove a still-matching fixed tunnel created by this attempt.
   $run={param($e,$a,$inputText) Invoke-ReviewProcess $e $a $inputText}
   $apk=Join-Path $PSScriptRoot 'lab-reference.apk'
   Assert-LabReverse (Invoke-ReplacementAdb $Adb $serial ReverseRead $apk $run) $true
   $null=Invoke-ReplacementAdb $Adb $serial RemoveReverse $apk $run
   Assert-LabReverse (Invoke-ReplacementAdb $Adb $serial ReverseRead $apk $run) $false
   $reverseCleanup='OWN_REVERSE_REMOVED'
  }catch{$reverseCleanup='UNVERIFIED'}
 }
 if($backend){try{$backendCleanup=Stop-ProductBackend $backend}catch{$backendCleanup='UNVERIFIED'}}
 if($temporary){try{[IO.Directory]::Delete($temporary)}catch{$recovery='HOST_TEMP_REVIEW_REQUIRED'}}
 $jwt=$null;$serial=$null
}
$result=[ordered]@{scope='OD51_ONE_PRODUCT_SLICE_NOT_QUALIFICATION';hostValidated=$hostValidated;hostFailureStage=$hostFailureStage;hostFailureAction=$(if(-not $hostValidated){'Host preflight failed before tablet mutation. Check the named stage; Docker Desktop must be running. Preserve this attempt and paste only this sanitized JSON.'}else{'NONE'});reuse=$reuse;expectedSetupActions=$(if($reuse){0}else{5});persistentSyntheticLab=$true;source=$source;primary=$primary;backendCleanup=$backendCleanup;reverseCleanup=$reverseCleanup;labRecovery=$recovery;oldApkRestored=$false;newAppMayRemainInstalled=$true;historicalEvidenceUnchanged=$true}
# Result contains only typed verdict/state and task UUIDs, never credentials or raw device output.
$json=$result|ConvertTo-Json -Depth 8
if($directory){$p=Join-Path $directory 'result.txt';$f=[IO.File]::Open($p,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None);try{$b=[Text.Encoding]::UTF8.GetBytes($json);$f.Write($b,0,$b.Length);$f.Flush($true)}finally{$f.Dispose()}}
Write-Output $json
