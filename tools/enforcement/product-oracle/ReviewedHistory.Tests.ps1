Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'ResumeReview.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'Journal.psm1') -Force
$script:n=0;function Check($value){$script:n++;if(-not $value){throw "REVIEWED_HISTORY_CHECK_$script:n"}}
$root=Join-Path ([IO.Path]::GetTempPath()) ('od51-history-'+[Guid]::NewGuid());[void][IO.Directory]::CreateDirectory($root)
function New-ReviewedFixture([string[]]$Stages){
 $dir=New-ProductJournal $root ('a'*40) ('b'*64) ('c'*64) ('d'*64) $true
 foreach($stage in $Stages){
  $value=switch($stage){'BEGIN'{'STARTED'} 'VERDICT'{'INVALID'} 'CLEANUP'{'UNVERIFIED'} 'LOCK_ADMITTED'{'EXPECTED_VERSION:1'} default{'OD51_FIXED_SCOPE'}}
  $null=Add-ProductJournal $dir ([Guid]::NewGuid().ToString()) $stage $value
 }
 $cleanupFailure=$Stages -notcontains 'ENROLLMENT_ADMITTED'
 $result=@{hostValidated=$true;hostFailureCode=$(if($cleanupFailure){'NONE'}else{'SANITIZED_HOST_EXCEPTION'});primary=@{reason=$(if($cleanupFailure){'INVALID:PREPARATION_ORCHESTRATION_FAILED'}else{'INVALID:HOST_OR_TRANSPORT_FAILURE'});cleanup='UNVERIFIED'};reverseCleanup=$(if($cleanupFailure){'NOT_CREATED'}else{'OWN_REVERSE_REMOVED'});backendCleanup='STOPPED_SYNTHETIC_LEASE_AND_ENROLLMENT_RETAINED'}
 if($cleanupFailure){$result.preparationFailureStage='PAIRING_SESSION_CLEANUP';$result.preparationFailureCode='PREPARATION_ORCHESTRATION_FAILED'}
 [IO.File]::WriteAllText((Join-Path $dir 'result.txt'),($result|ConvertTo-Json -Depth 5))
 $meta=[IO.File]::ReadAllText((Join-Path $dir 'provenance'))|ConvertFrom-Json;$inventory=[ordered]@{}
 foreach($file in @(Get-ChildItem -LiteralPath $dir -File|Sort-Object Name)){$inventory[$file.Name]=(Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant()}
 $catalog=Join-Path $root ($meta.attempt+'.catalog.json')
 $review=[ordered]@{attempt=$meta.attempt;source=$meta.source;bundle=$meta.bundle;child=$meta.child;fixture=$meta.fixture;stages=$Stages;primaryReason=$result.primary.reason;hostFailureCode=$result.hostFailureCode;inventory=$inventory}
 if($cleanupFailure){$review.preparationFailureStage='PAIRING_SESSION_CLEANUP';$review.preparationFailureCode='PREPARATION_ORCHESTRATION_FAILED';$review.reverseCleanup='NOT_CREATED';$review.pairingResolution=@{id=[Guid]::NewGuid().ToString();from='OPEN';to='CANCELLED'}}
 else{$review.pairingSession=@{id=[Guid]::NewGuid().ToString();disposition='OPEN'}}
 [IO.File]::WriteAllText($catalog,(@{schema=1;reviews=@($review)}|ConvertTo-Json -Depth 8))
 return [pscustomobject]@{directory=$dir;catalog=$catalog}
}
try{
 $safe=New-ReviewedFixture @('BEGIN','PAIRING_CLEANUP_ADMITTED','REVERSE_ADMITTED','ENROLLMENT_ADMITTED','VERDICT','CLEANUP');Check ($null -ne (Get-ResumableHistoryReview $safe.directory $safe.catalog))
 $cleanupFailure=New-ReviewedFixture @('BEGIN','PAIRING_CLEANUP_ADMITTED','REVERSE_ADMITTED','VERDICT','CLEANUP');Check ($null -ne (Get-ResumableHistoryReview $cleanupFailure.directory $cleanupFailure.catalog))
 $policy=New-ReviewedFixture @('BEGIN','PAIRING_CLEANUP_ADMITTED','REVERSE_ADMITTED','ENROLLMENT_ADMITTED','SETUP_ADMITTED','POLICY_ADMITTED','VERDICT','CLEANUP');Check ($null -eq (Get-ResumableHistoryReview $policy.directory $policy.catalog))
 $lock=New-ReviewedFixture @('BEGIN','PAIRING_CLEANUP_ADMITTED','REVERSE_ADMITTED','ENROLLMENT_ADMITTED','SETUP_ADMITTED','POLICY_ADMITTED','LOCK_ADMITTED','VERDICT','CLEANUP');Check ($null -eq (Get-ResumableHistoryReview $lock.directory $lock.catalog))
 [IO.File]::WriteAllText((Join-Path $safe.directory 'unexpected'),'x');Check ($null -eq (Get-ResumableHistoryReview $safe.directory $safe.catalog))
 Write-Output "REVIEWED_HISTORY_CHECKS=$script:n;POLICY_AND_LOCK_BYPASS=REJECTED;IMMUTABLE_INVENTORY=PASS;DEVICE=NOT_INVOKED"
}finally{Remove-Item -LiteralPath $root -Recurse -Force}
