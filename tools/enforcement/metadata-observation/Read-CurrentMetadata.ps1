param(
 [string]$Adb='C:\platform-tools\adb.exe',
 [Parameter(Mandatory=$true)][string]$ExpectedManifestHash
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$attempt=[Guid]::NewGuid().ToString();$source='UNSPECIFIED';$serial=$null;$temporary=$null;$cleanup='NOT_CREATED';$failure='NONE';$exitCode=0
$result=[ordered]@{
 scope='OD51_READ_ONLY_METADATA_OBSERVATION';deviceMutation=$false;backendMutation=$false;mutationJournalCreated=$false
 configurationProvenance='INVALID';packageProvenance='INVALID';fixtureProvenance='INVALID';reverseAbsent=$false
 metadataStatus='UNSPECIFIED';metadataKnown='UNSPECIFIED';knownPresent=@();totalDurableFiles='UNSPECIFIED';knownDurableFiles='UNSPECIFIED';otherDurableFiles='UNSPECIFIED'
 productPhysicalOracle='BLOCKED';physicalExecution='OWNER_READ_ONLY_OBSERVATION';probeStatus='INVALID'
}
try{
 $manifestPath=Join-Path $PSScriptRoot 'bundle.json'
 if($ExpectedManifestHash -cnotmatch '^[a-f0-9]{64}$' -or -not (Test-Path -LiteralPath $manifestPath) -or (Get-FileHash -LiteralPath $manifestPath -Algorithm SHA256).Hash.ToLowerInvariant() -cne $ExpectedManifestHash){throw 'BUNDLE_HASH_INVALID'}
 $manifest=[IO.File]::ReadAllText($manifestPath)|ConvertFrom-Json
 if($manifest.scope -cne 'OD51_READ_ONLY_METADATA_OBSERVATION' -or $manifest.source -cnotmatch '^[a-f0-9]{40}$' -or $manifest.files.Count -lt 5){throw 'BUNDLE_SCHEMA_INVALID'}
 $source=$manifest.source
 $expectedNames=@('MetadataObservation.psm1','ProductRuntimeCatalog.psm1','Read-CurrentMetadata.ps1','runtime/apksigner.jar','runtime/jbr/bin/java.exe')
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
 $devices=Invoke-Od51Adb $Adb '' @('devices') '' $metadataScript
 $serial=Select-Od51Target (Get-Od51AdbText $devices)
 $invoke={param($argsToRead,[string]$stdinText='',[string]$pull='') Invoke-Od51Adb $Adb $serial $argsToRead $stdinText $metadataScript $pull}.GetNewClosure()
 $read={param($argsToRead)
  $r=& $invoke $argsToRead '' ''
  return Get-Od51AdbText $r (($argsToRead -join ' ') -match '^shell pm path ')
 }.GetNewClosure()
 $configuration=Get-Od51Configuration $read
 $result.configuration=[ordered]@{manufacturer=$configuration.manufacturer;model=$configuration.model;android=$configuration.android;api=$configuration.api;build=$configuration.build;securityPatch=$configuration.securityPatch}
 $expected=$manifest.expectedConfiguration
 if($configuration.manufacturer -ceq $expected.manufacturer -and $configuration.model -ceq $expected.model -and $configuration.android -ceq $expected.android -and $configuration.api -ceq $expected.api -and $configuration.build -ceq $expected.build -and $configuration.securityPatch -ceq $expected.securityPatch){$result.configurationProvenance='PASS'}
 $child=Get-Od51Package 'dev.kidremote.child.unassigned.debug' $read
 $fixture=Get-Od51Package 'dev.kidremote.spike.ordinary' $read
 $reverseCommand=@('reverse','--list');$reverse=(& $invoke $reverseCommand '' '')
 $reverseRaw=Get-Od51AdbText $reverse
 $result.reverseAbsent=Test-Od51ReverseAbsent $reverseRaw ([int]$manifest.labPort)
 $signer='UNSPECIFIED'
 if($child.installed){
  $tempRoot=Join-Path $env:LOCALAPPDATA 'KidRemote\metadata-observation-temp';[void][IO.Directory]::CreateDirectory($tempRoot)
  $temporary=Join-Path $tempRoot $attempt;[void][IO.Directory]::CreateDirectory($temporary);$cleanup='UNVERIFIED'
  $apk=Join-Path $temporary 'installed-base.apk';$pullCommand=@('pull',$child.basePath,$apk);$pull=& $invoke $pullCommand '' $apk
  $null=Get-Od51AdbText $pull
  if(-not (Test-Path -LiteralPath $apk -PathType Leaf) -or (Get-Item -LiteralPath $apk).Length -gt 200MB -or (Get-FileHash -LiteralPath $apk -Algorithm SHA256).Hash.ToLowerInvariant() -cne $child.sha256){throw 'PACKAGE_PROVENANCE_INVALID'}
  $signer=Get-Od51Signer (Join-Path $PSScriptRoot 'runtime\jbr\bin\java.exe') (Join-Path $PSScriptRoot 'runtime\apksigner.jar') $apk
 }
 $result.child=[ordered]@{installed=[bool]$child.installed;sha256=$child.sha256;signerSha256=$signer;versionCode=$child.versionCode;versionName=$child.versionName}
 $result.fixture=[ordered]@{installed=[bool]$fixture.installed;sha256=$fixture.sha256;versionCode=$fixture.versionCode;versionName=$fixture.versionName}
 if($child.installed -and $child.sha256 -ceq $manifest.child.sha256 -and $signer -ceq $manifest.child.signerSha256 -and $child.versionCode -ceq ([string]$manifest.child.versionCode) -and $child.versionName -ceq $manifest.child.versionName){$result.packageProvenance='PASS'}
 if($fixture.installed -and $fixture.sha256 -ceq $manifest.fixture.sha256){$result.fixtureProvenance='PASS'}
 if($result.configurationProvenance -ceq 'PASS' -and $result.packageProvenance -ceq 'PASS' -and $result.fixtureProvenance -ceq 'PASS' -and $result.reverseAbsent){
  $metadataCommand=@('shell','-T','run-as','dev.kidremote.child.unassigned.debug','sh');$raw=& $invoke $metadataCommand $metadataScript ''
  $metadata=Convert-Od51MetadataProcessResult $raw $paths
  $result.metadataStatus=$metadata.metadataStatus;$result.metadataKnown=$metadata.metadataKnown
  if($metadata.metadataStatus -ceq 'METADATA_ONLY'){
   $result.metadataFinding=$metadata.metadataFinding;$result.knownPresent=@($metadata.knownPresent);$result.totalDurableFiles=$metadata.totalDurableFiles;$result.knownDurableFiles=$metadata.knownDurableFiles;$result.otherDurableFiles=$metadata.otherDurableFiles
   if($metadata.otherDurableFiles -gt 0){$result.unexpectedStructuralEntries=@($metadata.unexpectedStructuralEntries)}
  }
  $result.probeStatus=$(if($metadata.metadataStatus -ceq 'METADATA_ONLY'){'OBSERVED'}else{'TYPED_METADATA_FAILURE'})
 }else{$result.probeStatus='PROVENANCE_OR_REVERSE_INVALID'}
}catch{
 $exitCode=1;$allowed=@('BUNDLE_HASH_INVALID','BUNDLE_SCHEMA_INVALID','BUNDLE_FILE_INVALID','ONE_AUTHORIZED_NON_EMULATOR_TARGET_REQUIRED','CONFIGURATION_INVALID','PACKAGE_SCOPE_INVALID','PACKAGE_METADATA_INVALID','PACKAGE_PROVENANCE_INVALID','PACKAGE_SIGNER_INVALID','REVERSE_OUTPUT_INVALID','READ_ONLY_COMMAND_REJECTED','TARGET_SELECTION_INVALID','ADB_TIMEOUT','ADB_PROCESS_FAILED','ADB_READ_FAILED')
 $failure=if($_.Exception.Message -cin $allowed){$_.Exception.Message}else{'PROBE_INTERNAL_INVALID'}
 $result.probeStatus='INVALID';$result.failureReason=$failure
}finally{
 $serial=$null
 if($temporary){
  try{if(Test-Path -LiteralPath $temporary){Remove-Item -LiteralPath $temporary -Recurse -Force};if(Test-Path -LiteralPath $temporary){throw 'remaining'};$cleanup='HOST_TEMP_DELETED'}catch{$cleanup='HOST_TEMP_CLEANUP_FAILED';$exitCode=1;$result.probeStatus='INVALID';$result.failureReason='HOST_TEMP_CLEANUP_FAILED'}
 }
}
$result.hostTemporaryApk=$cleanup
$output=[ordered]@{attempt=$attempt;utc=[DateTime]::UtcNow.ToString('o');source=$source;bundleSha256=$(if($ExpectedManifestHash -cmatch '^[a-f0-9]{64}$'){$ExpectedManifestHash}else{'UNSPECIFIED'});result=$result}
$json=$output|ConvertTo-Json -Depth 9
try{
 $dir=Join-Path $env:LOCALAPPDATA 'KidRemote\metadata-observation-results';[void][IO.Directory]::CreateDirectory($dir);$path=Join-Path $dir ($attempt+'.json')
 $f=[IO.File]::Open($path,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
 try{$bytes=(New-Object Text.UTF8Encoding($false)).GetBytes($json);$f.Write($bytes,0,$bytes.Length);$f.Flush($true)}finally{$f.Dispose()}
 Write-Output $json
}catch{Write-Output '{"result":{"scope":"OD51_READ_ONLY_METADATA_OBSERVATION","deviceMutation":false,"backendMutation":false,"probeStatus":"INVALID","failureReason":"HOST_EVIDENCE_WRITE_FAILED","productPhysicalOracle":"BLOCKED"}}';exit 1}
exit $exitCode
