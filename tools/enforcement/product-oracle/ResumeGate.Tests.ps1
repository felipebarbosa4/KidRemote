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
 foreach($case in @('EMPTY','OEM_OBSERVED','LOCAL_ONLY','PENDING','ACCOUNTING','BACKEND_ONLY','REUSE','METADATA_UNKNOWN','UNKNOWN','ORPHAN','OLD_PACKAGE','FOREIGN_EPOCH','POLICY_AMBIGUOUS')){
  $historicalPartial=$case -cnotin @('REUSE','FOREIGN_EPOCH');$Adb='SYNTHETIC_ONLY';$temporary=$root;$preparation=$null
  $directory=New-ProductJournal $root ('a'*40) ('b'*64) ('c'*64) ('d'*64) $true
  $metadata=[pscustomobject]@{status=$(if($case -ceq 'METADATA_UNKNOWN'){'UNKNOWN'}else{'METADATA_ONLY'});otherDurableFiles=$(if($case -ceq 'UNKNOWN'){1}else{0});files=@(
   [pscustomobject]@{kind='identity';presence=$(if($case -cin @('LOCAL_ONLY','REUSE','FOREIGN_EPOCH')){'PRESENT'}else{'ABSENT'})},
   [pscustomobject]@{kind='pairing';presence=$(if($case -ceq 'PENDING'){'PRESENT'}else{'ABSENT'})},
   [pscustomobject]@{kind='accounting';presence=$(if($case -ceq 'ACCOUNTING'){'PRESENT'}else{'ABSENT'})},
   [pscustomobject]@{kind='runtime_profile';presence='PRESENT'},
   [pscustomobject]@{kind='runtime_work_no_backup';presence='PRESENT'},
   [pscustomobject]@{kind='runtime_work_no_backup_wal';presence='PRESENT'},
   [pscustomobject]@{kind='runtime_work_no_backup_shm';presence='PRESENT'},
   [pscustomobject]@{kind='runtime_samsung_ids';presence='PRESENT'}
  )}
  $d=[pscustomobject]@{id=$device;epoch=$epoch;configured=($case -cin @('REUSE','FOREIGN_EPOCH','POLICY_AMBIGUOUS'));manualLock=$false;reported=($case -cin @('REUSE','FOREIGN_EPOCH'));usable=$true}
  $backend=[pscustomobject]@{local=[pscustomobject]@{device=$(if($case -cin @('REUSE','FOREIGN_EPOCH','ORPHAN')){[pscustomobject]@{id=$device;policy_epoch=$(if($case -ceq 'FOREIGN_EPOCH'){[Guid]::NewGuid().ToString()}else{$epoch})}}else{$null})};review=[pscustomobject]@{owners=1;households=1;devices=$(if($case -cin @('BACKEND_ONLY','REUSE','FOREIGN_EPOCH','POLICY_AMBIGUOUS')){@($d)}else{@()});sessions=@([pscustomobject]@{device=$device;consumed=$true})};compatibility=('e'*64);jwt=$null}
  $installed=if($case -ceq 'OLD_PACKAGE'){[pscustomobject]@{package='dev.kidremote.child.unassigned.debug';sha256='3ff9962ec6bf55eab20eda993e879112be9c04a3ed7c00e8287fc7660ad63ac9';signer='771bc0fa9b91aecba8fd2d0e7d1e3af27237840198327731e098bb83dcbc97d7';version=1;versionName='0.0.1-local';serviceRegistered=$false}}else{$record}
  $backendBefore=$backend|ConvertTo-Json -Depth 8 -Compress;$metadataBefore=$metadata|ConvertTo-Json -Depth 8 -Compress
  $script:fakeLive=@{state=@{new=$false};ops=@{HostReady={};Configuration={};FixtureHash={'223219c17a31439b52698e769bdf03ead0998bbbe8bbb5c1b0ff5be3cfaf21dc'};Installed={$installed}.GetNewClosure();Metadata={$metadata}.GetNewClosure()}}
  $h=@{backend=$backend;live=$null;reuse=$false;resolution=$null;serial=$null}
  $caught=$false;try{& $gate}catch{$caught=$true;if($_.Exception.Message -cne 'INVALID:INVALID_PARTIAL_STATE_REVIEW_REQUIRED'){throw}}
  $expected=switch($case){{$_ -in @('EMPTY','OEM_OBSERVED')}{'ENROLL'} 'REUSE'{'VERIFY_REUSE'} {$_ -in @('METADATA_UNKNOWN','UNKNOWN','ORPHAN','OLD_PACKAGE','FOREIGN_EPOCH','POLICY_AMBIGUOUS','ACCOUNTING')}{'NONE'} default{'RESET_ENROLL'}}
  $reason=switch($case){'METADATA_UNKNOWN'{'METADATA_KNOWN'} 'UNKNOWN'{'NO_UNKNOWN_FILES'} 'ORPHAN'{'SAVED_DEVICE_ORPHANED'} 'OLD_PACKAGE'{'PACKAGE_PROVENANCE'} {$_ -in @('FOREIGN_EPOCH','POLICY_AMBIGUOUS','ACCOUNTING')}{'POLICY_STATE_AMBIGUOUS'} default{'NONE'}}
  Check ($h.resolution.path -ceq $expected);Check ($caught -eq ($expected -ceq 'NONE'))
  if($case -cin @('LOCAL_ONLY','PENDING','ACCOUNTING')){Check ($h.resolution.packageMode -cne 'LAB_PACKAGE_UNPAIRED')}
  if($case -ceq 'OEM_OBSERVED'){Check ($h.resolution.packageMode -ceq 'LAB_PACKAGE_UNPAIRED');Check ($h.resolution.classification -ceq 'SAFE_RESUME_FROM_ENROLLMENT')}
  $persisted=Read-ResumeReview $directory;Check ($persisted.permittedPath -ceq $expected);Check ($persisted.reviewReason -ceq $reason)
  $reported=(@{preparation=$h.resolution}|ConvertTo-Json -Depth 6)|ConvertFrom-Json
  Check ($reported.preparation.reviewReason -ceq $reason);Check ((@($reported.preparation.failedChecks) -join ',') -ceq (@($h.resolution.failedChecks) -join ','))
  Check ((Read-ProductJournal $directory).rows.Count -eq 0)
  Check (($backend|ConvertTo-Json -Depth 8 -Compress) -ceq $backendBefore);Check (($metadata|ConvertTo-Json -Depth 8 -Compress) -ceq $metadataBefore)
 }
 Write-Output "OD51_ACTUAL_READONLY_GATE_CHECKS=$script:n;ALL_TRANSPORTS=SYNTHETIC;DEVICE=NOT_INVOKED"
}finally{Remove-Item -LiteralPath $root -Recurse -Force}
