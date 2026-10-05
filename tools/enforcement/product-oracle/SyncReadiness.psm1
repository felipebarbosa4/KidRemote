Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'Journal.psm1')
Import-Module (Join-Path $PSScriptRoot 'ResumeReview.psm1')
# Diagnostic projection only; no policy, enrollment, retry repair or fixture input.
function Assert-SyncReadinessInteger($Value,[long]$Minimum=0){
 if(($Value -isnot [int] -and $Value -isnot [long]) -or $Value -lt $Minimum -or $Value -gt 9007199254740991){throw 'INVALID:SYNC_NUMBER'}
}
function Convert-SyncReadinessPage($Page,$Expected){
 if($Page.protocol_version -ne 1 -or $Page.devices -isnot [Array] -or $Page.devices.Count -ne 1){throw 'INVALID:SYNC_DEVICE_SCOPE'}
 $d=$Page.devices[0]
 if($d.id -cne $Expected.id -or $d.policy_epoch -cne $Expected.epoch -or $d.revoked -isnot [bool] -or $d.revoked -or $d.policy_configured -isnot [bool] -or -not $d.policy_configured){throw 'INVALID:SYNC_DEVICE_SCOPE'}
 Assert-SyncReadinessInteger $d.version 1;Assert-SyncReadinessInteger $d.daily_limit_seconds 1
 if($d.version -ne $Expected.version -or $d.daily_limit_seconds -ne $Expected.limit){throw 'INVALID:SYNC_POLICY_CHANGED'}
 if($d.period_key -cnotmatch '^[1-9][0-9]{0,9}:\d{4}-\d{2}-\d{2}$'){throw 'INVALID:SYNC_PERIOD'}
 try{$server=[DateTimeOffset]::Parse($Page.server_utc)}catch{throw 'INVALID:SYNC_SERVER_TIME'}
 $r=$d.report;$report=$null
 if($null -ne $r){
  foreach($k in @('version','sequence','used_ms','remaining_ms','bonus_seconds')){Assert-SyncReadinessInteger $r.$k}
  foreach($k in @('manual_lock','restriction_required','restriction_applied')){if($r.$k -isnot [bool]){throw 'INVALID:SYNC_REPORT_BOOLEAN'}}
  if($r.version -gt $d.version -or $r.period_key -cnotmatch '^[1-9][0-9]{0,9}:\d{4}-\d{2}-\d{2}$' -or $r.health -cnotmatch '^[A-Z_]{1,64}:[A-Z_]{1,32}$'){throw 'INVALID:SYNC_REPORT_SCHEMA'}
  try{$received=[DateTimeOffset]::Parse($r.received_at)}catch{throw 'INVALID:SYNC_REPORT_TIME'}
  if($received -gt $server){throw 'INVALID:SYNC_REPORT_TIME'}
  $report=[pscustomobject]@{version=$r.version;sequence=$r.sequence;period=$r.period_key;received=$received;health=$r.health;remainingMs=$r.remaining_ms;manualLock=$r.manual_lock;restrictionRequired=$r.restriction_required;restrictionApplied=$r.restriction_applied}
 }
 return [pscustomobject]@{server=$server;period=$d.period_key;report=$report}
}
function Wait-SyncReadinessReport([hashtable]$Ops,$Expected,$Baseline){
 $sequence=if($null -eq $Baseline.report){-1L}else{[long]$Baseline.report.sequence}
 $lastElapsed=-1L;$lastServer=$Baseline.server;$firstWindow='NOT_YET_OBSERVED';$reads=0
 while($reads -lt 181){
  $before=& $Ops.Elapsed;Assert-SyncReadinessInteger $before
  if($before -gt 360000){break}
  $page=Convert-SyncReadinessPage (& $Ops.Read) $Expected;$reads++
  $elapsed=& $Ops.Elapsed;Assert-SyncReadinessInteger $elapsed
  if($elapsed -lt $lastElapsed -or $page.server -lt $lastServer){throw 'INVALID:SYNC_CLOCK_REGRESSION'}
  $lastElapsed=$elapsed;$lastServer=$page.server;$r=$page.report
  $fresh=$null -ne $r -and $r.sequence -gt $sequence -and $r.version -eq $Expected.version -and $r.period -ceq $page.period -and $r.received -ge $Baseline.server -and ($page.server-$r.received).TotalSeconds -le 30
  if($firstWindow -ceq 'NOT_YET_OBSERVED' -and ($elapsed -ge 30000 -or $fresh)){
   $firstWindow=if($fresh -and $elapsed -le 30000){'FRESH_REPORT_WITHIN_30S'}else{'NOT_OBSERVED_WITHIN_30S'}
   & $Ops.Record ([ordered]@{stage='INITIAL_WINDOW';elapsedMs=$elapsed;finding=$firstWindow})
  }
  if($fresh -and $elapsed -le 360000){
   return [pscustomobject]@{status='OBSERVED';finding='FRESH_AUTHENTICATED_REPORT';firstWindow=$firstWindow;elapsedMs=$elapsed;reads=$reads;report=[ordered]@{version=$r.version;sequence=$r.sequence;health=$r.health;remainingMs=$r.remainingMs;manualLock=$r.manualLock;restrictionRequired=$r.restrictionRequired;restrictionApplied=$r.restrictionApplied};enforcementAcceptance=$false}
  }
  if($elapsed -ge 360000){break};& $Ops.Pause
 }
 if($firstWindow -ceq 'NOT_YET_OBSERVED'){$firstWindow='NOT_OBSERVED_WITHIN_30S'}
 return [pscustomobject]@{status='INCOMPLETE';finding='NO_FRESH_REPORT_IN_DIAGNOSTIC_WINDOW';firstWindow=$firstWindow;elapsedMs=[Math]::Max(0,$lastElapsed);reads=$reads;report=$null;enforcementAcceptance=$false}
}
function Assert-SyncReadinessRetry($Retry){
 if($Retry.status -cne 'OBSERVED' -or $Retry.checksumValidity -cne 'VALID' -or $Retry.schemaValidity -cne 'VALID'){throw 'INVALID:SYNC_RETRY_UNVERIFIED'}
 if($Retry.stopped -isnot [bool] -or $Retry.pending -isnot [bool] -or $Retry.stopped -or $Retry.reason -cne 'NONE'){throw 'INVALID:SYNC_RETRY_HARD_STOP'}
 Assert-SyncReadinessInteger $Retry.delayMs
 if($Retry.delayMs -gt 300000){throw 'INVALID:SYNC_RETRY_DELAY_OUTSIDE_WINDOW'}
}
function Assert-SyncReadinessHistory([string]$Root,$Review){
 if($Review.attempt -cnotmatch '^[a-f0-9-]{36}$' -or $Review.observedResult.primaryReason -cne 'INITIAL_REPORT_TIMEOUT'){throw 'INVALID:SYNC_HISTORY_SCHEMA'}
 $folders=@(Get-ChildItem -LiteralPath $Root -Force)
 if($folders.Count -lt 1 -or $folders.Count -gt 30){throw 'INVALID:SYNC_HISTORY_BOUNDS'}
 $found=$false;$inventory=@{}
 foreach($dir in $folders){
  if(-not $dir.PSIsContainer -or ($dir.Attributes -band [IO.FileAttributes]::ReparsePoint) -or $dir.Name -cnotmatch '^[a-f0-9-]{36}$'){throw 'INVALID:SYNC_HISTORY_ENTRY'}
  $files=@(Get-ChildItem -LiteralPath $dir.FullName -Force)
  foreach($file in $files){
   if($file.PSIsContainer -or ($file.Attributes -band [IO.FileAttributes]::ReparsePoint) -or $file.Name -cnotmatch '^(?:[0-9]{6}\.json|provenance|result\.txt|resume-review|writer\.lock)$'){throw 'INVALID:SYNC_HISTORY_ENTRY'}
   $inventory[$dir.Name+'/'+$file.Name]=(Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
  }
  $j=Read-ProductJournal $dir.FullName
  if($j.partial){throw 'INVALID:SYNC_HISTORY_PARTIAL'}
  if($dir.Name -ceq $Review.attempt){
   $found=$true;$pinned=@($Review.durableJournal.inventory.PSObject.Properties)
   if($files.Count -ne $pinned.Count -or $j.verdict -cne 'INVALID' -or $j.cleanup -cne 'NOT_REQUIRED' -or ($j.rows.stage -join ',') -cne ($Review.durableJournal.rows.stage -join ',')){throw 'INVALID:SYNC_HISTORY_CHANGED'}
   foreach($p in $pinned){if($inventory[$dir.Name+'/'+$p.Name] -cne $p.Value){throw 'INVALID:SYNC_HISTORY_CHANGED'}}
  }elseif($j.rows.stage -contains 'POLICY_ADMITTED' -or $j.rows.stage -contains 'LOCK_ADMITTED' -or $j.rows.stage -contains 'UNLOCK_ADMITTED'){throw 'INVALID:SYNC_OTHER_POLICY_HISTORY'}
  elseif(-not (Test-ResumableHistory $dir.FullName)){
   if($j.verdict -cne 'INVALID' -or $j.cleanup -cne 'NOT_REQUIRED' -or @($j.rows|Where-Object{$_.stage -cnotin @('BEGIN','VERDICT','CLEANUP')}).Count){throw 'INVALID:SYNC_UNREVIEWED_HISTORY'}
  }
 }
 if(-not $found){throw 'INVALID:SYNC_HISTORY_MISSING'}
 return $inventory
}
function Assert-SyncReadinessLease($Backend,$Expected,$Review){
 $d=@($Backend.review.devices);$saved=$Backend.local.device
 if($Backend.review.owners -ne 1 -or $Backend.review.households -ne 1 -or $d.Count -ne 1 -or $null -eq $saved){throw 'INVALID:SYNC_RETAINED_LEASE_REQUIRED'}
 if($d[0].id -cne $Expected.id -or $d[0].epoch -cne $Expected.epoch -or $saved.id -cne $Expected.id -or $saved.policy_epoch -cne $Expected.epoch -or $d[0].configured -ne $true -or $d[0].manualLock -ne $false -or $d[0].usable -ne $true){throw 'INVALID:SYNC_RETAINED_DEVICE_CHANGED'}
 $expectedSessions=@($Review.backendObservation.review.sessions);$actual=@($Backend.review.sessions)
 if($actual.Count -ne $expectedSessions.Count){throw 'INVALID:SYNC_PAIRING_HISTORY_CHANGED'}
 foreach($s in $expectedSessions){$match=@($actual|Where-Object{$_.id -ceq $s.id});if($match.Count -ne 1 -or $match[0].device -cne $s.device -or $match[0].consumed -ne $s.consumed -or $match[0].cancelled -ne $s.cancelled){throw 'INVALID:SYNC_PAIRING_HISTORY_CHANGED'}}
}
function Get-SyncReadinessAction([string]$Action){
 switch -Exact ($Action){
  'ReadReverse' {return @('reverse','--list')}
  'Connect' {return @('reverse','--no-rebind','tcp:47366','tcp:47366')}
  'Disconnect' {return @('reverse','--remove','tcp:47366')}
  'Resume' {return @('shell','am','start','-W','-n','dev.kidremote.child.unassigned.debug/dev.kidremote.child.ChildActivity')}
  default {throw 'INVALID:SYNC_ACTION_REJECTED'}
 }
}
function Write-SyncReadinessEvent([string]$Path,$Record){
 # Only caller-built bounded technical records, never raw child/process content.
 $raw=$Record|ConvertTo-Json -Depth 8 -Compress
 if($raw.Length -gt 16384){throw 'INVALID:SYNC_EVIDENCE_BOUNDS'}
 $f=[IO.File]::Open($Path,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
 try{$bytes=(New-Object Text.UTF8Encoding($false)).GetBytes($raw);$f.Write($bytes,0,$bytes.Length);$f.Flush($true)}finally{$f.Dispose()}
}
Export-ModuleMember -Function Assert-SyncReadinessInteger,Convert-SyncReadinessPage,Wait-SyncReadinessReport,Assert-SyncReadinessRetry,Assert-SyncReadinessHistory,Assert-SyncReadinessLease,Get-SyncReadinessAction,Write-SyncReadinessEvent
