Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'SyncReadiness.psm1') -Force
$n=0
function Check([bool]$Value){$script:n++;if(-not $Value){throw "SYNC_READINESS_CHECK_$script:n"}}
function Reject([scriptblock]$Body,[string]$Code){$found='NONE';try{& $Body|Out-Null}catch{$found=$_.Exception.Message};Check ($found -ceq $Code)}
$expected=[pscustomobject]@{id='11111111-1111-4111-8111-111111111111';epoch='22222222-2222-4222-8222-222222222222';version=1;limit=3600}
function Page([bool]$Report=$false,[long]$Sequence=1){
 [pscustomobject]@{protocol_version=1;server_utc='2026-10-01T18:00:00Z';devices=@([pscustomobject]@{id=$expected.id;policy_epoch=$expected.epoch;revoked=$false;policy_configured=$true;version=1;daily_limit_seconds=3600;period_key='1:2026-10-01';report=$(if($Report){[pscustomobject]@{version=1;sequence=$Sequence;used_ms=0;remaining_ms=3600000;bonus_seconds=0;manual_lock=$false;restriction_required=$false;restriction_applied=$false;health='ENFORCEMENT_UNAVAILABLE:NONE';period_key='1:2026-10-01';received_at='2026-10-01T18:00:00Z'}}else{$null})})}
}
foreach($when in @(0L,45000L,224411L,999999L)){
 $state=@{time=0L;events=@()};$baseline=Convert-SyncReadinessPage (Page) $expected
 $ops=@{Elapsed={$state.time};Read={Page ($state.time -ge $when)};Pause={$state.time+=2000};Record={param($r)$state.events+=,$r}}
 $r=Wait-SyncReadinessReport $ops $expected $baseline
 Check (-not $r.enforcementAcceptance);Check ($r.reads -le 181)
 if($when -gt 360000){Check ($r.status -ceq 'INCOMPLETE');Check ($null -eq $r.report)}else{Check ($r.status -ceq 'OBSERVED');Check ($r.report.version -eq 1);Check (-not $r.report.restrictionApplied)}
 Check ($state.events.Count -eq 1)
 Check ($r.firstWindow -ceq $(if($when -eq 0){'FRESH_REPORT_WITHIN_30S'}else{'NOT_OBSERVED_WITHIN_30S'}))
}
# Existing report, old period and stale timestamp cannot be reused as a fresh device response.
foreach($kind in @('sameSequence','oldPeriod','stale')){
 $state=@{time=0L};$baseline=Convert-SyncReadinessPage (Page $true 1) $expected
 $page=Page $true 2
 if($kind -ceq 'sameSequence'){$page.devices[0].report.sequence=1}
 if($kind -ceq 'oldPeriod'){$page.devices[0].report.period_key='1:2026-09-30'}
 if($kind -ceq 'stale'){$page.devices[0].report.received_at='2026-10-01T17:59:00Z'}
 $ops=@{Elapsed={$state.time};Read={$page};Pause={$state.time+=2000};Record={param($r)}}
 Check ((Wait-SyncReadinessReport $ops $expected $baseline).status -ceq 'INCOMPLETE')
}
foreach($field in @('id','policy_epoch','revoked','policy_configured','version','daily_limit_seconds','period_key')){
 $p=Page;$d=$p.devices[0]
 $d.$field=switch($field){'id'{'33333333-3333-4333-8333-333333333333'} 'policy_epoch'{'33333333-3333-4333-8333-333333333333'} 'revoked'{$true} 'policy_configured'{$false} 'version'{2} 'daily_limit_seconds'{7200} 'period_key'{'INVALID'}}
 $code=if($field -in @('version','daily_limit_seconds')){'SYNC_POLICY_CHANGED'}elseif($field -ceq 'period_key'){'SYNC_PERIOD'}else{'SYNC_DEVICE_SCOPE'}
 Reject {Convert-SyncReadinessPage $p $expected} ('INVALID:'+$code)
}
foreach($field in @('version','sequence','used_ms','remaining_ms','bonus_seconds')){$p=Page $true;$p.devices[0].report.$field='1';Reject {Convert-SyncReadinessPage $p $expected} 'INVALID:SYNC_NUMBER'}
foreach($field in @('manual_lock','restriction_required','restriction_applied')){$p=Page $true;$p.devices[0].report.$field='false';Reject {Convert-SyncReadinessPage $p $expected} 'INVALID:SYNC_REPORT_BOOLEAN'}
$p=Page $true;$p.devices[0].report.received_at='2026-10-01T18:00:01Z';Reject {Convert-SyncReadinessPage $p $expected} 'INVALID:SYNC_REPORT_TIME'
$p=Page;$p.devices+=,$p.devices[0];Reject {Convert-SyncReadinessPage $p $expected} 'INVALID:SYNC_DEVICE_SCOPE'
$retry=[pscustomobject]@{status='OBSERVED';checksumValidity='VALID';schemaValidity='VALID';stopped=$false;pending=$true;reason='NONE';delayMs=224411}
Assert-SyncReadinessRetry $retry;Check $true
$retry.delayMs=300001;Reject {Assert-SyncReadinessRetry $retry} 'INVALID:SYNC_RETRY_DELAY_OUTSIDE_WINDOW'
$retry.delayMs=0;$retry.stopped=$true;$retry.reason='AUTH';Reject {Assert-SyncReadinessRetry $retry} 'INVALID:SYNC_RETRY_HARD_STOP'
$retry.status='INVALID';Reject {Assert-SyncReadinessRetry $retry} 'INVALID:SYNC_RETRY_UNVERIFIED'
foreach($action in @('ReadReverse','Connect','Disconnect','Resume')){Check (@(Get-SyncReadinessAction $action).Count -gt 1)}
foreach($action in @('LOCK','UNLOCK','Reset','ClearChildData','Install','Uninstall','OpenUsage','OpenAccessibility','RetryNow','enroll','echo secret')){Reject {Get-SyncReadinessAction $action} 'INVALID:SYNC_ACTION_REJECTED'}
# Runtime callback failure must not be converted into a successful report.
$ops=@{Elapsed={0L};Read={throw 'INVALID:HTTP_503'};Pause={};Record={}}
Reject {Wait-SyncReadinessReport $ops $expected (Convert-SyncReadinessPage (Page) $expected)} 'INVALID:HTTP_503'
$ops.Read={Page};$ops.Elapsed={-1L};Reject {Wait-SyncReadinessReport $ops $expected (Convert-SyncReadinessPage (Page) $expected)} 'INVALID:SYNC_NUMBER'
Write-Output "SYNC_READINESS_MODEL_CHECKS=$n;CLOCK=CONTROLLED;BACKEND=FAKE;DEVICE=NOT_INVOKED"
