Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'ResumeReview.psm1')
Import-Module (Join-Path $PSScriptRoot 'ResumePreparation.psm1')
Import-Module (Join-Path $PSScriptRoot 'Journal.psm1')
$script:n=0;function Check($b){$script:n++;if(-not $b){throw "RESUME_CHECK_$script:n"}}
function Facts {return [pscustomobject]@{provenance=$true;owned=$true;compatible=$true;reverseAbsent=$true;historySafe=$true;metadataKnown=$true;noUnknownFiles=$true;package='LAB';historicalPartial=$true;backendDevice=$false;savedDevice=$false;savedMatches=$false;identity=$false;pending=$false;accounting=$false;credentialUsable=$false;policyConsistent=$false;noPolicyOrReport=$true;resetAttributable=$true}}
$f=Facts;$r=Resolve-ProductPreparation $f;Check ($r.path -ceq 'ENROLL');Check ($r.packageMode -ceq 'LAB_PACKAGE_UNPAIRED')
foreach($field in @('backendDevice','identity','pending','savedDevice')){$f=Facts;$f.$field=$true;Check ((Resolve-ProductPreparation $f).path -ceq 'RESET_ENROLL')}
foreach($field in @('provenance','owned','compatible','reverseAbsent','historySafe','metadataKnown','noUnknownFiles')){$f=Facts;$f.$field=$false;Check ((Resolve-ProductPreparation $f).path -ceq 'NONE')}
$f=Facts;$f.backendDevice=$true;$f.noPolicyOrReport=$false;Check ((Resolve-ProductPreparation $f).path -ceq 'NONE')
$f=Facts;$f.identity=$true;$f.resetAttributable=$false;Check ((Resolve-ProductPreparation $f).path -ceq 'NONE')
$f=Facts;$f.historicalPartial=$false;$f.backendDevice=$true;$f.savedDevice=$true;$f.savedMatches=$true;$f.identity=$true;$f.credentialUsable=$true;$f.policyConsistent=$true
$r=Resolve-ProductPreparation $f;Check ($r.path -ceq 'VERIFY_REUSE');Check ($r.credentialProof -ceq 'FRESH_ACK_REQUIRED_BEFORE_POLICY')
$f.savedMatches=$false;Check ((Resolve-ProductPreparation $f).path -ceq 'NONE')
$root=Join-Path ([IO.Path]::GetTempPath()) ('od51-resume-'+[Guid]::NewGuid());[void][IO.Directory]::CreateDirectory($root)
try{
 foreach($path in @('ENROLL','RESET_ENROLL','VERIFY_REUSE')){
  $dir=New-ProductJournal $root ('a'*40) ('b'*64) ('c'*64) ('d'*64) $true
  $r=Resolve-ProductPreparation (Facts);Write-ResumeReview $dir 'NONE' ('e'*64) $r
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
 Write-Output "OD51_RESUME_CHECKS=$script:n;DEVICE=NOT_INVOKED"
}finally{Remove-Item -LiteralPath $root -Recurse -Force}
