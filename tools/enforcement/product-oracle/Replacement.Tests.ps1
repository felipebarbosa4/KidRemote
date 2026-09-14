Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'Replacement.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'Journal.psm1') -Force
$root=Join-Path ([IO.Path]::GetTempPath()) ('od50-'+[Guid]::NewGuid().ToString());$script:checks=0
function Check($value){$script:checks++;if(-not $value){throw "REPLACEMENT_CHECK_$script:checks"}}
function MakeOps([string]$Fault){
 $s=@{actions=@();installed=0;fault=$Fault}
 $ops=@{}
 foreach($name in @('HostReady','Configuration','Uninstall','Install','Reverse','Enroll','Consent','Configure','Recovery')){
  $n=$name
  $ops[$name]={
   $s.actions+=,$n
   if($s.fault -ceq $n){throw 'INVALID:SYNTHETIC_FAILURE'}
   if($n -ceq 'Install'){$s.installed=1}
  }.GetNewClosure()
 }
 $ops.FixtureHash={if($s.fault -ceq 'Fixture'){'0'*64}else{'223219c17a31439b52698e769bdf03ead0998bbbe8bbb5c1b0ff5be3cfaf21dc'}}.GetNewClosure()
 $ops.Absent={$s.fault -cne 'Absent'}.GetNewClosure()
 $ops.Installed={
  $old=$s.installed -eq 0
  $hash=if($old){'3ff9962ec6bf55eab20eda993e879112be9c04a3ed7c00e8287fc7660ad63ac9'}else{'f6d2a240fae179343d9eb19dfde7684ae6e241b35cebea8ce491205110f7ad56'}
  if(($old -and $s.fault -ceq 'OldHash') -or (-not $old -and $s.fault -ceq 'NewHash')){$hash='0'*64}
  [pscustomobject]@{package='dev.kidremote.child.unassigned.debug';sha256=$hash;signer=$(if($old){'771bc0fa9b91aecba8fd2d0e7d1e3af27237840198327731e098bb83dcbc97d7'}else{'638dfa66379788415c313d7a3ca96dcfcaf7e643c12bb0c4950b3046a3f76beb'});version=$(if($old){1}else{2});versionName=$(if($old){'0.0.1-local'}else{'0.0.2-local-physical-lab'});serviceRegistered=(-not $old)}
 }.GetNewClosure()
 return @{ops=$ops;state=$s}
}
try{
 foreach($fault in @('NONE','HostReady','Configuration','Fixture','OldHash','Uninstall','Absent','Install','NewHash','Reverse','Enroll','Consent','Configure')){
  $d=New-ProductJournal $root ('a'*40) ('b'*64) ('c'*64) ('d'*64) $true;$o=MakeOps $fault
  $r=Invoke-ReplacementPreparation $d $o.ops;$j=Read-ProductJournal $d
  Check ($r.status -ceq $(if($fault -ceq 'NONE'){'PREPARED_NOT_PASS'}else{'INVALID'}))
  Check (-not $j.partial)
  if($fault -in @('HostReady','Configuration','Fixture','OldHash')){Check (-not ($o.state.actions -contains 'Uninstall'))}
  if($fault -ceq 'Install'){Check (($o.state.actions -contains 'Uninstall') -and -not ($o.state.actions -contains 'Enroll'))}
  if($fault -ceq 'NewHash'){Check (-not ($o.state.actions -contains 'Reverse'))}
  if($fault -ne 'NONE'){Check ($j.verdict -ceq 'INVALID');Check ($j.cleanup -in @('NOT_REQUIRED','UNVERIFIED'))}
  $before=$o.state.actions.Count;$rejected=$false
  try{$null=Invoke-ReplacementPreparation $d $o.ops}catch{$rejected=$_.Exception.Message -ceq 'INVALID:EXISTING_ATTEMPT_REVIEW_REQUIRED'}
  Check ($rejected -and $o.state.actions.Count -eq $before)
 }
 foreach($stage in @('UNINSTALL_ADMITTED','INSTALL_ADMITTED','REVERSE_ADMITTED','ENROLLMENT_ADMITTED','SETUP_ADMITTED','POLICY_ADMITTED')){
  $d=New-ProductJournal $root ('a'*40) ('b'*64) ('c'*64) ('d'*64) $true
  try{$null=Add-ProductJournal $d ([Guid]::NewGuid().ToString()) $stage OD50_FIXED_SCOPE TRUNCATE}catch{}
  $o=MakeOps NONE;$bad=$false;try{$null=Invoke-ReplacementPreparation $d $o.ops}catch{$bad=$true}
  Check ($bad -and $o.state.actions.Count -eq 0 -and (Read-ProductJournal $d).partial)
 }
 Write-Output "REPLACEMENT_SYNTHETIC_CHECKS=$script:checks;PHYSICAL_EXECUTION=NOT_RUN"
}finally{if(Test-Path -LiteralPath $root){Remove-Item -LiteralPath $root -Recurse -Force}}
