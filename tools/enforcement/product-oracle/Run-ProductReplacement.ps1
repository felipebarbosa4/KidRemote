param([string]$Adb='C:\platform-tools\adb.exe',[string]$ExpectedManifestHash)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
# Real Windows supervisor validation failed; fail before imports, ADB, backend or mutation.
# No owner bundle/command may bypass this until the complete path is validated.
throw 'INVALID:OD50_LIVE_SUPERVISOR_VALIDATION_BLOCKED'
# Frozen entrypoint is copied to bundle root. No ADB/HTTP until manifest/tool validation.
$directory=$null;$backend=$null;$live=$null;$serial=$null;$temporary=$null;$primary=$null;$backendCleanup='NOT_STARTED';$reverseCleanup='NOT_CREATED';$recovery='NOT_REQUIRED';$source='UNSPECIFIED'
try{
 $manifestPath=Join-Path $PSScriptRoot 'bundle.json'
 if($ExpectedManifestHash -cnotmatch '^[a-f0-9]{64}$' -or (Get-FileHash -LiteralPath $manifestPath).Hash.ToLowerInvariant() -cne $ExpectedManifestHash){throw 'INVALID:BUNDLE_HASH'}
 $m=[IO.File]::ReadAllText($manifestPath)|ConvertFrom-Json
 if($m.scope -cne 'OD50_ONE_DESTRUCTIVE_PRODUCT_SLICE' -or $m.source -cnotmatch '^[a-f0-9]{40}$' -or $m.readiness -cne 'READY' -or $m.files.Count -lt 10 -or $m.files.Count -gt 2000){throw 'INVALID:BUNDLE_SCHEMA'}
 $seen=@{}
 foreach($f in $m.files){
  if($f.name -cnotmatch '^[A-Za-z0-9_./-]+$' -or $f.name -match '(^|/)\.\.?(/|$)' -or $seen.ContainsKey($f.name) -or $f.sha256 -cnotmatch '^[a-f0-9]{64}$'){throw 'INVALID:BUNDLE_FILE_SCHEMA'}
  $seen[$f.name]=$true
  if((Get-FileHash -LiteralPath (Join-Path $PSScriptRoot $f.name)).Hash.ToLowerInvariant() -cne $f.sha256){throw 'INVALID:BUNDLE_FILE_HASH'}
 }
 if(-not $seen.ContainsKey('Start-ProductSlice.ps1') -or -not $seen.ContainsKey('lab-reference.apk') -or -not $seen.ContainsKey('host-qr.jar') -or -not $seen.ContainsKey('zxing-core.jar')){throw 'INVALID:BUNDLE_REQUIRED_FILES'}
 $source=$m.source;$sourceRoot=Join-Path $PSScriptRoot 'source';$modules=Join-Path $sourceRoot 'tools/enforcement/product-oracle'
 foreach($n in @('BackendHost','Journal','Replacement','ReplacementAdb','ReadOnly','Canonical','EnrollmentHost','LivePreparation','LiveSlice','ProductOracle','ProductTransport')){Import-Module (Join-Path $modules ($n+'.psm1')) -Force}
 Import-Module (Join-Path $sourceRoot 'tools/enforcement/update-review/Review.psm1') -Force
 $java='C:\Program Files\Android\Android Studio\jbr\bin\java.exe';$jar=Join-Path $env:LOCALAPPDATA 'Android\Sdk\build-tools\37.0.0\lib\apksigner.jar'
 if((Get-FileHash -LiteralPath $java).Hash.ToLowerInvariant() -cne $m.javaSha256 -or (Get-FileHash -LiteralPath $jar).Hash.ToLowerInvariant() -cne $m.apksignerSha256){throw 'INVALID:SDK_PROVENANCE'}
 if($Adb -cne 'C:\platform-tools\adb.exe'){throw 'INVALID:FIXED_ADB_REQUIRED'}
 $root=Join-Path $env:LOCALAPPDATA 'KidRemote\product-slice-attempts';[void][IO.Directory]::CreateDirectory($root)
 # Restart is review-only. No new uninstall can hide an unfinished/ambiguous attempt.
 foreach($old in @(Get-ChildItem -LiteralPath $root -Directory)){
  $previous=Read-ProductJournal $old.FullName
  if($previous.partial -or -not $previous.verdict -or $previous.cleanup -ceq 'UNVERIFIED'){throw 'INVALID:PRIOR_ATTEMPT_REVIEW_REQUIRED'}
 }
 $directory=New-ProductJournal $root $source $ExpectedManifestHash 'f6d2a240fae179343d9eb19dfde7684ae6e241b35cebea8ce491205110f7ad56' '223219c17a31439b52698e769bdf03ead0998bbbe8bbb5c1b0ff5be3cfaf21dc' $true
 $temporary=Join-Path $directory 'temporary';[void][IO.Directory]::CreateDirectory($temporary)
 Write-Host 'Preparando backend local isolado; nenhuma substituição do tablet foi admitida ainda.'
 $backend=Start-ProductBackend $sourceRoot
 $wire={param($s,$p,$method,$body,$jwt) Invoke-LabWire $s $p $method $body $jwt}
 $jwt=New-LabParent $wire
 $serial=Select-InventoryTarget (Invoke-InventoryAdb $Adb '' @('devices'))
 $live=New-LivePreparation $Adb $serial $PSScriptRoot $temporary $jwt
 $prepared=Invoke-ReplacementPreparation $directory $live.ops
 if($prepared.status -cne 'PREPARED_NOT_PASS'){$primary=$prepared}
 else{
  $ops=New-LiveSliceCallbacks $Adb $serial $wire $jwt $live.state.device $directory
  $read=$live.read
  $ops.Preflight={
   $i=Invoke-ReadOnlyInventory $read
   if($i.classification -ceq 'CONFIGURATION_MISMATCH' -or $i.child.sha256 -cne 'f6d2a240fae179343d9eb19dfde7684ae6e241b35cebea8ce491205110f7ad56' -or $i.fixture.sha256 -cne '223219c17a31439b52698e769bdf03ead0998bbbe8bbb5c1b0ff5be3cfaf21dc' -or $i.accessibility -cne 'ENABLED' -or $i.usageAccess -cne 'ENABLED'){throw 'INVALID:FINAL_SETUP_PROVENANCE'}
  }.GetNewClosure()
  Write-Host 'Executando controle positivo, LOCK canônico, oráculo independente e UNLOCK.'
  $primary=Invoke-ProductSlice $ops
  if($primary.cleanup -ceq 'UNVERIFIED'){
   $recovery='MANUAL_RECOVERY_REQUIRED'
   & $live.action OpenAccessibility
   Write-Host 'LAB RECOVERY: desative manualmente somente a Acessibilidade do KidRemote para restaurar uso. O resultado original não muda.'
  }
 }
}catch{
 $reason=[string]$_.Exception.Message;if($reason -cnotmatch '^INVALID:[A-Z0-9_]+$'){$reason='INVALID:HOST_OR_TRANSPORT_FAILURE'}
 if($null -eq $primary){$primary=[pscustomobject]@{status='INVALID';reason=$reason;cleanup='UNVERIFIED'}}
 if($directory){try{$j=Read-ProductJournal $directory;if(-not $j.verdict){$meta=[IO.File]::ReadAllText((Join-Path $directory 'provenance'))|ConvertFrom-Json;$null=Add-ProductJournal $directory $meta.attempt VERDICT INVALID;if(-not ($j.rows|Where-Object{$_.stage -ceq 'UNINSTALL_ADMITTED'})){$null=Add-ProductJournal $directory ([Guid]::NewGuid().ToString()) CLEANUP NOT_REQUIRED}}}catch{}}
}finally{
 if($live -and $live.state.reverseAttempted){$reverseCleanup='UNVERIFIED'}
 if($live -and $live.state.reverse){
  try{
   # Only remove a still-matching fixed tunnel created by this attempt.
   $run={param($e,$a,$inputText) Invoke-ReviewProcess $e $a $inputText}
   $apk=Join-Path $PSScriptRoot 'lab-reference.apk'
   Assert-LabReverse (Invoke-ReplacementAdb $Adb $serial ReverseRead $apk $run) $true
   $null=Invoke-ReplacementAdb $Adb $serial RemoveReverse $apk $run
   Assert-LabReverse (Invoke-ReplacementAdb $Adb $serial ReverseRead $apk $run) $false
   $reverseCleanup='OWN_REVERSE_REMOVED'
  }catch{$reverseCleanup='UNVERIFIED'}
 }
 if($backend){try{$backendCleanup=Stop-ProductBackend $backend}catch{$backendCleanup='UNVERIFIED'}}
 if($temporary){try{[IO.Directory]::Delete($temporary)}catch{$recovery='HOST_TEMP_REVIEW_REQUIRED'}}
 $jwt=$null;$serial=$null
}
$result=[ordered]@{scope='OD50_ONE_PRODUCT_SLICE_NOT_QUALIFICATION';source=$source;primary=$primary;backendCleanup=$backendCleanup;reverseCleanup=$reverseCleanup;labRecovery=$recovery;oldApkRestored=$false;newAppMayRemainInstalled=$true;historicalEvidenceUnchanged=$true}
# Result contains only typed verdict/state and task UUIDs, never credentials or raw device output.
$json=$result|ConvertTo-Json -Depth 8
if($directory){$p=Join-Path $directory 'result.txt';$f=[IO.File]::Open($p,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None);try{$b=[Text.Encoding]::UTF8.GetBytes($json);$f.Write($b,0,$b.Length);$f.Flush($true)}finally{$f.Dispose()}}
Write-Output $json
