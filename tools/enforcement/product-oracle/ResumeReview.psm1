Set-StrictMode -Version Latest
Import-Module (Join-Path $PSScriptRoot 'Journal.psm1')
Import-Module (Join-Path $PSScriptRoot '../update-review/ProductRuntimeCatalog.psm1')
Import-Module (Join-Path $PSScriptRoot '../update-review/ProductRuntimeOemOverlay.psm1')
function Test-InterruptedEnrollmentObservation($Review,[string]$CatalogPath){
 # A pinned historical observation supports review only; runtime state is checked again.
 $ref=$Review.metadataObservation
 if($ref.path -cnotmatch '^\.\./\.\./\.\./docs/test-plans/evidence/[A-Z0-9_-]+\.json$' -or $ref.sha256 -cnotmatch '^[a-f0-9]{64}$' -or $ref.attempt -cnotmatch '^[a-f0-9-]{36}$' -or $ref.source -cnotmatch '^[a-f0-9]{40}$'){return $false}
 $path=Join-Path (Split-Path $CatalogPath -Parent) $ref.path
 $file=Get-Item -LiteralPath $path -Force -ErrorAction Stop
 if($file.PSIsContainer -or ($file.Attributes -band [IO.FileAttributes]::ReparsePoint) -or $file.Length -gt 16384 -or (Get-FileHash -LiteralPath $path).Hash.ToLowerInvariant() -cne $ref.sha256){return $false}
 $observation=[IO.File]::ReadAllText($path)|ConvertFrom-Json;$r=$observation.result
 if($observation.attempt -cne $ref.attempt -or $observation.source -cne $ref.source -or $r.scope -cne 'OD51_READ_ONLY_METADATA_OBSERVATION'){return $false}
 foreach($k in @('deviceMutation','backendMutation','mutationJournalCreated')){if($r.$k -isnot [bool] -or $r.$k){return $false}}
 foreach($k in @('configurationProvenance','packageProvenance','fixtureProvenance')){if($r.$k -cne 'PASS'){return $false}}
 if($r.reverseAbsent -isnot [bool] -or -not $r.reverseAbsent -or $r.metadataKnown -isnot [bool] -or -not $r.metadataKnown -or $r.metadataStatus -cne 'METADATA_ONLY' -or $r.probeStatus -cne 'OBSERVED'){return $false}
 if($r.child.sha256 -cne $Review.child -or $r.fixture.sha256 -cne $Review.fixture){return $false}
 $c=$r.configuration;$config=@{manufacturer=$c.manufacturer;model=$c.model;android=$c.android;api=$c.api;build=$c.build;patch=$c.securityPatch}
 $overlay=Get-ProductRuntimeOemOverlayPaths $config
 if($overlay.Count -ne 1 -or -not $overlay.Contains('runtime_samsung_ids')){return $false}
 if($r.knownPresent -isnot [Array] -or (($r.knownPresent|Sort-Object) -join ',') -cne 'runtime_profile,runtime_work_no_backup,runtime_work_no_backup_shm,runtime_work_no_backup_wal'){return $false}
 if($r.totalDurableFiles -ne 5 -or $r.knownDurableFiles -ne 4 -or $r.otherDurableFiles -ne 1 -or $r.metadataFinding -cne 'UNKNOWN_DURABLE_FILES_PRESENT'){return $false}
 if($r.unexpectedStructuralEntries -isnot [Array] -or $r.unexpectedStructuralEntries.Count -ne 1){return $false}
 $entry=$r.unexpectedStructuralEntries[0]
 return (($entry.directory+'/'+$entry.relativeName) -ceq $overlay['runtime_samsung_ids'] -and $entry.bytes -eq 108)
}
function Test-InterruptedEnrollmentLiveState($Metadata,$Devices,$Saved,[bool]$LabPackage){
 try{
  if(-not $LabPackage -or $null -ne $Saved -or @($Devices).Count -ne 0 -or $Metadata.status -cne 'METADATA_ONLY' -or $Metadata.otherDurableFiles -ne 0 -or $Metadata.files -isnot [Array]){return $false}
  $known=Get-ReviewStatePaths $true
  foreach($kind in @($known.Keys|Where-Object{$_ -cnotlike 'runtime_*'})){
   $rows=@($Metadata.files|Where-Object{$_.kind -ceq $kind})
   if($rows.Count -ne 1 -or $rows[0].presence -cne 'ABSENT'){return $false}
  }
  if(@($Metadata.files|Where-Object{$_.kind -cnotlike 'runtime_*' -and $_.presence -cne 'ABSENT'}).Count){return $false}
  return $true
 }catch{return $false}
}

