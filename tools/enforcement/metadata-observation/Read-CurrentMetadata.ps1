param(
 [string]$Adb='C:\platform-tools\adb.exe',
 [Parameter(Mandatory=$true)][string]$ExpectedManifestHash,
 [switch]$RetrySummary
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$attempt=[Guid]::NewGuid().ToString();$source='UNSPECIFIED';$serial=$null;$temporary=$null;$cleanup='NOT_CREATED';$failure='NONE';$stage='BUNDLE_VERIFY';$exitCode=0
$scope=if($RetrySummary){'OD51_BOUNDED_RETRY_DIAGNOSTIC'}else{'OD51_READ_ONLY_METADATA_OBSERVATION'}
$result=[ordered]@{
 scope=$scope;deviceMutation=$false;backendMutation=$false;mutationJournalCreated=$false
 configurationProvenance='INVALID';packageProvenance='INVALID';fixtureProvenance='INVALID';reverseAbsent=$false
 metadataStatus='UNSPECIFIED';metadataKnown='UNSPECIFIED';knownPresent=@();totalDurableFiles='UNSPECIFIED';knownDurableFiles='UNSPECIFIED';otherDurableFiles='UNSPECIFIED'
 productPhysicalOracle='BLOCKED';physicalExecution='OWNER_READ_ONLY_OBSERVATION';probeStatus='INVALID';failureStage='NONE';failureReason='NONE'
}
if($RetrySummary){
 foreach($key in @('metadataStatus','metadataKnown','knownPresent','totalDurableFiles','knownDurableFiles','otherDurableFiles')){$result.Remove($key)}
 $result.physicalExecution='OWNER_READ_ONLY_RETRY_DIAGNOSTIC';$result.privateReadScope='SYNC_RETRY_ONLY'
 $result.privateContentRetained=$false;$result.retryReadAttempted=$false;$result.retry=$null
}
try{
 $manifestPath=Join-Path $PSScriptRoot 'bundle.json'
 if($ExpectedManifestHash -cnotmatch '^[a-f0-9]{64}$' -or -not (Test-Path -LiteralPath $manifestPath) -or (Get-FileHash -LiteralPath $manifestPath -Algorithm SHA256).Hash.ToLowerInvariant() -cne $ExpectedManifestHash){throw 'BUNDLE_HASH_INVALID'}
 $manifest=[IO.File]::ReadAllText($manifestPath)|ConvertFrom-Json
 if($manifest.scope -cne $scope -or $manifest.source -cnotmatch '^[a-f0-9]{40}$' -or $manifest.files.Count -lt 5){throw 'BUNDLE_SCHEMA_INVALID'}
 $source=$manifest.source
 if($RetrySummary -and ($manifest.readiness -cne 'READY_FOR_ONE_OWNER_RUN' -or $manifest.privateRead.path -cne 'no_backup/sync-retry' -or $manifest.privateRead.maximumBytes -ne 1024 -or $manifest.privateRead.rawRetained -ne $false)){throw 'BUNDLE_SCHEMA_INVALID'}
 $expectedNames=@('MetadataObservation.psm1','ProductRuntimeCatalog.psm1','Read-CurrentMetadata.ps1','runtime/apksigner.jar','runtime/jbr/bin/java.exe')
 if($RetrySummary){$expectedNames+=@('SyncRetryDiagnostic.psm1','SyncRetryDiagnostic.cs','Read-SyncRetry.sh')}
 foreach($name in $expectedNames){if(@($manifest.files|Where-Object{$_.name -ceq $name}).Count -ne 1){throw 'BUNDLE_SCHEMA_INVALID'}}
 $actual=@(Get-ChildItem -LiteralPath $PSScriptRoot -File -Recurse|Where-Object{$_.FullName -cne $manifestPath})
 if($actual.Count -ne $manifest.files.Count){throw 'BUNDLE_SCHEMA_INVALID'}
 foreach($file in $manifest.files){
  if($file.name -cnotmatch '^[A-Za-z0-9_./-]{1,240}$' -or $file.name -match '(^|/)\.\.?(/|$)' -or $file.sha256 -cnotmatch '^[a-f0-9]{64}$'){throw 'BUNDLE_SCHEMA_INVALID'}
  $path=Join-Path $PSScriptRoot ($file.name.Replace('/',[IO.Path]::DirectorySeparatorChar));if(-not (Test-Path -LiteralPath $path -PathType Leaf) -or ((Get-Item -LiteralPath $path).Attributes -band [IO.FileAttributes]::ReparsePoint) -or (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant() -cne $file.sha256){throw 'BUNDLE_FILE_INVALID'}
 }
 Import-Module (Join-Path $PSScriptRoot 'ProductRuntimeCatalog.psm1') -Force
 Import-Module (Join-Path $PSScriptRoot 'MetadataObservation.psm1') -Force
 $paths=Get-ReviewStatePaths $true;$metadataScript=Get-Od51MetadataScript $paths
 if($RetrySummary){Import-Module (Join-Path $PSScriptRoot 'SyncRetryDiagnostic.psm1') -Force;$metadataScript=Get-Od51RetryScript}
 $stage='DEVICE_SELECTION'
 $devices=Invoke-Od51Adb $Adb '' @('devices') '' $metadataScript
 $serial=Select-Od51Target (Get-Od51AdbText $devices)
 $invoke={param($argsToRead,[string]$stdinText='',[string]$pull='') Invoke-Od51Adb $Adb $serial $argsToRead $stdinText $metadataScript $pull}.GetNewClosure()
 $read={param($argsToRead)
  $r=& $invoke $argsToRead '' ''
  return Get-Od51AdbText $r (($argsToRead -join ' ') -match '^shell pm path ')
 }.GetNewClosure()
 $stage='CONFIGURATION_READ'
 $configuration=Get-Od51Configuration $read
 $result.configuration=[ordered]@{manufacturer=$configuration.manufacturer;model=$configuration.model;android=$configuration.android;api=$configuration.api;build=$configuration.build;securityPatch=$configuration.securityPatch}
 $expected=$manifest.expectedConfiguration
 if($configuration.manufacturer -ceq $expected.manufacturer -and $configuration.model -ceq $expected.model -and $configuration.android -ceq $expected.android -and $configuration.api -ceq $expected.api -and $configuration.build -ceq $expected.build -and $configuration.securityPatch -ceq $expected.securityPatch){$result.configurationProvenance='PASS'}
 $stage='CHILD_PACKAGE_READ'
 $child=Get-Od51Package 'dev.kidremote.child.unassigned.debug' $read
 $result.child=[ordered]@{installed=[bool]$child.installed;sha256=$child.sha256;signerSha256='UNSPECIFIED';versionCode=$child.versionCode;versionName=$child.versionName}
 $stage='FIXTURE_PACKAGE_READ'
 $fixture=Get-Od51Package 'dev.kidremote.spike.ordinary' $read
 $result.fixture=[ordered]@{installed=[bool]$fixture.installed;sha256=$fixture.sha256;versionCode=$fixture.versionCode;versionName=$fixture.versionName}
 if($fixture.installed -and $fixture.sha256 -ceq $manifest.fixture.sha256){$result.fixtureProvenance='PASS'}
 $stage='REVERSE_READ'
 $reverseCommand=@('reverse','--list');$reverse=(& $invoke $reverseCommand '' '')
 $reverseRaw=Get-Od51AdbText $reverse
 $result.reverseAbsent=Test-Od51ReverseAbsent $reverseRaw ([int]$manifest.labPort)
 $signer='UNSPECIFIED'
 if($child.installed){
  $tempRoot=Join-Path $env:LOCALAPPDATA 'KidRemote\metadata-observation-temp';[void][IO.Directory]::CreateDirectory($tempRoot)
  $temporary=Join-Path $tempRoot $attempt;[void][IO.Directory]::CreateDirectory($temporary);$cleanup='UNVERIFIED'
  $apk=Join-Path $temporary 'installed-base.apk';$pullCommand=@('pull',$child.basePath,$apk)
  $stage='CHILD_APK_PULL';$pull=& $invoke $pullCommand '' $apk
  Assert-Od51PullResult $pull $pullCommand[2] $apk
  $stage='CHILD_APK_LOCAL_VERIFY';Assert-Od51LocalApk $apk $apk $child.sha256
  $stage='CHILD_APK_SIGNER_VERIFY'
  $signer=Get-Od51Signer (Join-Path $PSScriptRoot 'runtime\jbr\bin\java.exe') (Join-Path $PSScriptRoot 'runtime\apksigner.jar') $apk
  if($signer -cne $manifest.child.signerSha256){throw 'PACKAGE_SIGNER_INVALID'}
  $result.child.signerSha256=$signer
 }
 if($child.installed -and $child.sha256 -ceq $manifest.child.sha256 -and $signer -ceq $manifest.child.signerSha256 -and $child.versionCode -ceq ([string]$manifest.child.versionCode) -and $child.versionName -ceq $manifest.child.versionName){$result.packageProvenance='PASS'}
 if($result.configurationProvenance -ceq 'PASS' -and $result.packageProvenance -ceq 'PASS' -and $result.fixtureProvenance -ceq 'PASS' -and $result.reverseAbsent){
  if($RetrySummary){
   $stage='RETRY_RUN_AS';$result.retryReadAttempted=$true
   $retryCommand=@('shell','-T','run-as','dev.kidremote.child.unassigned.debug','sh')
   try{
    $raw=& $invoke $retryCommand $metadataScript ''
    $stage='RETRY_PARSE';$result.retry=Convert-Od51RetryProcessResult $raw
   }finally{$raw=$null}
   if($result.retry.status -ceq 'OBSERVED'){$result.probeStatus='OBSERVED'}else{
    $exitCode=1;$result.probeStatus='TYPED_RETRY_FAILURE';$result.failureStage=$stage;$result.failureReason=$result.retry.failureCode
   }
  }else{
  $stage='METADATA_RUN_AS'
  $metadataCommand=@('shell','-T','run-as','dev.kidremote.child.unassigned.debug','sh');$raw=& $invoke $metadataCommand $metadataScript ''
  $stage='METADATA_PARSE'
  $metadata=Convert-Od51MetadataProcessResult $raw $paths
  $result.metadataStatus=$metadata.metadataStatus;$result.metadataKnown=$metadata.metadataKnown
  if($metadata.metadataStatus -ceq 'METADATA_ONLY'){
   $result.metadataFinding=$metadata.metadataFinding;$result.knownPresent=@($metadata.knownPresent);$result.totalDurableFiles=$metadata.totalDurableFiles;$result.knownDurableFiles=$metadata.knownDurableFiles;$result.otherDurableFiles=$metadata.otherDurableFiles
   if($metadata.otherDurableFiles -gt 0){$result.unexpectedStructuralEntries=@($metadata.unexpectedStructuralEntries)}
  }
  if($metadata.metadataStatus -ceq 'METADATA_ONLY'){$result.probeStatus='OBSERVED';$result.failureStage='NONE';$result.failureReason='NONE'}else{
   $result.probeStatus='TYPED_METADATA_FAILURE'
   if($metadata.metadataStatus -ceq 'RUN_AS_FAILED'){$result.failureStage='METADATA_RUN_AS';$result.failureReason='ADB_EXIT_NONZERO'}
   elseif($raw.outputTooLarge){$result.failureStage='METADATA_PARSE';$result.failureReason='ADB_OUTPUT_TOO_LARGE'}
   elseif($raw.exitCode -eq 0 -and $raw.stderrPresent){$result.failureStage='METADATA_PARSE';$result.failureReason='ADB_STDERR_PRESENT'}
   else{$result.failureStage='METADATA_PARSE';$result.failureReason=$metadata.metadataStatus}
  }
  }
 }else{
  $result.probeStatus='PROVENANCE_OR_REVERSE_INVALID'
  if($result.configurationProvenance -cne 'PASS'){$result.failureStage='CONFIGURATION_READ';$result.failureReason='CONFIGURATION_PROVENANCE_INVALID'}
  elseif($result.packageProvenance -cne 'PASS'){$result.failureStage='CHILD_PACKAGE_READ';$result.failureReason='PACKAGE_PROVENANCE_INVALID'}
  elseif($result.fixtureProvenance -cne 'PASS'){$result.failureStage='FIXTURE_PACKAGE_READ';$result.failureReason='PACKAGE_PROVENANCE_INVALID'}
  else{$result.failureStage='REVERSE_READ';$result.failureReason='REVERSE_PRESENT'}
 }
}catch{
 $exitCode=1;$allowed=@('BUNDLE_HASH_INVALID','BUNDLE_SCHEMA_INVALID','BUNDLE_FILE_INVALID','ONE_AUTHORIZED_NON_EMULATOR_TARGET_REQUIRED','CONFIGURATION_INVALID','PACKAGE_SCOPE_INVALID','PACKAGE_METADATA_INVALID','PACKAGE_PROVENANCE_INVALID','PACKAGE_SIGNER_INVALID','REVERSE_OUTPUT_INVALID','READ_ONLY_COMMAND_REJECTED','TARGET_SELECTION_INVALID','ADB_TIMEOUT','ADB_PROCESS_FAILED','ADB_EXIT_NONZERO','ADB_STDERR_PRESENT','ADB_OUTPUT_TOO_LARGE')
 $failure=if($_.Exception.Message -cin $allowed){$_.Exception.Message}else{'PROBE_INTERNAL_INVALID'}
 $result.probeStatus='INVALID';$result.failureStage=$stage;$result.failureReason=$failure
}finally{
 $serial=$null;$raw=$null
 if($temporary){
  try{if(Test-Path -LiteralPath $temporary){Remove-Item -LiteralPath $temporary -Recurse -Force};if(Test-Path -LiteralPath $temporary){throw 'remaining'};$cleanup='HOST_TEMP_DELETED'}catch{$cleanup='HOST_TEMP_CLEANUP_FAILED';$exitCode=1;$result.probeStatus='INVALID';$result.failureStage='HOST_TEMP_CLEANUP';$result.failureReason='HOST_TEMP_CLEANUP_FAILED'}
 }
}
$result.hostTemporaryApk=$cleanup
$output=[ordered]@{attempt=$attempt;utc=[DateTime]::UtcNow.ToString('o');source=$source;bundleSha256=$(if($ExpectedManifestHash -cmatch '^[a-f0-9]{64}$'){$ExpectedManifestHash}else{'UNSPECIFIED'});result=$result}
$json=$output|ConvertTo-Json -Depth 9
try{
 $resultFolder=if($RetrySummary){'KidRemote\retry-diagnostic-results'}else{'KidRemote\metadata-observation-results'}
 $dir=Join-Path $env:LOCALAPPDATA $resultFolder;[void][IO.Directory]::CreateDirectory($dir);$path=Join-Path $dir ($attempt+'.json')
 $f=[IO.File]::Open($path,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
 try{$bytes=(New-Object Text.UTF8Encoding($false)).GetBytes($json);$f.Write($bytes,0,$bytes.Length);$f.Flush($true)}finally{$f.Dispose()}
 Write-Output $json
}catch{Write-Output (@{result=@{scope=$scope;deviceMutation=$false;backendMutation=$false;probeStatus='INVALID';failureStage='HOST_EVIDENCE_WRITE';failureReason='HOST_EVIDENCE_WRITE_FAILED';productPhysicalOracle='BLOCKED'}}|ConvertTo-Json -Compress);exit 1}
exit $exitCode
