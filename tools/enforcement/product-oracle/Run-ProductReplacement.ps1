param([string]$Adb='C:\platform-tools\adb.exe',[string]$ExpectedManifestHash)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
# OD-51: frozen files + native live host gate precede every device mutation.
# Frozen entrypoint is copied to bundle root. No ADB/HTTP until manifest/tool validation.
$preparation=$null;$directory=$null;$backend=$null;$live=$null;$serial=$null;$temporary=$null;$primary=$null;$backendCleanup='NOT_STARTED';$reverseCleanup='NOT_CREATED';$recovery='NOT_REQUIRED';$source='UNSPECIFIED';$hostValidated=$false;$backendAttempted=$false;$reuse=$false;$hostFailureStage='BUNDLE_VERIFY';$hostFailureCode='NONE';$hostDiagnosticWrite='NOT_ATTEMPTED';$preparationFailureStage='NONE';$preparationFailureCode='NONE'
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
 $hostFailureStage='RUNTIME_VERIFY'
 $source=$m.source;$sourceRoot=Join-Path $PSScriptRoot 'source';$modules=Join-Path $sourceRoot 'tools/enforcement/product-oracle'
 foreach($n in @('ResumeReview','ResumePreparation','Reuse','BackendHost','Journal','Replacement','ReplacementAdb','ReadOnly','Canonical','EnrollmentHost','QrPresentation','QrRenderer','LivePreparation','LiveSlice','ProductOracle','ProductTransport')){Import-Module (Join-Path $modules ($n+'.psm1'))}
 Import-Module (Join-Path $sourceRoot 'tools/enforcement/update-review/Review.psm1')
 $java=Join-Path $PSScriptRoot 'runtime\jbr\bin\java.exe';$jar=Join-Path $PSScriptRoot 'runtime\apksigner.jar'
 if((Get-FileHash -LiteralPath $java).Hash.ToLowerInvariant() -cne $m.javaSha256 -or (Get-FileHash -LiteralPath $jar).Hash.ToLowerInvariant() -cne $m.apksignerSha256){throw 'INVALID:SDK_PROVENANCE'}
 $hostFailureStage='ADB_PREREQUISITE'
 if($Adb -cne 'C:\platform-tools\adb.exe'){throw 'INVALID:FIXED_ADB_REQUIRED'}
 $hostFailureStage='JOURNAL_READY'
 $root=Join-Path $env:LOCALAPPDATA 'KidRemote\product-slice-attempts';[void][IO.Directory]::CreateDirectory($root)
 # Restart is review-only. No new uninstall can hide an unfinished/ambiguous attempt.
 $historicalPartial=$false;$historyReviews=@();$resolvedHistory=@{}
 $oldAttempts=@(Get-ChildItem -LiteralPath $root -Directory)
 foreach($old in $oldAttempts){
  $previous=Read-ProductJournal $old.FullName
  if($previous.verdict -ceq 'PASS' -and $previous.cleanup -ceq 'VERIFIED_CANONICAL_UNLOCK_AND_INDEPENDENT_INPUT' -and (Test-Path -LiteralPath (Join-Path $old.FullName 'resume-review'))){
   $priorReview=Read-ResumeReview $old.FullName
   foreach($attempt in @($priorReview.reviewedHistoricalAttempts)){$resolvedHistory[$attempt]=$true}
  }
 }
 foreach($old in $oldAttempts){
  $previous=Read-ProductJournal $old.FullName;$meta=[IO.File]::ReadAllText((Join-Path $old.FullName 'provenance'))|ConvertFrom-Json
  if(($previous.partial -or -not $previous.verdict -or $previous.cleanup -ceq 'UNVERIFIED') -and -not $resolvedHistory.ContainsKey($meta.attempt)){
   $reviewed=Get-ResumableHistoryReview $old.FullName
   if($reviewed){$historicalPartial=$true;$historyReviews+=,$reviewed}else{throw 'INVALID:PRIOR_ATTEMPT_REVIEW_REQUIRED'}
  }
 }
 $historyAttemptIds=@($historyReviews|ForEach-Object{$_.attempt})
 $directory=New-ProductJournal $root $source $ExpectedManifestHash 'f6d2a240fae179343d9eb19dfde7684ae6e241b35cebea8ce491205110f7ad56' '223219c17a31439b52698e769bdf03ead0998bbbe8bbb5c1b0ff5be3cfaf21dc' $true
 $temporary=Join-Path $directory 'temporary';[void][IO.Directory]::CreateDirectory($temporary)
 Write-Host 'Preparando backend local isolado; nenhuma substituição do tablet foi admitida ainda.'
 $wire={param($s,$p,$method,$body,$jwt) Invoke-LabWire $s $p $method $body $jwt}
 $h=@{backend=$null;backendAttempted=$false;serial=$null;live=$null;reuse=$false;resolution=$null}
 $gate=@{
  Bundle={if($seen.Count -ne $m.files.Count){throw 'INVALID:BUNDLE_INCOMPLETE'}}
  Tools={if(-not(Test-Path -LiteralPath $Adb) -or -not(Test-Path -LiteralPath (Join-Path $PSScriptRoot 'runtime/node.exe'))){throw 'INVALID:NATIVE_TOOLS'}}
  Lease={$h.backendAttempted=$true;$h.backend=Start-ProductBackend $sourceRoot $PSScriptRoot $source}
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
   $installed=& $h.live.ops.Installed
   $lab=$installed.sha256 -ceq 'f6d2a240fae179343d9eb19dfde7684ae6e241b35cebea8ce491205110f7ad56'
   Assert-ReplacementRecord $installed (-not $lab)
   $metadata=& $h.live.ops.Metadata
   $known=$metadata.status -ceq 'METADATA_ONLY'
   $identity=$false;$pending=$false;$accounting=$false;$noUnknown=$false
   if($known){
    $noUnknown=$metadata.otherDurableFiles -eq 0
    $identity=@($metadata.files|Where-Object{$_.kind -like 'identity*' -and $_.presence -ceq 'PRESENT'}).Count -gt 0
    $pending=@($metadata.files|Where-Object{$_.kind -like 'pairing*' -and $_.presence -ceq 'PRESENT'}).Count -gt 0
    $accounting=@($metadata.files|Where-Object{$_.kind -like 'accounting*' -and $_.presence -ceq 'PRESENT'}).Count -gt 0
   }
   $review=$h.backend.review;$devices=@($review.devices);$saved=$h.backend.local.device
   $expectedSessions=@(Get-ReviewedPairingExpectations $historyReviews);$actualSessions=@($review.sessions)
   $expectedSessionCount=($expectedSessions|Measure-Object).Count;$actualSessionCount=($actualSessions|Measure-Object).Count
   $historyBackendSafe=$expectedSessionCount -eq $actualSessionCount
   if($historyBackendSafe){
    foreach($expected in $expectedSessions){
     $matches=@($actualSessions|Where-Object{$_.id -ceq $expected.id})
     if(($matches|Measure-Object).Count -ne 1 -or $matches[0].device -ne $null -or $matches[0].consumed -ne $false -or ($expected.disposition -ceq 'OPEN' -and $matches[0].cancelled -ne $false) -or ($expected.disposition -ceq 'CANCELLED' -and $matches[0].cancelled -ne $true)){$historyBackendSafe=$false;break}
    }
   }
   $d=if($devices.Count -eq 1){$devices[0]}else{$null}
   $historySafe=(-not $historicalPartial) -or ($historyBackendSafe -and -not $identity -and -not $pending -and -not $accounting)
   $facts=[pscustomobject]@{provenance=$true;owned=($review.owners -eq 1 -and $review.households -eq 1);compatible=($h.backend.compatibility -cmatch '^[a-f0-9]{64}$');reverseAbsent=$true;historySafe=$historySafe;metadataKnown=$known;noUnknownFiles=$noUnknown;package=$(if($lab){'LAB'}else{'OLD'});historicalPartial=$historicalPartial;backendDevice=($null -ne $d);savedDevice=($null -ne $saved);savedMatches=($null -ne $saved -and $null -ne $d -and $saved.id -ceq $d.id -and $saved.policy_epoch -ceq $d.epoch);identity=$identity;pending=$pending;accounting=$accounting;credentialUsable=($null -ne $d -and $d.usable);policyConsistent=($null -ne $d -and $d.configured);noPolicyOrReport=($null -eq $d -or (-not $d.configured -and -not $d.manualLock -and -not $d.reported));resetAttributable=($historicalPartial -and $known -and $noUnknown -and (-not $accounting) -and ($null -eq $d -or @($review.sessions|Where-Object{$_.device -ceq $d.id -and $_.consumed}).Count -eq 1))}
   # Historical replacement explicitly authorizes loss of old unknown files, only on OLD path.
   if(-not $lab -and -not $historicalPartial){$facts.metadataKnown=$true;$facts.noUnknownFiles=$true}
   $h.resolution=Resolve-ProductPreparation $facts;$preparation=$h.resolution
   Write-ResumeReview $directory $historyAttemptIds $h.backend.compatibility $h.resolution
   if($h.resolution.path -ceq 'NONE'){throw 'INVALID:INVALID_PARTIAL_STATE_REVIEW_REQUIRED'}
   $h.reuse=$h.resolution.path -ceq 'VERIFY_REUSE'
   $h.live.state.new=$lab

  }
 }
 try{Invoke-ProductHostGate $gate;$hostValidated=$true}finally{$backend=$h.backend;$backendAttempted=$h.backendAttempted;$serial=$h.serial;$live=$h.live;$reuse=$h.reuse;$preparation=$h.resolution}
 $jwt=$backend.jwt
 if(-not $hostValidated){throw 'INVALID:INVALID_HOST_PREFLIGHT'}
 $review=$backend.review
 $live.ops.CancelPairings={
  $live.state.preparationStage='PAIRING_SESSION_CLEANUP'
  $null=Invoke-ReviewedPairingCleanup $review $historyReviews $wire $jwt
 }.GetNewClosure()
 $live.ops.Reset={
  $live.state.preparationStage='RESET_RECONCILIATION'
  $fresh=Get-OnlyLabChild $wire $jwt
  if($fresh){
   $expected=@($review.devices)
   if($expected.Count -ne 1 -or $fresh.id -cne $expected[0].id -or $fresh.policy_epoch -cne $expected[0].epoch -or $fresh.policy_configured -or $fresh.report){throw 'INVALID:RESET_STATE_CHANGED'}
   $sessions=@($review.sessions|Where-Object{$_.device -ceq $fresh.id -and $_.consumed})
   if($sessions.Count -ne 1){throw 'INVALID:RESET_SESSION_AMBIGUOUS'}
   $r=& $wire rest '/rpc/finish_pairing' POST @{p_session=$sessions[0].id;p_revoke_incomplete=$true} $jwt
   if($r.result -cne 'REVOKED_FRESH_QR_REQUIRED'){throw 'INVALID:RESET_BACKEND_REFUSED'}
  }
  if($null -ne (Get-OnlyLabChild $wire $jwt)){throw 'INVALID:RESET_BACKEND_NOT_EMPTY'}
  & $live.action ClearChildData
  $after=& $live.ops.Metadata
  if($after.status -cne 'METADATA_ONLY' -or -not $after.sufficientForEmptyStateReview){throw 'INVALID:RESET_LOCAL_NOT_EMPTY'}
  Clear-ProductLabSavedDevice $backend
  $live.state.device=$null
 }.GetNewClosure()
 $prepared=if($h.resolution.path -ceq 'REPLACE'){Invoke-ReplacementPreparation $directory $live.ops}else{Invoke-ResumePreparation $directory $live.ops $h.resolution.path}
 $live.state.preparationStage='NONE'
 if($prepared.status -ceq 'PREPARED_NOT_PASS'){Save-ProductLabDevice $backend $live.state.device}
 if($prepared.status -cne 'PREPARED_NOT_PASS'){$primary=$prepared}
 else{
  $live.state.preparationStage='PRODUCT_SLICE'
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
 $hostFailureCode=if($_.Exception.Message -cmatch '^INVALID:[A-Z0-9_]{1,160}$'){$_.Exception.Message.Substring(8)}elseif($_.Exception -is [Management.Automation.CommandNotFoundException]){'COMMAND_NOT_AVAILABLE'}else{'SANITIZED_HOST_EXCEPTION'}
 if($_.Exception.Data.Contains('hostStage')){$hostFailureStage=[string]$_.Exception.Data['hostStage']}
 if($_.Exception.Data.Contains('hostCode')){$hostFailureCode=[string]$_.Exception.Data['hostCode']}
 $reason=[string]$_.Exception.Message
 if($hostValidated){
  $failure=Get-ProductPreparationFailure $_ $(if($live){$live.state}else{$null});$preparationFailureStage=$failure.stage;$preparationFailureCode=$failure.code
  $hostFailureCode='NONE';$reason=$failure.reason
 }else{$reason='INVALID:INVALID_HOST_PREFLIGHT'}
 if($reason -cnotmatch '^INVALID:[A-Z0-9_]+$'){$reason='INVALID:PREPARATION_ORCHESTRATION_FAILED'}
 if($null -eq $primary){$primary=[pscustomobject]@{status='INVALID';reason=$reason;cleanup='UNVERIFIED'}}
 if($directory){try{$j=Read-ProductJournal $directory;if(-not $j.verdict){$meta=[IO.File]::ReadAllText((Join-Path $directory 'provenance'))|ConvertFrom-Json;$null=Add-ProductJournal $directory $meta.attempt VERDICT INVALID;if(-not ($j.rows|Where-Object{$_.stage -in @('RESET_ADMITTED','PAIRING_CLEANUP_ADMITTED','ENROLLMENT_ADMITTED','SETUP_ADMITTED','UNINSTALL_ADMITTED','INSTALL_ADMITTED','REVERSE_ADMITTED','POLICY_ADMITTED','LOCK_ADMITTED')})){$null=Add-ProductJournal $directory ([Guid]::NewGuid().ToString()) CLEANUP NOT_REQUIRED}}}catch{}}
}finally{
 if($hostValidated -and $live -and $primary -and $primary.cleanup -ceq 'UNVERIFIED'){
  try{
   $j=Read-ProductJournal $directory
   if(@($j.rows|Where-Object{$_.stage -ceq 'POLICY_ADMITTED'}).Count -and -not @($j.rows|Where-Object{$_.stage -ceq 'UNLOCK_ADMITTED'}).Count){
    $d=Get-OnlyLabChild $wire $jwt
    if(-not $d -or -not $d.policy_configured){throw 'INVALID:RECOVERY_POLICY_UNKNOWN'}
    $id=[Guid]::NewGuid().ToString()
    $null=Add-ProductJournal $directory ([Guid]::NewGuid().ToString()) CLEANUP_ADMITTED OD51_FIXED_SCOPE
    $null=Add-ProductJournal $directory $id UNLOCK_ADMITTED ('EXPECTED_VERSION:'+$d.version)
    $q=New-ProductOperation $id $d.id UNLOCK $d.version
    $r=Invoke-StableLabOperation $wire $jwt $q;Assert-ProductAccepted $r $q $d.policy_epoch
    $recoveryOps=New-LiveSliceCallbacks $Adb $serial $wire $jwt $d $directory $true
    & $recoveryOps.Sync;$null=& $recoveryOps.Report $r.version $false
    & $recoveryOps.StartFixture;$before=& $recoveryOps.Fixture;& $recoveryOps.Tap $before;& $recoveryOps.Pause
    Assert-ProductPositive $before (& $recoveryOps.Fixture)
    if(-not (& $recoveryOps.Status $id $r.version)){throw 'INVALID:RECOVERY_STATUS_UNVERIFIED'}
    $null=Add-ProductJournal $directory ([Guid]::NewGuid().ToString()) CLEANUP VERIFIED_CANONICAL_UNLOCK_AND_INDEPENDENT_INPUT
    $recovery='VERIFIED_CANONICAL_UNLOCK_AND_INDEPENDENT_INPUT'
   }
  }catch{$recovery='CANONICAL_RECOVERY_UNVERIFIED'}
 }
 if($hostValidated -and $live -and $primary -and $primary.cleanup -ceq 'UNVERIFIED' -and $recovery -cin @('NOT_REQUIRED','CANONICAL_RECOVERY_UNVERIFIED') -and @((Read-ProductJournal $directory).rows|Where-Object{$_.stage -in @('POLICY_ADMITTED','LOCK_ADMITTED')}).Count){
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
 if($backendAttempted -and -not $backend){$backendCleanup='START_FAILED_PERSISTENT_STATE_REVIEW_REQUIRED'}
 if($backend){try{$backendCleanup=Stop-ProductBackend $backend}catch{$backendCleanup='UNVERIFIED'}}
 if($temporary){try{[IO.Directory]::Delete($temporary)}catch{$recovery='HOST_TEMP_REVIEW_REQUIRED'}}
 $jwt=$null;$serial=$null
}
$result=[ordered]@{scope='OD51_ONE_PRODUCT_SLICE_NOT_QUALIFICATION';hostValidated=$hostValidated;hostFailureStage=$(if($hostValidated){'NONE'}else{$hostFailureStage});hostFailureCode=$hostFailureCode;hostFailureAction=$(if(-not $hostValidated){'Host preflight failed before tablet mutation. Check the named stage and code. Docker engine availability is relevant only to DOCKER_ENGINE. Preserve this attempt and paste only this sanitized JSON.'}else{'NONE'});preparationFailureStage=$preparationFailureStage;preparationFailureCode=$preparationFailureCode;preparation=$preparation;reuse=$reuse;expectedSetupActions=$(if($reuse){0}else{5});persistentSyntheticLab=$true;source=$source;primary=$primary;backendCleanup=$backendCleanup;reverseCleanup=$reverseCleanup;labRecovery=$recovery;oldApkRestored=$false;newAppMayRemainInstalled=$true;historicalEvidenceUnchanged=$true}
# Result contains only typed verdict/state and task UUIDs, never credentials or raw device output.
$json=$result|ConvertTo-Json -Depth 8
if($directory){$p=Join-Path $directory 'result.txt';$f=[IO.File]::Open($p,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None);try{$b=[Text.Encoding]::UTF8.GetBytes($json);$f.Write($b,0,$b.Length);$f.Flush($true)}finally{$f.Dispose()}}
# Independent early diagnostic: no imported module is required; unique create-new + flush.
# Kept separate from mutation journals, so a pre-journal failure cannot hide a later attempt.
try{
 $diagnostics=Join-Path $env:LOCALAPPDATA 'KidRemote\product-host-failures'
 [void][IO.Directory]::CreateDirectory($diagnostics)
 $record=[ordered]@{attempt=[Guid]::NewGuid().ToString();utc=[DateTime]::UtcNow.ToString('o');result=$result}
 $path=Join-Path $diagnostics ($record.attempt+'.json')
 $stream=[IO.File]::Open(($path+'.tmp'),[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
 try{$bytes=[Text.Encoding]::UTF8.GetBytes(($record|ConvertTo-Json -Depth 10));$stream.Write($bytes,0,$bytes.Length);$stream.Flush($true)}finally{$stream.Dispose()}
 [IO.File]::Move(($path+'.tmp'),$path);$hostDiagnosticWrite='DURABLE'
}catch{$hostDiagnosticWrite='FAILED_PRESERVE_CONSOLE_JSON'}
$result.hostDiagnosticWrite=$hostDiagnosticWrite
Write-Output ($result|ConvertTo-Json -Depth 8)
