Set-StrictMode -Version Latest
Import-Module (Join-Path $PSScriptRoot 'Journal.psm1')
# No caller-supplied ADB commands or product state contents enter this model.
function Test-ResumableHistory([string]$Directory){
 $j=Read-ProductJournal $Directory
 $m=[IO.File]::ReadAllText((Join-Path $Directory 'provenance'))|ConvertFrom-Json
 if($j.partial -or $j.verdict -cne 'INVALID' -or $j.cleanup -cne 'UNVERIFIED'){return $false}
 if($m.attempt -cne 'd9157ae6-a6ff-4849-919f-c8f13fe08f7e' -or $m.source -cne '3693034816039de67087066f077e6e02a9507dd6'){return $false}
 if($m.bundle -cne 'a4824b1e655b5ec3dcaf0d69fcb57516392a0ea9c270cc1865f7c735c63e40fa' -or $m.child -cne 'f6d2a240fae179343d9eb19dfde7684ae6e241b35cebea8ce491205110f7ad56' -or $m.fixture -cne '223219c17a31439b52698e769bdf03ead0998bbbe8bbb5c1b0ff5be3cfaf21dc'){return $false}
 $resultPath=Join-Path $Directory 'result.txt';if(-not(Test-Path -LiteralPath $resultPath)){return $false}
 $raw=[IO.File]::ReadAllText($resultPath);if($raw.Length -gt 65536){return $false};$result=$raw|ConvertFrom-Json
 if($result.hostValidated -ne $true -or $result.primary.reason -cne 'INVALID:PAIRING_TIMEOUT' -or $result.primary.lastStage -cne 'ENROLLMENT_ADMITTED' -or $result.primary.cleanup -cne 'UNVERIFIED' -or $result.reverseCleanup -cne 'OWN_REVERSE_REMOVED' -or $result.backendCleanup -cne 'STOPPED_SYNTHETIC_LEASE_AND_ENROLLMENT_RETAINED'){return $false}
 $expected='BEGIN,PREMUTATION,UNINSTALL_ADMITTED,INSTALL_ADMITTED,REVERSE_ADMITTED,ENROLLMENT_ADMITTED,VERDICT,CLEANUP_ADMITTED,CLEANUP'
 return (($j.rows.stage -join ',') -ceq $expected)
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
 $failed=@($record.failedChecks)
 if($record.kind -cne 'RESUME_REVIEW' -or $record.format -ne 1 -or $record.attempt -cne $m.attempt -or $record.source -cne $m.source -or $record.bundle -cne $m.bundle -or $record.compatibility -cnotmatch '^[a-f0-9]{64}$' -or $failed.Count -gt 10 -or @($failed|Where-Object{$_ -cnotin $allowed}).Count -or ($failed.Count -and $record.reviewReason -cne $failed[0]) -or (-not $failed.Count -and $record.reviewReason -cne 'NONE')){throw 'INVALID:RESUME_REVIEW_SCHEMA'}
 return $record
}
function Write-ResumeReview([string]$Directory,[string]$HistoricalAttempt,[string]$Digest,$Resolution){
 $m=[IO.File]::ReadAllText((Join-Path $Directory 'provenance'))|ConvertFrom-Json
 $allowed=@('PROVENANCE','OWNERSHIP','BACKEND_COMPATIBILITY','REVERSE_ABSENT','HISTORY_SAFE','METADATA_KNOWN','NO_UNKNOWN_FILES','PACKAGE_PROVENANCE','SAVED_DEVICE_ORPHANED','POLICY_STATE_AMBIGUOUS');$failed=@($Resolution.failedChecks)
 if($Digest -cnotmatch '^[a-f0-9]{64}$' -or $HistoricalAttempt -cnotmatch '^(NONE|[a-f0-9-]{36})$' -or $Resolution.classification -cnotin @('SAFE_REUSE_ENROLLED','SAFE_RESUME_FROM_ENROLLMENT','SAFE_RESET_SYNTHETIC_KIDREMOTE_STATE_AND_REENROLL','INVALID_PARTIAL_STATE_REVIEW_REQUIRED') -or $failed.Count -gt 10 -or @($failed|Where-Object{$_ -cnotin $allowed}).Count -or ($failed.Count -and $Resolution.reviewReason -cne $failed[0]) -or (-not $failed.Count -and $Resolution.reviewReason -cne 'NONE')){throw 'INVALID:RESUME_REVIEW_SCHEMA'}
 $record=[ordered]@{kind='RESUME_REVIEW';format=1;attempt=$m.attempt;historicalAttempt=$HistoricalAttempt;source=$m.source;bundle=$m.bundle;utc=[DateTime]::UtcNow.ToString('o');compatibility=$Digest;classification=$Resolution.classification;packageMode=$Resolution.packageMode;permittedPath=$Resolution.path;credentialProof=$Resolution.credentialProof;reviewReason=$Resolution.reviewReason;failedChecks=@($failed);backendDevice=$Resolution.backendDevice;localIdentity=$Resolution.localIdentity;pairingPending=$Resolution.pairingPending;localAccounting=$Resolution.localAccounting;historicalVerdict='UNCHANGED';historicalCleanup='UNCHANGED'}
 $path=Join-Path $Directory 'resume-review';$tmp=$path+'.tmp'
 if((Test-Path -LiteralPath $path) -or (Test-Path -LiteralPath $tmp)){throw 'INVALID:RESUME_REVIEW_IMMUTABLE'}
 $payload=$record|ConvertTo-Json -Compress;$envelope=@{payload=$payload;sha256=(Get-ResumeHash $payload)}|ConvertTo-Json -Compress
 $f=[IO.File]::Open($tmp,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
 try{$bytes=[Text.Encoding]::UTF8.GetBytes($envelope);$f.Write($bytes,0,$bytes.Length);$f.Flush($true)}finally{$f.Dispose()}
 [IO.File]::Move($tmp,$path)
}
Export-ModuleMember -Function Read-ResumeReview,Test-ResumableHistory,Resolve-ProductPreparation,Write-ResumeReview
