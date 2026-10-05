Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'SyncRetryDiagnostic.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'MetadataObservation.psm1') -Force
$n=0
function Check($value){$script:n++;if(-not $value){throw "RETRY_DIAGNOSTIC_CHECK_$script:n"}}
$fixtures=[IO.File]::ReadAllText((Join-Path $PSScriptRoot 'SyncRetryFixtures.json'))|ConvertFrom-Json
$keys='attemptCount,bootRecorded,checksumValidity,deadlineRecorded,delayMs,failureCode,legacyReasonDerived,pending,reason,schemaValidity,status,stopped'
foreach($case in $fixtures.cases){
 $r=Convert-Od51RetryProcessResult ([pscustomobject]@{stdout=$case.frame;exitCode=0;stderrPresent=$false;outputTooLarge=$false})
 Check ($r.status -ceq $case.status);Check ($r.failureCode -ceq $case.code)
 foreach($p in $case.expect.PSObject.Properties){Check ($r.($p.Name) -ceq $p.Value)}
 Check ((($r.PSObject.Properties.Name|Sort-Object) -join ',') -ceq $keys)
 $json=$r|ConvertTo-Json -Compress
 Check ($json -cnotmatch 'PRIVATE_|11111111|22222222|"identity"|OD51RETRY|"due"|"boot"')
 if($r.status -cne 'OBSERVED'){foreach($key in @('pending','stopped','reason','attemptCount','delayMs','bootRecorded','deadlineRecorded')){Check ($null -eq $r.$key)}}
}
foreach($pair in @(@('outputTooLarge','ADB_OUTPUT_TOO_LARGE'),@('stderrPresent','ADB_STDERR_PRESENT'),@('exitCode','ADB_EXIT_NONZERO'))){
 $p=[pscustomobject]@{stdout='PRIVATE_RAW_SENTINEL';exitCode=0;stderrPresent=$false;outputTooLarge=$false};$p.($pair[0])=if($pair[0] -ceq 'exitCode'){1}else{$true}
 $r=Convert-Od51RetryProcessResult $p;Check ($r.status -ceq 'INVALID');Check ($r.failureCode -ceq $pair[1]);Check (($r|ConvertTo-Json) -notmatch 'PRIVATE_')
}
$fixed=Get-Od51RetryScript;$cmd=@('shell','-T','run-as','dev.kidremote.child.unassigned.debug','sh')
Check (Test-Od51AdbCommand $cmd $fixed $fixed)
Check (-not(Test-Od51AdbCommand $cmd ($fixed+'echo unexpected') $fixed))
foreach($argsToReject in @(@('shell','cat','no_backup/sync-retry'),@('pull','no_backup/sync-retry','C:\temp\raw'),@('shell','am','start','-n','dev.kidremote.child.unassigned.debug/.ChildActivity'),@('reverse','tcp:47366','tcp:47366'))){Check (-not(Test-Od51AdbCommand $argsToReject '' $fixed))}
Check ($fixed -notmatch 'device-identity|\.bak|logcat|settings|appops|sqlite|curl|wget|touch|mkdir|\brm\b')
Write-Output "OD51_RETRY_DIAGNOSTIC_CHECKS=$n;SYNTHETIC_CASES=$($fixtures.cases.Count);RAW_BINDING_OUTPUT=ABSENT;DEVICE=NOT_INVOKED"