# No caller-supplied ADB commands or product state contents enter this model.
function Get-ResumableHistoryReview([string]$Directory,[string]$CatalogPath=''){
 try{
  if(-not $CatalogPath){$CatalogPath=Join-Path $PSScriptRoot 'ReviewedInvalidAttempts.json'}
  $catalogRaw=[IO.File]::ReadAllText($CatalogPath);if($catalogRaw.Length -gt 32768){return $null};$catalog=$catalogRaw|ConvertFrom-Json
  if($catalog.schema -ne 1 -or $catalog.reviews -isnot [Array] -or $catalog.reviews.Count -gt 10){return $null}
  $j=Read-ProductJournal $Directory
  $m=[IO.File]::ReadAllText((Join-Path $Directory 'provenance'))|ConvertFrom-Json
  if($j.partial){return $null}
  $matches=@($catalog.reviews|Where-Object{$_.attempt -ceq $m.attempt});if($matches.Count -ne 1){return $null};$review=$matches[0]
  $kind=if($review.PSObject.Properties.Name -contains 'reviewKind'){[string]$review.reviewKind}else{'FINALIZED_INVALID'}
  if($kind -cnotin @('FINALIZED_INVALID','INTERRUPTED_PRE_SETUP')){return $null};$interrupted=$kind -ceq 'INTERRUPTED_PRE_SETUP'
  if($interrupted){if($j.verdict -or $j.cleanup -cne 'UNVERIFIED'){return $null}}elseif($j.verdict -cne 'INVALID' -or $j.cleanup -cne 'UNVERIFIED'){return $null}
  if($review.attempt -cnotmatch '^[a-f0-9-]{36}$' -or $review.source -cnotmatch '^[a-f0-9]{40}$' -or $review.bundle -cnotmatch '^[a-f0-9]{64}$' -or $review.child -cnotmatch '^[a-f0-9]{64}$' -or $review.fixture -cnotmatch '^[a-f0-9]{64}$'){return $null}
  if($m.source -cne $review.source -or $m.bundle -cne $review.bundle -or $m.child -cne $review.child -or $m.fixture -cne $review.fixture){return $null}
  $inventory=@($review.inventory.PSObject.Properties);if($inventory.Count -lt 5 -or $inventory.Count -gt 32){return $null}
  $actual=@(Get-ChildItem -LiteralPath $Directory -Force);if($actual.Count -ne $inventory.Count -or @($actual|Where-Object{$_.PSIsContainer -or ($_.Attributes -band [IO.FileAttributes]::ReparsePoint)}).Count){return $null}
  foreach($entry in $inventory){
   if($entry.Name -cnotmatch '^(?:[0-9]{6}\.json|provenance|result\.txt|resume-review|writer\.lock)$' -or [string]$entry.Value -cnotmatch '^[a-f0-9]{64}$'){return $null}
   $path=Join-Path $Directory $entry.Name;if(-not(Test-Path -LiteralPath $path -PathType Leaf) -or (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant() -cne $entry.Value){return $null}
  }
  $stages=@($review.stages);if($stages.Count -ne $j.rows.Count -or ($stages -join ',') -cne ($j.rows.stage -join ',') -or $stages -contains 'POLICY_ADMITTED' -or $stages -contains 'LOCK_ADMITTED'){return $null}
  if($interrupted){
   if(($stages -join ',') -cne 'BEGIN,PAIRING_CLEANUP_ADMITTED,REVERSE_ADMITTED,ENROLLMENT_ADMITTED' -or $review.permittedPath -cne 'ENROLL'){return $null}
   foreach($field in @('primaryStatus','primaryReason','primaryCleanup')){if($review.$field -cne 'NOT_RECORDED'){return $null}}
   if(-not(Test-InterruptedEnrollmentObservation $review $CatalogPath)){return $null}
   $resume=Read-ResumeReview $Directory
   if($resume.classification -cne 'SAFE_RESUME_FROM_ENROLLMENT' -or $resume.packageMode -cne 'LAB_PACKAGE_UNPAIRED' -or $resume.permittedPath -cne 'ENROLL' -or $resume.failedChecks.Count){return $null}
   foreach($field in @('backendDevice','localIdentity','pairingPending','localAccounting')){if($resume.$field -isnot [bool] -or $resume.$field){return $null}}
  }else{
  $raw=[IO.File]::ReadAllText((Join-Path $Directory 'result.txt'));if($raw.Length -gt 65536){return $null};$result=$raw|ConvertFrom-Json
  if($review.primaryReason -cnotmatch '^INVALID:[A-Z0-9_]{1,120}$' -or $review.hostFailureCode -cnotmatch '^[A-Z0-9_]{1,120}$'){return $null}
  $expectedReverse=if($review.PSObject.Properties.Name -contains 'reverseCleanup'){[string]$review.reverseCleanup}else{'OWN_REVERSE_REMOVED'}
  if($expectedReverse -cnotin @('OWN_REVERSE_REMOVED','NOT_CREATED')){return $null}
  if($result.hostValidated -ne $true -or $result.hostFailureCode -cne $review.hostFailureCode -or $result.primary.reason -cne $review.primaryReason -or $result.primary.cleanup -cne 'UNVERIFIED' -or $result.reverseCleanup -cne $expectedReverse -or $result.backendCleanup -cne 'STOPPED_SYNTHETIC_LEASE_AND_ENROLLMENT_RETAINED'){return $null}
  if($review.PSObject.Properties.Name -contains 'preparationFailureStage'){
   if($review.preparationFailureStage -cnotmatch '^[A-Z0-9_]{1,80}$' -or $review.preparationFailureCode -cnotmatch '^[A-Z0-9_]{1,120}$' -or $result.preparationFailureStage -cne $review.preparationFailureStage -or $result.preparationFailureCode -cne $review.preparationFailureCode){return $null}
  }
  }
  $hasSession=$review.PSObject.Properties.Name -contains 'pairingSession';$hasResolution=$review.PSObject.Properties.Name -contains 'pairingResolution'
  if($interrupted){if(-not $hasSession -or -not $hasResolution -or $review.pairingSession.id -ceq $review.pairingResolution.id){return $null}}elseif($hasSession -eq $hasResolution){return $null}
  if($hasSession -and ($review.pairingSession.id -cnotmatch '^[a-f0-9-]{36}$' -or $review.pairingSession.disposition -cnotin @('OPEN','CANCELLED'))){return $null}
  if($hasResolution -and ($review.pairingResolution.id -cnotmatch '^[a-f0-9-]{36}$' -or $review.pairingResolution.from -cne 'OPEN' -or $review.pairingResolution.to -cne 'CANCELLED')){return $null}
  return $review
 }catch{return $null}
}
function Test-ResumableHistory([string]$Directory,[string]$CatalogPath=''){return $null -ne (Get-ResumableHistoryReview $Directory $CatalogPath)}
function Test-ConfiguredReuseHistorySafe($HistoryReviews,$Review,$Saved,[bool]$Identity,[bool]$Pending,[bool]$Accounting){
 try{
  $history=@($HistoryReviews)
  if($history.Count -eq 0 -or $null -eq $Saved -or -not $Identity -or $Pending -or -not $Accounting){return $false}
  if(@($history|Where-Object{@($_.stages).Count -eq 0 -or @($_.stages|Where-Object{$_ -in @('POLICY_ADMITTED','LOCK_ADMITTED','UNLOCK_ADMITTED')}).Count}).Count){return $false}
  $expected=@{}
  foreach($h in $history){
   if($h.PSObject.Properties.Name -contains 'pairingSession'){
    $s=$h.pairingSession;if($null -eq $s -or $expected.ContainsKey($s.id) -or $s.id -cnotmatch '^[a-f0-9-]{36}$' -or $s.disposition -cnotin @('OPEN','CANCELLED')){return $false};$expected[$s.id]=[string]$s.disposition
   }
   if($h.PSObject.Properties.Name -contains 'pairingResolution'){
    $r=$h.pairingResolution;if($null -eq $r -or -not $expected.ContainsKey($r.id) -or $expected[$r.id] -cne 'OPEN' -or $r.from -cne 'OPEN' -or $r.to -cne 'CANCELLED'){return $false};$expected[$r.id]='CANCELLED'
   }
  }
  if($expected.Count -eq 0){return $false}
  $devices=@($Review.devices);if($devices.Count -ne 1){return $false};$d=$devices[0]
  if($d.id -cne $Saved.id -or $d.epoch -cne $Saved.policy_epoch -or $d.configured -ne $true -or $d.reported -ne $true -or $d.usable -ne $true){return $false}
  $sessions=@($Review.sessions);if($sessions.Count -ne $expected.Count+1){return $false}
  foreach($id in $expected.Keys){
   $rows=@($sessions|Where-Object{$_.id -ceq $id})
   if($rows.Count -ne 1 -or $rows[0].device -ne $null -or $rows[0].consumed -ne $false -or $rows[0].cancelled -ne $true){return $false}
  }
  $consumed=@($sessions|Where-Object{$_.consumed -and -not $_.cancelled})
  return ($consumed.Count -eq 1 -and $consumed[0].device -ceq $d.id)
 }catch{return $false}
}
function Resolve-ProductPreparation($Facts){
 $answer=[ordered]@{classification='INVALID_PARTIAL_STATE_REVIEW_REQUIRED';packageMode='INVALID_STATE';path='NONE';credentialProof='NOT_ESTABLISHED';reviewReason='NONE';failedChecks=@();backendDevice=$Facts.backendDevice;localIdentity=$Facts.identity;pairingPending=$Facts.pending;localAccounting=$Facts.accounting}
 $required=[ordered]@{provenance='PROVENANCE';owned='OWNERSHIP';compatible='BACKEND_COMPATIBILITY';reverseAbsent='REVERSE_ABSENT';historySafe='HISTORY_SAFE';metadataKnown='METADATA_KNOWN';noUnknownFiles='NO_UNKNOWN_FILES'}
 $failed=@()
 foreach($k in $required.Keys){if($Facts.$k -isnot [bool] -or -not $Facts.$k){$failed+=,$required[$k]}}
 if($failed.Count){$answer.failedChecks=@($failed);$answer.reviewReason=$failed[0];return [pscustomobject]$answer}
 if($Facts.package -ceq 'OLD'){
  if(-not $Facts.backendDevice -and -not $Facts.savedDevice -and -not $Facts.historicalPartial){$answer.packageMode='OLD_PACKAGE_NEEDS_REPLACEMENT';$answer.path='REPLACE';$answer.classification='SAFE_RESUME_FROM_ENROLLMENT'}
  else{$answer.failedChecks=@('PACKAGE_PROVENANCE');$answer.reviewReason='PACKAGE_PROVENANCE'}
  return [pscustomobject]$answer
 }
 if($Facts.package -cne 'LAB'){$answer.failedChecks=@('PACKAGE_PROVENANCE');$answer.reviewReason='PACKAGE_PROVENANCE';return [pscustomobject]$answer}
 if(-not $Facts.backendDevice -and -not $Facts.identity -and -not $Facts.pending -and -not $Facts.accounting -and -not $Facts.savedDevice){
  $answer.packageMode='LAB_PACKAGE_UNPAIRED';$answer.path='ENROLL';$answer.classification='SAFE_RESUME_FROM_ENROLLMENT';return [pscustomobject]$answer
 }
 # A host pointer without its exact backend device is never treated as enrollment
 # or folded into partial-state reset. Reconciliation needs separate durable proof.
 if(-not $Facts.backendDevice -and $Facts.savedDevice){$answer.failedChecks=@('SAVED_DEVICE_ORPHANED');$answer.reviewReason='SAVED_DEVICE_ORPHANED';return [pscustomobject]$answer}
 # Metadata cannot decrypt the epoch. Reuse requires a separate fresh authenticated
 # sync/report gate after RESUME_ADMITTED and before any new canonical policy.
 $configuredHistorySafe=$Facts.PSObject.Properties.Name -contains 'configuredReuseHistorySafe' -and $Facts.configuredReuseHistorySafe -eq $true
 if($Facts.backendDevice -and $Facts.savedDevice -and $Facts.savedMatches -and $Facts.identity -and -not $Facts.pending -and $Facts.credentialUsable -and $Facts.policyConsistent -and (-not $Facts.historicalPartial -or $configuredHistorySafe)){
  $answer.packageMode='LAB_PACKAGE_PAIRED_REUSABLE';$answer.path='VERIFY_REUSE';$answer.classification='SAFE_REUSE_ENROLLED';$answer.credentialProof='FRESH_ACK_REQUIRED_BEFORE_POLICY';return [pscustomobject]$answer
 }
 # The approved narrow automatic repair covers incomplete enrollment only. A
 # configured/reported or restricting identity cannot be inferred safe from blobs.
 if($Facts.historicalPartial -and $Facts.noPolicyOrReport -and $Facts.resetAttributable){
  $answer.packageMode='LAB_PACKAGE_PARTIAL_REPAIR';$answer.path='RESET_ENROLL';$answer.classification='SAFE_RESET_SYNTHETIC_KIDREMOTE_STATE_AND_REENROLL'
 }else{
  $answer.failedChecks=@('POLICY_STATE_AMBIGUOUS');$answer.reviewReason='POLICY_STATE_AMBIGUOUS'
 }
 return [pscustomobject]$answer
}
function Get-ResumeHash([string]$Text){
 $h=[Security.Cryptography.SHA256]::Create();try{return ([BitConverter]::ToString($h.ComputeHash([Text.Encoding]::UTF8.GetBytes($Text)))).Replace('-','').ToLowerInvariant()}finally{$h.Dispose()}
}
function Read-ResumeReview([string]$Directory){
 if(Test-Path -LiteralPath (Join-Path $Directory 'resume-review.tmp')){throw 'INVALID:RESUME_REVIEW_PARTIAL'}
 $raw=[IO.File]::ReadAllText((Join-Path $Directory 'resume-review'));if($raw.Length -gt 8192){throw 'INVALID:RESUME_REVIEW_BOUNDS'}
 $envelope=$raw|ConvertFrom-Json
 if($envelope.sha256 -cne (Get-ResumeHash $envelope.payload)){throw 'INVALID:RESUME_REVIEW_CHECKSUM'}
 $record=$envelope.payload|ConvertFrom-Json
 $m=[IO.File]::ReadAllText((Join-Path $Directory 'provenance'))|ConvertFrom-Json
 $allowed=@('PROVENANCE','OWNERSHIP','BACKEND_COMPATIBILITY','REVERSE_ABSENT','HISTORY_SAFE','METADATA_KNOWN','NO_UNKNOWN_FILES','PACKAGE_PROVENANCE','SAVED_DEVICE_ORPHANED','POLICY_STATE_AMBIGUOUS')
 [array]$failed=@($record.failedChecks);[array]$history=$(if($record.PSObject.Properties.Name -contains 'historicalAttempts'){@($record.historicalAttempts)}elseif($record.historicalAttempt -cne 'NONE'){@($record.historicalAttempt)}else{@()})
 [array]$badFailed=@($failed|Where-Object{$_ -cnotin $allowed});[array]$badHistory=@($history|Where-Object{$_ -cnotmatch '^[a-f0-9-]{36}$'});[array]$uniqueHistory=@($history|Select-Object -Unique)
 $failedCount=($failed|Measure-Object).Count;$badFailedCount=($badFailed|Measure-Object).Count;$historyCount=($history|Measure-Object).Count;$badHistoryCount=($badHistory|Measure-Object).Count;$uniqueHistoryCount=($uniqueHistory|Measure-Object).Count
 if($record.kind -cne 'RESUME_REVIEW' -or $record.format -notin @(1,2) -or $record.attempt -cne $m.attempt -or $record.source -cne $m.source -or $record.bundle -cne $m.bundle -or $record.compatibility -cnotmatch '^[a-f0-9]{64}$'){throw 'INVALID:RESUME_REVIEW_SCHEMA'}
 if($failedCount -gt 10 -or $badFailedCount -gt 0 -or ($failedCount -gt 0 -and $record.reviewReason -cne $failed[0]) -or ($failedCount -eq 0 -and $record.reviewReason -cne 'NONE')){throw 'INVALID:RESUME_REVIEW_SCHEMA'}
 if($historyCount -gt 10 -or $badHistoryCount -gt 0 -or $uniqueHistoryCount -ne $historyCount){throw 'INVALID:RESUME_REVIEW_SCHEMA'}
 $record|Add-Member -NotePropertyName reviewedHistoricalAttempts -NotePropertyValue @($history) -Force
 return $record
}
function Write-ResumeReview([string]$Directory,$HistoricalAttempts,[string]$Digest,$Resolution){
 $m=[IO.File]::ReadAllText((Join-Path $Directory 'provenance'))|ConvertFrom-Json
 $allowed=@('PROVENANCE','OWNERSHIP','BACKEND_COMPATIBILITY','REVERSE_ABSENT','HISTORY_SAFE','METADATA_KNOWN','NO_UNKNOWN_FILES','PACKAGE_PROVENANCE','SAVED_DEVICE_ORPHANED','POLICY_STATE_AMBIGUOUS');[array]$failed=@($Resolution.failedChecks);[array]$history=@($HistoricalAttempts|Where-Object{$_ -ne 'NONE'})
 [array]$badFailed=@($failed|Where-Object{$_ -cnotin $allowed});[array]$badHistory=@($history|Where-Object{$_ -cnotmatch '^[a-f0-9-]{36}$'});[array]$uniqueHistory=@($history|Select-Object -Unique)
 $failedCount=($failed|Measure-Object).Count;$badFailedCount=($badFailed|Measure-Object).Count;$historyCount=($history|Measure-Object).Count;$badHistoryCount=($badHistory|Measure-Object).Count;$uniqueHistoryCount=($uniqueHistory|Measure-Object).Count
 if($Digest -cnotmatch '^[a-f0-9]{64}$' -or $Resolution.classification -cnotin @('SAFE_REUSE_ENROLLED','SAFE_RESUME_FROM_ENROLLMENT','SAFE_RESET_SYNTHETIC_KIDREMOTE_STATE_AND_REENROLL','INVALID_PARTIAL_STATE_REVIEW_REQUIRED')){throw 'INVALID:RESUME_REVIEW_SCHEMA'}
 if($historyCount -gt 10 -or $badHistoryCount -gt 0 -or $uniqueHistoryCount -ne $historyCount){throw 'INVALID:RESUME_REVIEW_SCHEMA'}
 if($failedCount -gt 10 -or $badFailedCount -gt 0 -or ($failedCount -gt 0 -and $Resolution.reviewReason -cne $failed[0]) -or ($failedCount -eq 0 -and $Resolution.reviewReason -cne 'NONE')){throw 'INVALID:RESUME_REVIEW_SCHEMA'}
 $record=[ordered]@{kind='RESUME_REVIEW';format=2;attempt=$m.attempt;historicalAttempt=$(if($historyCount){$history[-1]}else{'NONE'});historicalAttempts=@($history);source=$m.source;bundle=$m.bundle;utc=[DateTime]::UtcNow.ToString('o');compatibility=$Digest;classification=$Resolution.classification;packageMode=$Resolution.packageMode;permittedPath=$Resolution.path;credentialProof=$Resolution.credentialProof;reviewReason=$Resolution.reviewReason;failedChecks=@($failed);backendDevice=$Resolution.backendDevice;localIdentity=$Resolution.localIdentity;pairingPending=$Resolution.pairingPending;localAccounting=$Resolution.localAccounting;historicalVerdict='UNCHANGED';historicalCleanup='UNCHANGED'}
 $path=Join-Path $Directory 'resume-review';$tmp=$path+'.tmp'
 if((Test-Path -LiteralPath $path) -or (Test-Path -LiteralPath $tmp)){throw 'INVALID:RESUME_REVIEW_IMMUTABLE'}
 $payload=$record|ConvertTo-Json -Compress;$envelope=@{payload=$payload;sha256=(Get-ResumeHash $payload)}|ConvertTo-Json -Compress
 $f=[IO.File]::Open($tmp,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
 try{$bytes=[Text.Encoding]::UTF8.GetBytes($envelope);$f.Write($bytes,0,$bytes.Length);$f.Flush($true)}finally{$f.Dispose()}
 [IO.File]::Move($tmp,$path)
}
Export-ModuleMember -Function Test-InterruptedEnrollmentLiveState,Read-ResumeReview,Test-ResumableHistory,Get-ResumableHistoryReview,Test-ConfiguredReuseHistorySafe,Resolve-ProductPreparation,Write-ResumeReview
