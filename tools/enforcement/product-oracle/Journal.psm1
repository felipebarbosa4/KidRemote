Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
function Get-JHash([string]$Text){$h=[Security.Cryptography.SHA256]::Create();try{return ([BitConverter]::ToString($h.ComputeHash([Text.Encoding]::UTF8.GetBytes($Text)))).Replace('-','').ToLowerInvariant()}finally{$h.Dispose()}}
function Read-ProductJournal([string]$Directory){
 $metaRaw=[IO.File]::ReadAllText((Join-Path $Directory 'provenance'))
 try{$meta=$metaRaw|ConvertFrom-Json}catch{throw 'INVALID:JOURNAL_PROVENANCE'}
 if($meta.source -cnotmatch '^[a-f0-9]{40}$' -or $meta.attempt -cnotmatch '^[a-f0-9-]{36}$' -or $meta.scope -cne 'ONE_PRODUCT_SLICE'){throw 'INVALID:JOURNAL_PROVENANCE'}
 foreach($k in @('bundle','child','fixture')){if($meta.$k -cnotmatch '^[a-f0-9]{64}$'){throw 'INVALID:JOURNAL_PROVENANCE'}}
 $rows=@();$previous=Get-JHash $metaRaw;$verdict=$null;$cleanup='UNVERIFIED'
 foreach($file in @(Get-ChildItem -LiteralPath $Directory -Filter '*.json'|Sort-Object Name)){
  if($file.Name -cne ('{0:d6}.json' -f $rows.Count)){throw 'INVALID:JOURNAL_SEQUENCE'}
  try{$raw=[IO.File]::ReadAllText($file.FullName);$envelope=$raw|ConvertFrom-Json;if($envelope.sha256 -cne (Get-JHash $envelope.payload)){throw 'checksum'};$r=$envelope.payload|ConvertFrom-Json}catch{throw 'INVALID:JOURNAL_CORRUPT'}
  if($r.stage -cnotmatch '^(BEGIN|PREMUTATION|UNINSTALL_ADMITTED|INSTALL_ADMITTED|REVERSE_ADMITTED|ENROLLMENT_ADMITTED|SETUP_ADMITTED|POLICY_ADMITTED|CLEANUP_ADMITTED|LOCK_ADMITTED|UNLOCK_ADMITTED|OBSERVATION|VERDICT|CLEANUP)$' -or $r.value -cnotmatch '^[A-Z0-9_:-]{1,120}$' -or $r.event -cnotmatch '^[a-f0-9-]{36}$'){throw 'INVALID:JOURNAL_SCHEMA'}
  if($r.previous -cne $previous -or $r.sequence -ne $rows.Count){throw 'INVALID:JOURNAL_CHAIN'}
  if($r.stage -eq 'VERDICT'){if($null -ne $verdict -and $verdict -cne $r.value){throw 'INVALID:VERDICT_CHANGED'};$verdict=$r.value}
  if($r.stage -eq 'CLEANUP'){$cleanup=$r.value}
  $rows+=,$r;$previous=Get-JHash $raw
 }
 return [pscustomobject]@{rows=$rows;previous=$previous;verdict=$verdict;cleanup=$cleanup;partial=(@(Get-ChildItem -LiteralPath $Directory -Filter '*.tmp').Count -gt 0)}
}
function Add-ProductJournal([string]$Directory,[string]$EventId,[string]$Stage,[string]$Value,[string]$Fault='NONE'){
 if($EventId -cnotmatch '^[a-f0-9-]{36}$' -or $Stage -cnotmatch '^(BEGIN|PREMUTATION|UNINSTALL_ADMITTED|INSTALL_ADMITTED|REVERSE_ADMITTED|ENROLLMENT_ADMITTED|SETUP_ADMITTED|POLICY_ADMITTED|CLEANUP_ADMITTED|LOCK_ADMITTED|UNLOCK_ADMITTED|OBSERVATION|VERDICT|CLEANUP)$' -or $Value -cnotmatch '^[A-Z0-9_:-]{1,120}$'){throw 'INVALID:JOURNAL_SCHEMA'}
 $validValue=switch($Stage){
 'BEGIN' {$Value -ceq 'STARTED'}
 'PREMUTATION' {$Value -ceq 'EXACT_OLD_AND_FIXTURE_VERIFIED'}
 {$_ -in @('UNINSTALL_ADMITTED','INSTALL_ADMITTED','REVERSE_ADMITTED','ENROLLMENT_ADMITTED','SETUP_ADMITTED','POLICY_ADMITTED','CLEANUP_ADMITTED')} {$Value -ceq 'OD50_FIXED_SCOPE'}
 'LOCK_ADMITTED' {$Value -cmatch '^EXPECTED_VERSION:[0-9]{1,16}$'}
 'UNLOCK_ADMITTED' {$Value -cmatch '^EXPECTED_VERSION:[0-9]{1,16}$'}
 'OBSERVATION' {$Value -cin @('INDEPENDENT_BLOCKED','INDEPENDENT_RESTORED','TRANSPORT_UNAVAILABLE')}
 'VERDICT' {$Value -cin @('PASS','FAIL','INVALID')}
 'CLEANUP' {$Value -cin @('NOT_REQUIRED','UNVERIFIED','VERIFIED_CANONICAL_UNLOCK_AND_INDEPENDENT_INPUT')}
 }
 if(-not $validValue){throw 'INVALID:JOURNAL_SCHEMA'}
 $guard=[IO.File]::Open((Join-Path $Directory 'writer.lock'),[IO.FileMode]::OpenOrCreate,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)
 try{
  $state=Read-ProductJournal $Directory
  if($state.partial){throw 'INVALID:JOURNAL_PARTIAL_REQUIRES_REVIEW'}
  $old=@($state.rows|Where-Object{$_.event -ceq $EventId})
  if($old.Count){if($old.Count -ne 1 -or $old[0].stage -cne $Stage -or $old[0].value -cne $Value){throw 'INVALID:JOURNAL_RETRY_CONFLICT'};return $old[0]}
  if($Stage -eq 'VERDICT' -and ($Value -notin @('PASS','FAIL','INVALID') -or $null -ne $state.verdict)){throw 'INVALID:VERDICT_IMMUTABLE'}
  if($null -ne $state.verdict -and $Stage -notin @('CLEANUP','CLEANUP_ADMITTED','OBSERVATION','UNLOCK_ADMITTED')){throw 'INVALID:ATTEMPT_FINALIZED'}
  $row=[ordered]@{sequence=$state.rows.Count;previous=$state.previous;event=$EventId;stage=$Stage;value=$Value;utc=[DateTime]::UtcNow.ToString('o')}
  $payload=$row|ConvertTo-Json -Compress;$raw=@{payload=$payload;sha256=(Get-JHash $payload)}|ConvertTo-Json -Compress;$tmp=Join-Path $Directory ('{0:d6}.tmp' -f $state.rows.Count)
  if($Fault -eq 'BEFORE_WRITE'){throw 'INVALID:INJECTED_CRASH'}
  $bytes=[Text.Encoding]::UTF8.GetBytes($raw)
  $f=[IO.File]::Open($tmp,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
  try{$length=if($Fault -eq 'TRUNCATE'){[int]($bytes.Length/2)}else{$bytes.Length};$f.Write($bytes,0,$length);$f.Flush($true)}finally{$f.Dispose()}
  if($Fault -eq 'TRUNCATE'){throw 'INVALID:INJECTED_CRASH'}
  [IO.File]::Move($tmp,(Join-Path $Directory ('{0:d6}.json' -f $state.rows.Count)))
  if($Fault -eq 'AFTER_COMMIT'){throw 'INVALID:INJECTED_CRASH'}
  return [pscustomobject]$row
 }finally{$guard.Dispose()}
}
function New-ProductJournal([string]$Root,[string]$Source,[string]$BundleHash,[string]$ChildHash,[string]$FixtureHash,[bool]$Replacement=$false){
 if($Source -cnotmatch '^[a-f0-9]{40}$' -or @($BundleHash,$ChildHash,$FixtureHash|Where-Object{$_ -cnotmatch '^[a-f0-9]{64}$'}).Count){throw 'INVALID:JOURNAL_PROVENANCE'}
 $id=[Guid]::NewGuid().ToString();$dir=Join-Path $Root $id;[void][IO.Directory]::CreateDirectory($dir)
 $meta=[ordered]@{attempt=$id;source=$Source;bundle=$BundleHash;child=$ChildHash;fixture=$FixtureHash;target='SAMSUNG_SM_X400_ANDROID16_API36_BP4A.251205.006_PATCH2026-07-05';scope='ONE_PRODUCT_SLICE'}
 if($Replacement){$meta.replacement=[ordered]@{decision='OD-50';package='dev.kidremote.child.unassigned.debug';oldSha256='3ff9962ec6bf55eab20eda993e879112be9c04a3ed7c00e8287fc7660ad63ac9';oldSigner='771bc0fa9b91aecba8fd2d0e7d1e3af27237840198327731e098bb83dcbc97d7';oldVersion=1;newSha256='f6d2a240fae179343d9eb19dfde7684ae6e241b35cebea8ce491205110f7ad56';newSigner='638dfa66379788415c313d7a3ca96dcfcaf7e643c12bb0c4950b3046a3f76beb';newVersion=2}}
 $f=[IO.File]::Open((Join-Path $dir 'provenance'),[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
 try{$b=[Text.Encoding]::UTF8.GetBytes(($meta|ConvertTo-Json -Compress));$f.Write($b,0,$b.Length);$f.Flush($true)}finally{$f.Dispose()}
 return $dir
}
function New-DurableJournalCallback([string]$Directory,[bool]$Prepared=$false){
 $state=Read-ProductJournal $Directory
 if($state.partial -or ($state.rows.Count -and -not $Prepared)){throw 'INVALID:EXISTING_ATTEMPT_REVIEW_REQUIRED'}
 if($Prepared){$expected=@('BEGIN','PREMUTATION','UNINSTALL_ADMITTED','INSTALL_ADMITTED','REVERSE_ADMITTED','ENROLLMENT_ADMITTED','SETUP_ADMITTED','POLICY_ADMITTED');if($state.verdict -or (($state.rows|ForEach-Object{$_.stage}) -join ',') -cne ($expected -join ',')){throw 'INVALID:PREPARATION_JOURNAL_INCOMPLETE'}}
 $meta=[IO.File]::ReadAllText((Join-Path $Directory 'provenance'))|ConvertFrom-Json
 $cleanupAdmission=[Guid]::NewGuid().ToString()
 $callback={param($j)
  if($j.attempt -cne $meta.attempt){throw 'INVALID:ATTEMPT_ID_MISMATCH'}
  if($j.stage -in @('LOCK_ADMITTED','UNLOCK_ADMITTED')){
   if($Prepared -and $j.stage -ceq 'UNLOCK_ADMITTED'){$null=Add-ProductJournal $Directory $cleanupAdmission CLEANUP_ADMITTED OD50_FIXED_SCOPE}
   $id=if($j.stage -eq 'LOCK_ADMITTED'){$j.lockId}else{$j.unlockId}
   $null=Add-ProductJournal $Directory $id $j.stage ('EXPECTED_VERSION:'+$j.expectedVersion)
  }elseif($j.stage -in @('VERDICT','FINAL')){
   $null=Add-ProductJournal $Directory $j.attempt VERDICT $j.status
   if($j.stage -eq 'FINAL'){$null=Add-ProductJournal $Directory $j.cleanupId CLEANUP $j.cleanup}
  }else{throw 'INVALID:JOURNAL_STAGE'}
 }.GetNewClosure()
 return @{Attempt=$meta.attempt;Journal=$callback}
}
Export-ModuleMember -Function New-ProductJournal,Add-ProductJournal,Read-ProductJournal,New-DurableJournalCallback
