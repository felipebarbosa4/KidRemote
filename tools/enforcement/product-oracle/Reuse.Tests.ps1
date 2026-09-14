Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'Reuse.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'Journal.psm1') -Force
$script:n=0;function Check($b){$script:n++;if(-not $b){throw "REUSE_CHECK_$script:n"}}
$stages=@('Bundle','Tools','Lease','LiveHealth','Ports','Artifacts','Journal','ReadOnlyTarget')
foreach($failed in $stages){
 $s=@{calls=@();failed=$failed};$ops=@{}
 foreach($stage in $stages){$k=$stage;$ops[$k]={ $s.calls+=,$k;if($s.failed -ceq $k){throw 'synthetic failure'} }.GetNewClosure()}
 $caught=$false;try{Invoke-ProductHostGate $ops}catch{$caught=$_.Exception.Message -ceq 'INVALID:INVALID_HOST_PREFLIGHT'}
 Check $caught;Check ($s.calls[-1] -ceq $failed);Check ($s.calls.Count -eq [Array]::IndexOf($stages,$failed)+1)
}
$s=@{calls=@();failed='NONE'};$ops=@{}
foreach($stage in $stages){$k=$stage;$ops[$k]={ $s.calls+=,$k }.GetNewClosure()}
Invoke-ProductHostGate $ops;Check ($s.calls.Count -eq 8)
$root=Join-Path ([IO.Path]::GetTempPath()) ('od51-reuse-'+[Guid]::NewGuid());[void][IO.Directory]::CreateDirectory($root)
try{
 $dir=New-ProductJournal $root ('a'*40) ('b'*64) ('c'*64) ('d'*64) $true
 $s=@{actions=@();verified=$false}
 $ops=@{HostReady={};Configuration={};FixtureHash={'223219c17a31439b52698e769bdf03ead0998bbbe8bbb5c1b0ff5be3cfaf21dc'}
  Installed={[pscustomobject]@{package='dev.kidremote.child.unassigned.debug';sha256='f6d2a240fae179343d9eb19dfde7684ae6e241b35cebea8ce491205110f7ad56';signer='638dfa66379788415c313d7a3ca96dcfcaf7e643c12bb0c4950b3046a3f76beb';version=2;versionName='0.0.2-local-physical-lab';serviceRegistered=$true}}
  ReuseIdentityPermissions={$s.verified=$true}.GetNewClosure()
 }
 foreach($stage in @('Reverse','Resume','Normalize')){$k=$stage;$ops[$k]={param($id) if(-not $s.verified){throw 'missing gate'};$s.actions+=,$k;Check ($id -match '^[a-f0-9-]{36}$')}.GetNewClosure()}
 foreach($stage in @('Uninstall','Install','Enroll','Consent')){$ops[$stage]={throw 'REUSE_MUST_NOT_CALL_SETUP'}}
 $r=Invoke-ReusePreparation $dir $ops
 Check ($r.status -ceq 'PREPARED_NOT_PASS' -and $r.ownerSetupActions -eq 0)
 Check (($s.actions -join ',') -ceq 'Reverse,Resume,Normalize')
 $j=Read-ProductJournal $dir;Check (-not $j.verdict);Check ($j.rows.Count -eq 5)
 $cb=New-DurableJournalCallback $dir $true;Check ($cb.Attempt -match '^[a-f0-9-]{36}$')
 $caught=$false;try{Invoke-ReusePreparation $dir $ops}catch{$caught=$true};Check $caught
 foreach($failure in @('HostReady','Configuration','ReuseIdentityPermissions','Reverse','Resume','Normalize')){
  $d=New-ProductJournal $root ('a'*40) ('b'*64) ('c'*64) ('d'*64) $true;$old=$ops[$failure];$ops[$failure]={throw 'synthetic failure'}
  $caught=$false;try{Invoke-ReusePreparation $d $ops}catch{$caught=$true};Check $caught;Check (-not (Read-ProductJournal $d).verdict);$ops[$failure]=$old
 }
 Write-Output "OD51_HOST_GATE_REUSE_CHECKS=$script:n;DEVICE=NOT_INVOKED"
}finally{Remove-Item -LiteralPath $root -Recurse -Force}
