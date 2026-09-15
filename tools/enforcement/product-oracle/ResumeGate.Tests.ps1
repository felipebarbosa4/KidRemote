Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'ResumeReview.psm1')
Import-Module (Join-Path $PSScriptRoot 'Journal.psm1')
Import-Module (Join-Path $PSScriptRoot 'Replacement.psm1')
# Execute the actual entrypoint's read-only gate with synthetic boundary callbacks.
$text=[IO.File]::ReadAllText((Join-Path $PSScriptRoot 'Run-ProductReplacement.ps1'))
if($text -notmatch '(?s)  ReadOnlyTarget=\{(.*?)\r?\n  \}\r?\n \}') {throw 'GATE_SOURCE_NOT_FOUND'}
$gate=[scriptblock]::Create($Matches[1]);$script:n=0
function Check($b){$script:n++;if(-not $b){throw "RESUME_GATE_$script:n"}}
$root=Join-Path ([IO.Path]::GetTempPath()) ('od51-gate-'+[Guid]::NewGuid());[void][IO.Directory]::CreateDirectory($root)
function Invoke-InventoryAdb {return 'SYNTHETIC_ONLY'}
function Select-InventoryTarget {return 'SYNTHETIC_ONLY'}
function New-LivePreparation {return $script:fakeLive}
$epoch=[Guid]::NewGuid().ToString();$device=[Guid]::NewGuid().ToString()
$record=[pscustomobject]@{package='dev.kidremote.child.unassigned.debug';sha256='f6d2a240fae179343d9eb19dfde7684ae6e241b35cebea8ce491205110f7ad56'
 signer='638dfa66379788415c313d7a3ca96dcfcaf7e643c12bb0c4950b3046a3f76beb';version=2;versionName='0.0.2-local-physical-lab';serviceRegistered=$true}
try{
 foreach($case in @('EMPTY','LOCAL_ONLY','PENDING','BACKEND_ONLY','REUSE','UNKNOWN','FOREIGN_EPOCH','POLICY_AMBIGUOUS')){
  $historicalPartial=$case -cnotin @('REUSE','FOREIGN_EPOCH');$Adb='SYNTHETIC_ONLY';$temporary=$root;$preparation=$null
  $directory=New-ProductJournal $root ('a'*40) ('b'*64) ('c'*64) ('d'*64) $true
  $metadata=[pscustomobject]@{status='METADATA_ONLY';otherDurableFiles=$(if($case -ceq 'UNKNOWN'){1}else{0});files=@([pscustomobject]@{kind='identity';presence=$(if($case -cin @('LOCAL_ONLY','REUSE','FOREIGN_EPOCH')){'PRESENT'}else{'ABSENT'})},[pscustomobject]@{kind='pairing';presence=$(if($case -ceq 'PENDING'){'PRESENT'}else{'ABSENT'})})}
  $d=[pscustomobject]@{id=$device;epoch=$epoch;configured=($case -cin @('REUSE','FOREIGN_EPOCH','POLICY_AMBIGUOUS'));manualLock=$false;reported=($case -cin @('REUSE','FOREIGN_EPOCH'));usable=$true}
  $backend=[pscustomobject]@{local=[pscustomobject]@{device=$(if($case -cin @('REUSE','FOREIGN_EPOCH')){[pscustomobject]@{id=$device;policy_epoch=$(if($case -ceq 'FOREIGN_EPOCH'){[Guid]::NewGuid().ToString()}else{$epoch})}}else{$null})};review=[pscustomobject]@{owners=1;households=1;devices=$(if($case -cin @('BACKEND_ONLY','REUSE','FOREIGN_EPOCH','POLICY_AMBIGUOUS')){@($d)}else{@()});sessions=@([pscustomobject]@{device=$device;consumed=$true})};compatibility=('e'*64);jwt=$null}
  $script:fakeLive=@{state=@{new=$false};ops=@{HostReady={};Configuration={};FixtureHash={'223219c17a31439b52698e769bdf03ead0998bbbe8bbb5c1b0ff5be3cfaf21dc'};Installed={$record}.GetNewClosure();Metadata={$metadata}.GetNewClosure()}}
  $h=@{backend=$backend;live=$null;reuse=$false;resolution=$null;serial=$null}
  $caught=$false;try{& $gate}catch{$caught=$true;if($_.Exception.Message -cne 'INVALID:INVALID_PARTIAL_STATE_REVIEW_REQUIRED'){throw}}
  $expected=switch($case){'EMPTY'{'ENROLL'} 'REUSE'{'VERIFY_REUSE'} {$_ -in @('UNKNOWN','FOREIGN_EPOCH','POLICY_AMBIGUOUS')}{'NONE'} default{'RESET_ENROLL'}}
  Check ($h.resolution.path -ceq $expected);Check ($caught -eq ($expected -ceq 'NONE'))
  Check ((Read-ResumeReview $directory).permittedPath -ceq $expected)
  Check ((Read-ProductJournal $directory).rows.Count -eq 0)
 }
 Write-Output "OD51_ACTUAL_READONLY_GATE_CHECKS=$script:n;ALL_TRANSPORTS=SYNTHETIC;DEVICE=NOT_INVOKED"
}finally{Remove-Item -LiteralPath $root -Recurse -Force}
