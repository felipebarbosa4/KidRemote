Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'ResumeReview.psm1')
Import-Module (Join-Path $PSScriptRoot 'ResumePreparation.psm1')
Import-Module (Join-Path $PSScriptRoot 'Journal.psm1')
$script:n=0;function Check($b){$script:n++;if(-not $b){throw "RESUME_CHECK_$script:n"}}
function Facts {return [pscustomobject]@{provenance=$true;owned=$true;compatible=$true;reverseAbsent=$true;historySafe=$true;metadataKnown=$true;noUnknownFiles=$true;package='LAB';historicalPartial=$true;backendDevice=$false;savedDevice=$false;savedMatches=$false;identity=$false;pending=$false;accounting=$false;credentialUsable=$false;policyConsistent=$false;noPolicyOrReport=$true;resetAttributable=$true}}
$f=Facts;$r=Resolve-ProductPreparation $f;Check ($r.path -ceq 'ENROLL');Check ($r.packageMode -ceq 'LAB_PACKAGE_UNPAIRED');Check ($r.reviewReason -ceq 'NONE');Check (@($r.failedChecks).Count -eq 0)
foreach($field in @('backendDevice','identity','pending')){$f=Facts;$f.$field=$true;$r=Resolve-ProductPreparation $f;Check ($r.path -ceq 'RESET_ENROLL');Check ($r.packageMode -cne 'LAB_PACKAGE_UNPAIRED')}
$f=Facts;$f.accounting=$true;$f.resetAttributable=$false;$r=Resolve-ProductPreparation $f;Check ($r.path -ceq 'NONE');Check ($r.packageMode -cne 'LAB_PACKAGE_UNPAIRED');Check ($r.reviewReason -ceq 'POLICY_STATE_AMBIGUOUS')
$typed=[ordered]@{provenance='PROVENANCE';owned='OWNERSHIP';compatible='BACKEND_COMPATIBILITY';reverseAbsent='REVERSE_ABSENT';historySafe='HISTORY_SAFE';metadataKnown='METADATA_KNOWN';noUnknownFiles='NO_UNKNOWN_FILES'}
foreach($field in $typed.Keys){$f=Facts;$f.$field=$false;$r=Resolve-ProductPreparation $f;Check ($r.path -ceq 'NONE');Check ($r.reviewReason -ceq $typed[$field]);Check ((@($r.failedChecks) -join ',') -ceq $typed[$field])}
$f=Facts;$f.metadataKnown=$false;$f.noUnknownFiles=$false;$r=Resolve-ProductPreparation $f;Check ((@($r.failedChecks) -join ',') -ceq 'METADATA_KNOWN,NO_UNKNOWN_FILES')
$f=Facts;$f.savedDevice=$true;$r=Resolve-ProductPreparation $f;Check ($r.path -ceq 'NONE');Check ($r.reviewReason -ceq 'SAVED_DEVICE_ORPHANED')
$f=Facts;$f.package='OTHER';$r=Resolve-ProductPreparation $f;Check ($r.reviewReason -ceq 'PACKAGE_PROVENANCE')
$f=Facts;$f.backendDevice=$true;$f.noPolicyOrReport=$false;$r=Resolve-ProductPreparation $f;Check ($r.path -ceq 'NONE');Check ($r.reviewReason -ceq 'POLICY_STATE_AMBIGUOUS')
$f=Facts;$f.identity=$true;$f.resetAttributable=$false;$r=Resolve-ProductPreparation $f;Check ($r.path -ceq 'NONE');Check ($r.reviewReason -ceq 'POLICY_STATE_AMBIGUOUS')
$f=Facts;$f.historicalPartial=$false;$f.backendDevice=$true;$f.savedDevice=$true;$f.savedMatches=$true;$f.identity=$true;$f.credentialUsable=$true;$f.policyConsistent=$true
$r=Resolve-ProductPreparation $f;Check ($r.path -ceq 'VERIFY_REUSE');Check ($r.credentialProof -ceq 'FRESH_ACK_REQUIRED_BEFORE_POLICY')
$f.savedMatches=$false;$r=Resolve-ProductPreparation $f;Check ($r.path -ceq 'NONE');Check ($r.reviewReason -ceq 'POLICY_STATE_AMBIGUOUS')
$root=Join-Path ([IO.Path]::GetTempPath()) ('od51-resume-'+[Guid]::NewGuid());[void][IO.Directory]::CreateDirectory($root)
try{
 foreach($path in @('ENROLL','RESET_ENROLL','VERIFY_REUSE')){
  $dir=New-ProductJournal $root ('a'*40) ('b'*64) ('c'*64) ('d'*64) $true
  $r=Resolve-ProductPreparation (Facts);Write-ResumeReview $dir 'NONE' ('e'*64) $r
  $saved=Read-ResumeReview $dir;Check ($saved.reviewReason -ceq 'NONE');Check (@($saved.failedChecks).Count -eq 0)
  $caught=$false;try{Write-ResumeReview $dir 'NONE' ('e'*64) $r}catch{$caught=$true};Check $caught
  $state=@{actions=@()};$ops=@{}
  foreach($action in @('Reset','CancelPairings','Reverse','Enroll','VerifyReuse','Consent','Configure','Normalize')){$a=$action;$ops[$a]={param($id) $j=Read-ProductJournal $dir;if(-not $j.rows.Count){throw 'NOT_ADMITTED'};$state.actions+=,$a}.GetNewClosure()}
  foreach($action in @('Install','Uninstall')){$ops[$action]={throw 'UNNECESSARY_REPLACEMENT'}}
  $result=Invoke-ResumePreparation $dir $ops $path;Check ($result.status -ceq 'PREPARED_NOT_PASS')
  Check ($state.actions -notcontains 'Install');Check ($state.actions -notcontains 'Uninstall')
  Check (($state.actions -contains 'Enroll') -eq ($path -cne 'VERIFY_REUSE'))
  Check (($state.actions -contains 'Reset') -eq ($path -ceq 'RESET_ENROLL'))
  $null=New-DurableJournalCallback $dir $true;Check $true
 }
 foreach($failed in @('Reset','CancelPairings','Reverse','Enroll','Consent','Configure')){
  $dir=New-ProductJournal $root ('a'*40) ('b'*64) ('c'*64) ('d'*64) $true;Write-ResumeReview $dir 'NONE' ('e'*64) (Resolve-ProductPreparation (Facts))
  $ops=@{};foreach($a in @('Reset','CancelPairings','Reverse','Enroll','Consent','Configure')){$ops[$a]={}}
  $ops[$failed]={throw 'INVALID:PAIRING_TIMEOUT'};$caught=$false;try{Invoke-ResumePreparation $dir $ops RESET_ENROLL}catch{$caught=$true};Check $caught
  $j=Read-ProductJournal $dir;Check ($j.verdict -ceq 'INVALID');Check ($j.cleanup -ceq 'UNVERIFIED')
 }
 # Exact historical sequence remains independently INVALID/UNVERIFIED after review.
 $dir=New-ProductJournal $root ('3693034816039de67087066f077e6e02a9507dd6') 'a4824b1e655b5ec3dcaf0d69fcb57516392a0ea9c270cc1865f7c735c63e40fa' 'f6d2a240fae179343d9eb19dfde7684ae6e241b35cebea8ce491205110f7ad56' '223219c17a31439b52698e769bdf03ead0998bbbe8bbb5c1b0ff5be3cfaf21dc' $true
 $metaPath=Join-Path $dir 'provenance';$meta=[IO.File]::ReadAllText($metaPath)|ConvertFrom-Json
 $meta.attempt='d9157ae6-a6ff-4849-919f-c8f13fe08f7e';[IO.File]::WriteAllText($metaPath,($meta|ConvertTo-Json -Compress))
 foreach($stage in @('BEGIN','PREMUTATION','UNINSTALL_ADMITTED','INSTALL_ADMITTED','REVERSE_ADMITTED','ENROLLMENT_ADMITTED','VERDICT','CLEANUP_ADMITTED','CLEANUP')){
  $value=switch($stage){'BEGIN'{'STARTED'} 'PREMUTATION'{'EXACT_OLD_AND_FIXTURE_VERIFIED'} 'VERDICT'{'INVALID'} 'CLEANUP'{'UNVERIFIED'} default{'OD50_FIXED_SCOPE'}}
  $null=Add-ProductJournal $dir ([Guid]::NewGuid().ToString()) $stage $value
 }
 [IO.File]::WriteAllText((Join-Path $dir 'result.txt'),(@{hostValidated=$true;primary=@{reason='INVALID:PAIRING_TIMEOUT';lastStage='ENROLLMENT_ADMITTED';cleanup='UNVERIFIED'};reverseCleanup='OWN_REVERSE_REMOVED';backendCleanup='STOPPED_SYNTHETIC_LEASE_AND_ENROLLMENT_RETAINED'}|ConvertTo-Json -Depth 4))
 Check (Test-ResumableHistory $dir)
 $before=(Read-ProductJournal $dir).previous
 $reviewDir=New-ProductJournal $root ('a'*40) ('b'*64) ('c'*64) ('d'*64) $true
 Write-ResumeReview $reviewDir $meta.attempt ('e'*64) (Resolve-ProductPreparation (Facts))
 Check ((Read-ResumeReview $reviewDir).historicalAttempt -ceq $meta.attempt)
 Check ((Read-ProductJournal $dir).previous -ceq $before)
 Check ((Read-ProductJournal $dir).cleanup -ceq 'UNVERIFIED')
 $typedDir=New-ProductJournal $root ('a'*40) ('b'*64) ('c'*64) ('d'*64) $true;$typedFacts=Facts;$typedFacts.noUnknownFiles=$false
 Write-ResumeReview $typedDir 'NONE' ('e'*64) (Resolve-ProductPreparation $typedFacts)
 $typedReview=Read-ResumeReview $typedDir;Check ($typedReview.reviewReason -ceq 'NO_UNKNOWN_FILES');Check ((@($typedReview.failedChecks) -join ',') -ceq 'NO_UNKNOWN_FILES')
 # Additional Lock admission is never reviewed away, even after a finalized INVALID.
 $null=Add-ProductJournal $dir ([Guid]::NewGuid().ToString()) UNLOCK_ADMITTED EXPECTED_VERSION:1
 Check (-not (Test-ResumableHistory $dir))
 [IO.File]::WriteAllText((Join-Path $reviewDir 'resume-review.tmp'),'truncated')
 $caught=$false;try{Read-ResumeReview $reviewDir}catch{$caught=$true};Check $caught
 # Opt-in runtime metadata never reads contents or reinterprets the historical parser.
 Import-Module (Join-Path $PSScriptRoot '../update-review/Review.psm1')
 $paths=Get-ReviewStatePaths $true;$lines=@()
 foreach($key in $paths.Keys){$lines+=($key+'|'+$(if($key -ceq 'runtime_profile'){'PRESENT|8'}else{'ABSENT|0'}))}
 $lines+=@('LINKS|0','TOTAL|1');$raw=$lines -join "`n"
 $parsed=Convert-ReviewState $raw $true;Check ($parsed.otherDurableFiles -eq 0);Check (-not $parsed.sufficientForEmptyStateReview)
 $caught=$false;try{Convert-ReviewState $raw}catch{$caught=$true};Check $caught
 Check ((Get-ReviewStateScript $true) -notmatch '(?m)^(cat|sqlite|am |pm clear)')
 Write-Output "OD51_RESUME_CHECKS=$script:n;DEVICE=NOT_INVOKED"
}finally{Remove-Item -LiteralPath $root -Recurse -Force}
