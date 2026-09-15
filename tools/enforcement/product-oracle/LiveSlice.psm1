Set-StrictMode -Version Latest
Import-Module (Join-Path $PSScriptRoot 'ProductOracle.psm1')
Import-Module (Join-Path $PSScriptRoot 'ProductTransport.psm1')
Import-Module (Join-Path $PSScriptRoot 'Canonical.psm1')
Import-Module (Join-Path $PSScriptRoot 'EnrollmentHost.psm1')
Import-Module (Join-Path $PSScriptRoot 'Journal.psm1')

function New-LiveSliceCallbacks([string]$Adb,[string]$Serial,[scriptblock]$Wire,[Security.SecureString]$Jwt,$Device,[string]$Directory,[bool]$RecoveryOnly=$false){
 $canonical=New-CanonicalCallbacks $Wire $Jwt $Device.id $Device.policy_epoch
 $s=@{request=0L;period=$null;sequence=-1L}
 $fixture={
  $s.request++;$raw=Invoke-ProductAdb $Adb $Serial @('shell','am','broadcast','--receiver-foreground','-n','dev.kidremote.spike.ordinary/.FixtureReceiver','--el','request',[string]$s.request)
  Convert-ProductFixture $raw $s.request
 }.GetNewClosure()
 $start={
  $null=Invoke-ProductAdb $Adb $Serial @('shell','am','start','-W','-n','dev.kidremote.spike.ordinary/.FixtureActivity')
  Start-Sleep -Milliseconds 1000
 }.GetNewClosure()
 $sync={
  $null=Invoke-ProductAdb $Adb $Serial @('shell','am','start','-W','-n','dev.kidremote.child.unassigned.debug/dev.kidremote.child.ChildActivity')
  Start-Sleep -Milliseconds 1000
 }.GetNewClosure()
 $initial={
  $timer=[Diagnostics.Stopwatch]::StartNew()
  while($timer.Elapsed.TotalSeconds -lt 30){
   try{$r=& $canonical.Initial;if($r.health -ceq 'UNRESTRICTED_OBSERVED:NONE'){$s.period=$r.period_key;$s.sequence=$r.sequence;return $r}}catch{if($_.Exception.Message -cnotin @('INVALID:REPORT_STALE_OR_CONCURRENT','INVALID:DEVICE_EPOCH_OR_POLICY')){throw}}
   Start-Sleep -Milliseconds 500
  };throw 'INVALID:INITIAL_REPORT_TIMEOUT'
 }.GetNewClosure()
 $report={param($v,$required)
  $timer=[Diagnostics.Stopwatch]::StartNew()
  while($timer.Elapsed.TotalSeconds -lt 30){
   try{$r=& $canonical.Report $v $required;return $r}catch{
    if($_.Exception.Message -cnotin @('INVALID:REPORT_STALE_OR_CONCURRENT','INVALID:REPORT_OR_CLEANUP_PRECONDITION')){throw}
   };Start-Sleep -Milliseconds 500
  };throw 'INVALID:REPORT_TIMEOUT'
 }.GetNewClosure()
 $status={param($id,$v)
  $timer=[Diagnostics.Stopwatch]::StartNew()
  while($timer.Elapsed.TotalSeconds -lt 30){if(& $canonical.Status $id $v){return $true};Start-Sleep -Milliseconds 500}
  return $false
 }.GetNewClosure()
 $operation={param($q)
  $r=Invoke-StableLabOperation $Wire $Jwt $q;Assert-ProductAccepted $r $q $Device.policy_epoch;return $r
 }.GetNewClosure()
 $ops=@{Initial=$initial;Operation=$operation;Report=$report;Status=$status;Sync=$sync;StartFixture=$start;Fixture=$fixture;BlockedFixture=$fixture
  Tap={param($p) $null=Invoke-ProductAdb $Adb $Serial @('shell','input','tap',[string]$p.probeX,[string]$p.probeY)}.GetNewClosure()
  Pause={Start-Sleep -Milliseconds 250}
 }
 if($RecoveryOnly){return $ops}
 $journal=New-DurableJournalCallback $Directory $true
 $ops.Attempt=$journal.Attempt;$ops.Journal=$journal.Journal
 return $ops
}
Export-ModuleMember -Function New-LiveSliceCallbacks
