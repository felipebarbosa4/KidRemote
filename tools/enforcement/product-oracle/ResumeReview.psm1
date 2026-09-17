Set-StrictMode -Version Latest
Import-Module (Join-Path $PSScriptRoot 'Journal.psm1')
# No caller-supplied ADB commands or product state contents enter this model.
function Get-ResumableHistoryReview([string]$Directory,[string]$CatalogPath=''){
 try{
  if(-not $CatalogPath){$CatalogPath=Join-Path $PSScriptRoot 'ReviewedInvalidAttempts.json'}
  $catalogRaw=[IO.File]::ReadAllText($CatalogPath);if($catalogRaw.Length -gt 32768){return $null};$catalog=$catalogRaw|ConvertFrom-Json
  if($catalog.schema -ne 1 -or $catalog.reviews -isnot [Array] -or $catalog.reviews.Count -gt 10){return $null}
  $j=Read-ProductJournal $Directory
  $m=[IO.File]::ReadAllText((Join-Path $Directory 'provenance'))|ConvertFrom-Json
  if($j.partial -or $j.verdict -cne 'INVALID' -or $j.cleanup -cne 'UNVERIFIED'){return $null}
  $matches=@($catalog.reviews|Where-Object{$_.attempt -ceq $m.attempt});if($matches.Count -ne 1){return $null};$review=$matches[0]
  if($review.attempt -cnotmatch '^[a-f0-9-]{36}$' -or $review.source -cnotmatch '^[a-f0-9]{40}$' -or $review.bundle -cnotmatch '^[a-f0-9]{64}$' -or $review.child -cnotmatch '^[a-f0-9]{64}$' -or $review.fixture -cnotmatch '^[a-f0-9]{64}$'){return $null}
  if($m.source -cne $review.source -or $m.bundle -cne $review.bundle -or $m.child -cne $review.child -or $m.fixture -cne $review.fixture){return $null}
  $inventory=@($review.inventory.PSObject.Properties);if($inventory.Count -lt 5 -or $inventory.Count -gt 32){return $null}
  $actual=@(Get-ChildItem -LiteralPath $Directory -File);if($actual.Count -ne $inventory.Count){return $null}
  foreach($entry in $inventory){
   if($entry.Name -cnotmatch '^(?:[0-9]{6}\.json|provenance|result\.txt|resume-review|writer\.lock)$' -or [string]$entry.Value -cnotmatch '^[a-f0-9]{64}$'){return $null}
   $path=Join-Path $Directory $entry.Name;if(-not(Test-Path -LiteralPath $path -PathType Leaf) -or (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant() -cne $entry.Value){return $null}
  }
  $stages=@($review.stages);if($stages.Count -ne $j.rows.Count -or ($stages -join ',') -cne ($j.rows.stage -join ',') -or $stages -contains 'POLICY_ADMITTED' -or $stages -contains 'LOCK_ADMITTED'){return $null}
  $raw=[IO.File]::ReadAllText((Join-Path $Directory 'result.txt'));if($raw.Length -gt 65536){return $null};$result=$raw|ConvertFrom-Json
  if($review.primaryReason -cnotmatch '^INVALID:[A-Z0-9_]{1,120}$' -or $review.hostFailureCode -cnotmatch '^[A-Z0-9_]{1,120}$'){return $null}
  if($result.hostValidated -ne $true -or $result.hostFailureCode -cne $review.hostFailureCode -or $result.primary.reason -cne $review.primaryReason -or $result.primary.cleanup -cne 'UNVERIFIED' -or $result.reverseCleanup -cne 'OWN_REVERSE_REMOVED' -or $result.backendCleanup -cne 'STOPPED_SYNTHETIC_LEASE_AND_ENROLLMENT_RETAINED'){return $null}
  if($review.pairingSession.id -cnotmatch '^[a-f0-9-]{36}$' -or $review.pairingSession.disposition -cnotin @('OPEN','CANCELLED')){return $null}
  return $review
 }catch{return $null}
}
function Test-ResumableHistory([string]$Directory,[string]$CatalogPath=''){return $null -ne (Get-ResumableHistoryReview $Directory $CatalogPath)}
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
 if($Facts.backendDevice -and $Facts.savedDevice -and $Facts.savedMatches -and $Facts.identity -and -not $Facts.pending -and $Facts.credentialUsable -and $Facts.policyConsistent -and -not $Facts.historicalPartial){
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
Export-ModuleMember -Function Read-ResumeReview,Test-ResumableHistory,Get-ResumableHistoryReview,Resolve-ProductPreparation,Write-ResumeReview
