Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'ResumeReview.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'Journal.psm1') -Force
Import-Module (Join-Path $PSScriptRoot '../update-review/ProductRuntimeCatalog.psm1')
$script:n=0;function Check($value){$script:n++;if(-not $value){throw "REVIEWED_HISTORY_CHECK_$script:n"}}
$root=Join-Path ([IO.Path]::GetTempPath()) ('od51-history-'+[Guid]::NewGuid());[void][IO.Directory]::CreateDirectory($root)
function New-ReviewedFixture([string[]]$Stages,[bool]$PairingFailure=$false){
 $dir=New-ProductJournal $root ('a'*40) ('b'*64) ('c'*64) ('d'*64) $true
 foreach($stage in $Stages){
  $value=switch($stage){'BEGIN'{'STARTED'} 'VERDICT'{'INVALID'} 'CLEANUP'{'UNVERIFIED'} 'LOCK_ADMITTED'{'EXPECTED_VERSION:1'} default{'OD51_FIXED_SCOPE'}}
  $null=Add-ProductJournal $dir ([Guid]::NewGuid().ToString()) $stage $value
 }
 $cleanupFailure=$Stages -notcontains 'ENROLLMENT_ADMITTED'
 $result=@{hostValidated=$true;hostFailureCode=$(if($cleanupFailure){'NONE'}else{'SANITIZED_HOST_EXCEPTION'});primary=@{reason=$(if($cleanupFailure){'INVALID:PREPARATION_ORCHESTRATION_FAILED'}else{'INVALID:HOST_OR_TRANSPORT_FAILURE'});cleanup='UNVERIFIED'};reverseCleanup=$(if($cleanupFailure){'NOT_CREATED'}else{'OWN_REVERSE_REMOVED'});backendCleanup='STOPPED_SYNTHETIC_LEASE_AND_ENROLLMENT_RETAINED'}
 if($cleanupFailure){$result.preparationFailureStage='PAIRING_SESSION_CLEANUP';$result.preparationFailureCode='PREPARATION_ORCHESTRATION_FAILED'}
 if($PairingFailure){$result.hostFailureCode='NONE';$result.primary.reason='INVALID:PAIRING_SESSION_INVALID';$result.preparationFailureStage='PAIRING_SESSION_VALIDATE';$result.preparationFailureCode='PAIRING_SESSION_INVALID'}
 [IO.File]::WriteAllText((Join-Path $dir 'result.txt'),($result|ConvertTo-Json -Depth 5))
 $meta=[IO.File]::ReadAllText((Join-Path $dir 'provenance'))|ConvertFrom-Json;$inventory=[ordered]@{}
 foreach($file in @(Get-ChildItem -LiteralPath $dir -File|Sort-Object Name)){$inventory[$file.Name]=(Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant()}
 $catalog=Join-Path $root ($meta.attempt+'.catalog.json')
 $review=[ordered]@{attempt=$meta.attempt;source=$meta.source;bundle=$meta.bundle;child=$meta.child;fixture=$meta.fixture;stages=$Stages;primaryReason=$result.primary.reason;hostFailureCode=$result.hostFailureCode;inventory=$inventory}
 if($cleanupFailure){$review.preparationFailureStage='PAIRING_SESSION_CLEANUP';$review.preparationFailureCode='PREPARATION_ORCHESTRATION_FAILED';$review.reverseCleanup='NOT_CREATED';$review.pairingResolution=@{id=[Guid]::NewGuid().ToString();from='OPEN';to='CANCELLED'}}
 else{$review.pairingSession=@{id=[Guid]::NewGuid().ToString();disposition='OPEN'}}
 if($PairingFailure){$review.preparationFailureStage='PAIRING_SESSION_VALIDATE';$review.preparationFailureCode='PAIRING_SESSION_INVALID';$review.reverseCleanup='OWN_REVERSE_REMOVED'}
 [IO.File]::WriteAllText($catalog,(@{schema=1;reviews=@($review)}|ConvertTo-Json -Depth 8))
 return [pscustomobject]@{directory=$dir;catalog=$catalog}
}
function New-InterruptedFixture {
 $base=Join-Path $root ([Guid]::NewGuid().ToString())
 $catalogDir=Join-Path $base 'tools/enforcement/product-oracle';$evidenceDir=Join-Path $base 'docs/test-plans/evidence'
 [void][IO.Directory]::CreateDirectory($catalogDir);[void][IO.Directory]::CreateDirectory($evidenceDir)
 $dir=New-ProductJournal $base ('a'*40) ('b'*64) ('c'*64) ('d'*64) $true
 $resolution=[pscustomobject]@{classification='SAFE_RESUME_FROM_ENROLLMENT';packageMode='LAB_PACKAGE_UNPAIRED';path='ENROLL';credentialProof='NOT_ESTABLISHED';reviewReason='NONE';failedChecks=@();backendDevice=$false;localIdentity=$false;pairingPending=$false;localAccounting=$false}
 Write-ResumeReview $dir @() ('e'*64) $resolution
 $stages=@('BEGIN','PAIRING_CLEANUP_ADMITTED','REVERSE_ADMITTED','ENROLLMENT_ADMITTED')
 foreach($stage in $stages){$value=if($stage -ceq 'BEGIN'){'STARTED'}else{'OD51_FIXED_SCOPE'};$null=Add-ProductJournal $dir ([Guid]::NewGuid().ToString()) $stage $value}
 $m=[IO.File]::ReadAllText((Join-Path $dir 'provenance'))|ConvertFrom-Json;$inventory=[ordered]@{}
 foreach($f in @(Get-ChildItem -LiteralPath $dir -File|Sort-Object Name)){$inventory[$f.Name]=(Get-FileHash -LiteralPath $f.FullName).Hash.ToLowerInvariant()}
 $o=[IO.File]::ReadAllText((Join-Path $PSScriptRoot '../../../docs/test-plans/evidence/PRODUCT-ENROLLMENT-METADATA-2026-09-30.json'))|ConvertFrom-Json
 $o.attempt=[Guid]::NewGuid().ToString();$o.result.child.sha256=$m.child;$o.result.fixture.sha256=$m.fixture
 $evidence=Join-Path $evidenceDir 'SYNTHETIC-METADATA.json';[IO.File]::WriteAllText($evidence,($o|ConvertTo-Json -Depth 12))
 $review=[ordered]@{reviewKind='INTERRUPTED_PRE_SETUP';attempt=$m.attempt;source=$m.source;bundle=$m.bundle;child=$m.child;fixture=$m.fixture;stages=$stages;primaryStatus='NOT_RECORDED';primaryReason='NOT_RECORDED';primaryCleanup='NOT_RECORDED';inventory=$inventory;permittedPath='ENROLL';metadataObservation=@{attempt=$o.attempt;source=$o.source;sha256=(Get-FileHash -LiteralPath $evidence).Hash.ToLowerInvariant();path='../../../docs/test-plans/evidence/SYNTHETIC-METADATA.json'};pairingSession=@{id=[Guid]::NewGuid().ToString();disposition='OPEN'};pairingResolution=@{id=[Guid]::NewGuid().ToString();from='OPEN';to='CANCELLED'}}
 $catalog=Join-Path $catalogDir 'catalog.json';[IO.File]::WriteAllText($catalog,(@{schema=1;reviews=@($review)}|ConvertTo-Json -Depth 12))
 return [pscustomobject]@{directory=$dir;catalog=$catalog;evidence=$evidence}
}
function Write-InterruptedFixtureCatalog($Fixture,$Value){[IO.File]::WriteAllText($Fixture.catalog,($Value|ConvertTo-Json -Depth 12))}

try{
 $safe=New-ReviewedFixture @('BEGIN','PAIRING_CLEANUP_ADMITTED','REVERSE_ADMITTED','ENROLLMENT_ADMITTED','VERDICT','CLEANUP');Check ($null -ne (Get-ResumableHistoryReview $safe.directory $safe.catalog))
 $cleanupFailure=New-ReviewedFixture @('BEGIN','PAIRING_CLEANUP_ADMITTED','REVERSE_ADMITTED','VERDICT','CLEANUP');Check ($null -ne (Get-ResumableHistoryReview $cleanupFailure.directory $cleanupFailure.catalog))
 $pairingFailure=New-ReviewedFixture @('BEGIN','PAIRING_CLEANUP_ADMITTED','REVERSE_ADMITTED','ENROLLMENT_ADMITTED','VERDICT','CLEANUP') $true
 Check ($null -ne (Get-ResumableHistoryReview $pairingFailure.directory $pairingFailure.catalog))
 $wrong=[IO.File]::ReadAllText($pairingFailure.catalog)|ConvertFrom-Json;$wrong.reviews[0].preparationFailureCode='PAIRING_SCHEMA'
 [IO.File]::WriteAllText($pairingFailure.catalog,($wrong|ConvertTo-Json -Depth 8));Check ($null -eq (Get-ResumableHistoryReview $pairingFailure.directory $pairingFailure.catalog))
 $policy=New-ReviewedFixture @('BEGIN','PAIRING_CLEANUP_ADMITTED','REVERSE_ADMITTED','ENROLLMENT_ADMITTED','SETUP_ADMITTED','POLICY_ADMITTED','VERDICT','CLEANUP');Check ($null -eq (Get-ResumableHistoryReview $policy.directory $policy.catalog))
 $lock=New-ReviewedFixture @('BEGIN','PAIRING_CLEANUP_ADMITTED','REVERSE_ADMITTED','ENROLLMENT_ADMITTED','SETUP_ADMITTED','POLICY_ADMITTED','LOCK_ADMITTED','VERDICT','CLEANUP');Check ($null -eq (Get-ResumableHistoryReview $lock.directory $lock.catalog))
 [IO.File]::WriteAllText((Join-Path $safe.directory 'unexpected'),'x');Check ($null -eq (Get-ResumableHistoryReview $safe.directory $safe.catalog))
 $interrupted=New-InterruptedFixture
 Check ($null -ne (Get-ResumableHistoryReview $interrupted.directory $interrupted.catalog))
 $j=Read-ProductJournal $interrupted.directory;Check ($null -eq $j.verdict);Check ($j.rows.Count -eq 4);Check (-not(Test-Path (Join-Path $interrupted.directory 'result.txt')))
 foreach($bad in @('kind','path','hash','status','resolution')){
  $f=New-InterruptedFixture;$c=[IO.File]::ReadAllText($f.catalog)|ConvertFrom-Json
  switch($bad){'kind'{$c.reviews[0].reviewKind='ANY_INTERRUPTION'} 'path'{$c.reviews[0].permittedPath='RESET_ENROLL'} 'hash'{$c.reviews[0].metadataObservation.sha256='0'*64} 'status'{$c.reviews[0].primaryStatus='INVALID'} 'resolution'{$c.reviews[0].pairingResolution.id=$c.reviews[0].pairingSession.id}}
  Write-InterruptedFixtureCatalog $f $c;Check ($null -eq (Get-ResumableHistoryReview $f.directory $f.catalog))
 }
 foreach($bad in @('configuration','identity','pending','unknown','reverse')){
  $f=New-InterruptedFixture;$o=[IO.File]::ReadAllText($f.evidence)|ConvertFrom-Json
  switch($bad){'configuration'{$o.result.configuration.model='OTHER'} 'identity'{$o.result.knownPresent+=,'identity'} 'pending'{$o.result.knownPresent+=,'pairing'} 'unknown'{$o.result.unexpectedStructuralEntries[0].relativeName='not-reviewed.xml'} 'reverse'{$o.result.reverseAbsent=$false}}
  [IO.File]::WriteAllText($f.evidence,($o|ConvertTo-Json -Depth 12));$c=[IO.File]::ReadAllText($f.catalog)|ConvertFrom-Json;$c.reviews[0].metadataObservation.sha256=(Get-FileHash $f.evidence).Hash.ToLowerInvariant()
  Write-InterruptedFixtureCatalog $f $c;Check ($null -eq (Get-ResumableHistoryReview $f.directory $f.catalog))
 }
 foreach($stage in @('SETUP_ADMITTED','POLICY_ADMITTED','LOCK_ADMITTED','VERDICT')){
  $f=New-InterruptedFixture;$value=switch($stage){'VERDICT'{'INVALID'} 'LOCK_ADMITTED'{'EXPECTED_VERSION:1'} default{'OD51_FIXED_SCOPE'}}
  $null=Add-ProductJournal $f.directory ([Guid]::NewGuid().ToString()) $stage $value
  $c=[IO.File]::ReadAllText($f.catalog)|ConvertFrom-Json;$c.reviews[0].stages+=,$stage;$inventory=[ordered]@{}
  foreach($item in @(Get-ChildItem -LiteralPath $f.directory -File)){$inventory[$item.Name]=(Get-FileHash $item.FullName).Hash.ToLowerInvariant()};$c.reviews[0].inventory=$inventory
  Write-InterruptedFixtureCatalog $f $c;Check ($null -eq (Get-ResumableHistoryReview $f.directory $f.catalog))
 }
 $f=New-InterruptedFixture;[IO.File]::WriteAllText((Join-Path $f.directory '000004.tmp'),'partial');Check ($null -eq (Get-ResumableHistoryReview $f.directory $f.catalog))
 $f=New-InterruptedFixture;[void][IO.Directory]::CreateDirectory((Join-Path $f.directory 'unknown-directory'));Check ($null -eq (Get-ResumableHistoryReview $f.directory $f.catalog))
 $paths=Get-ReviewStatePaths $true;$rows=@($paths.Keys|ForEach-Object{[pscustomobject]@{kind=$_;presence='ABSENT';bytes=0}})
 $metadata=[pscustomobject]@{status='METADATA_ONLY';otherDurableFiles=0;files=$rows}
 Check (Test-InterruptedEnrollmentLiveState $metadata @() $null $true)
 foreach($kind in @('identity','pairing','accounting','writeIntent','syncPages','syncRetry','consent')){
  $row=@($metadata.files|Where-Object{$_.kind -ceq $kind})[0];$row.presence='PRESENT';Check (-not(Test-InterruptedEnrollmentLiveState $metadata @() $null $true));$row.presence='ABSENT'
 }
 Check (-not(Test-InterruptedEnrollmentLiveState $metadata @([pscustomobject]@{id='synthetic'}) $null $true))
 Check (-not(Test-InterruptedEnrollmentLiveState $metadata @() ([pscustomobject]@{id='synthetic'}) $true))
 Check (-not(Test-InterruptedEnrollmentLiveState $metadata @() $null $false))
 $metadata.otherDurableFiles=1;Check (-not(Test-InterruptedEnrollmentLiveState $metadata @() $null $true));$metadata.otherDurableFiles=0
 $metadata.files=@($metadata.files|Where-Object{$_.kind -cne 'identity'});Check (-not(Test-InterruptedEnrollmentLiveState $metadata @() $null $true))
 $j=Read-ProductJournal $interrupted.directory;Check ($null -eq $j.verdict);Check ($j.rows.Count -eq 4)
 Write-Output "REVIEWED_HISTORY_CHECKS=$script:n;POLICY_AND_LOCK_BYPASS=REJECTED;IMMUTABLE_INVENTORY=PASS;DEVICE=NOT_INVOKED"
}finally{Remove-Item -LiteralPath $root -Recurse -Force}
