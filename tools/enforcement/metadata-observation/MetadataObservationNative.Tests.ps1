Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root=Join-Path ([IO.Path]::GetTempPath()) ('kr-metadata-native-'+[Guid]::NewGuid());[void][IO.Directory]::CreateDirectory($root)
$oldLocal=$env:LOCALAPPDATA;$oldApk=$env:KR_METADATA_APK;$oldHash=$env:KR_METADATA_CHILD_HASH;$oldFixture=$env:KR_METADATA_FIXTURE_HASH;$oldSigner=$env:KR_METADATA_SIGNER;$oldMode=$env:KR_METADATA_MODE;$oldReparse=$env:KR_METADATA_REPARSE_TARGET;$n=0
function Check([bool]$v){$script:n++;if(-not $v){throw "CHECK_$script:n"}}
function Eq($a,$b){$script:n++;if($a -cne $b){throw "CHECK_$script:n expected=$b actual=$a"}}
try{
 $bundle=Join-Path $root 'bundle';[void][IO.Directory]::CreateDirectory($bundle)
 foreach($f in @('MetadataObservation.psm1','Read-CurrentMetadata.ps1')){Copy-Item -LiteralPath (Join-Path $PSScriptRoot $f) -Destination $bundle}
 Copy-Item -LiteralPath (Join-Path $PSScriptRoot '../update-review/ProductRuntimeCatalog.psm1') -Destination $bundle
 $runtime=Join-Path $bundle 'runtime';$javaDir=Join-Path $runtime 'jbr\bin';[void][IO.Directory]::CreateDirectory($javaDir)
 [IO.File]::WriteAllText((Join-Path $runtime 'apksigner.jar'),'synthetic jar')
 $compiler=Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe';$fixture=Join-Path $root 'fixture.exe'
 $null=& $compiler /nologo /target:exe "/out:$fixture" (Join-Path $PSScriptRoot 'MetadataObservationFixture.cs');if($LASTEXITCODE -ne 0){throw 'FIXTURE_BUILD'}
 Copy-Item -LiteralPath $fixture -Destination (Join-Path $javaDir 'java.exe')
 $apk=Join-Path $root 'lab.apk';[IO.File]::WriteAllText($apk,'synthetic approved lab APK bytes')
 $childHash=(Get-FileHash -LiteralPath $apk -Algorithm SHA256).Hash.ToLowerInvariant();$fixtureHash='b'*64;$signer='c'*64
 $files=@();foreach($f in Get-ChildItem -LiteralPath $bundle -File -Recurse){$name=$f.FullName.Substring($bundle.Length+1).Replace('\','/');$files+=@{name=$name;sha256=(Get-FileHash -LiteralPath $f.FullName -Algorithm SHA256).Hash.ToLowerInvariant()}}
 $manifest=[ordered]@{scope='OD51_READ_ONLY_METADATA_OBSERVATION';source=('a'*40);files=$files;labPort=47366;expectedConfiguration=@{manufacturer='samsung';model='SM-X400';android='16';api='36';build='BP4A.251205.006';securityPatch='2026-07-05'};child=@{sha256=$childHash;signerSha256=$signer;versionCode=2;versionName='0.0.2-local-physical-lab'};fixture=@{sha256=$fixtureHash}}
 $manifestPath=Join-Path $bundle 'bundle.json';[IO.File]::WriteAllText($manifestPath,($manifest|ConvertTo-Json -Depth 8));$manifestHash=(Get-FileHash -LiteralPath $manifestPath -Algorithm SHA256).Hash.ToLowerInvariant()
 $env:LOCALAPPDATA=Join-Path $root 'local';$env:KR_METADATA_APK=$apk;$env:KR_METADATA_CHILD_HASH=$childHash;$env:KR_METADATA_FIXTURE_HASH=$fixtureHash;$env:KR_METADATA_SIGNER=$signer
 $env:KR_METADATA_REPARSE_TARGET=Join-Path $root 'reparse-target'
 $historicalDir=Join-Path $env:LOCALAPPDATA 'KidRemote\metadata-observation-results';[void][IO.Directory]::CreateDirectory($historicalDir)
 $historicalShape=[ordered]@{attempt='78bf058e-280f-4ee1-9384-a51a75a395e5';source='bcac31838720a8aee77488ccf4b1ca9ad4b7929e';result=[ordered]@{scope='OD51_READ_ONLY_METADATA_OBSERVATION';deviceMutation=$false;backendMutation=$false;mutationJournalCreated=$false;configurationProvenance='PASS';packageProvenance='INVALID';fixtureProvenance='INVALID';reverseAbsent=$true;metadataStatus='UNSPECIFIED';metadataKnown='UNSPECIFIED';probeStatus='INVALID';failureReason='ADB_READ_FAILED';hostTemporaryApk='HOST_TEMP_DELETED'}}
 $historical=Join-Path $historicalDir '78bf058e-280f-4ee1-9384-a51a75a395e5.json';[IO.File]::WriteAllText($historical,($historicalShape|ConvertTo-Json -Depth 5))
 $historicalHash=(Get-FileHash -LiteralPath $historical -Algorithm SHA256).Hash
 $historicalParsed=[IO.File]::ReadAllText($historical)|ConvertFrom-Json;Eq $historicalParsed.result.failureReason 'ADB_READ_FAILED';Check ($historicalParsed.result.PSObject.Properties.Name -cnotcontains 'failureStage')
 $shell=Join-Path $PSHOME $(if($PSVersionTable.PSEdition -eq 'Core'){'pwsh.exe'}else{'powershell.exe'})
 foreach($case in @('empty','unexpected','runFail','reversePresent','pullStderr','pullNoStderr')){
  $env:KR_METADATA_MODE=$case
  $raw=& $shell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $bundle 'Read-CurrentMetadata.ps1') -Adb $fixture -ExpectedManifestHash $manifestHash
  $joined=$raw -join "`n";$output=$joined|ConvertFrom-Json;$r=$output.result
  Eq $r.scope 'OD51_READ_ONLY_METADATA_OBSERVATION';Eq $r.deviceMutation $false;Eq $r.backendMutation $false;Eq $r.mutationJournalCreated $false
  Eq $r.configurationProvenance 'PASS';Eq $r.packageProvenance 'PASS';Eq $r.fixtureProvenance 'PASS';Eq $r.reverseAbsent ($case -cne 'reversePresent');Eq $r.productPhysicalOracle 'BLOCKED';Eq $r.hostTemporaryApk 'HOST_TEMP_DELETED'
  Check (-not $joined.Contains('SYNTHETIC_PRIVATE_SERIAL'));Check (-not $joined.Contains('PRIVATE_RAW_FAILURE'));Check (-not $joined.Contains('PRIVATE_NORMAL_PULL_PROGRESS'))
  if($case -eq 'empty'){Eq $r.metadataStatus 'METADATA_ONLY';Eq $r.metadataKnown $true;Eq $r.otherDurableFiles 0;Check ($r.PSObject.Properties.Name -cnotcontains 'unexpectedStructuralEntries')}
  elseif($case -eq 'unexpected'){Eq $r.metadataStatus 'METADATA_ONLY';Eq $r.metadataFinding 'UNKNOWN_DURABLE_FILES_PRESENT';Eq $r.otherDurableFiles 1;Eq $r.unexpectedStructuralEntries[0].relativeName 'bounded-extra.dat'}
  elseif($case -eq 'runFail'){Eq $r.metadataStatus 'RUN_AS_FAILED';Eq $r.metadataKnown $false;Eq $r.probeStatus 'TYPED_METADATA_FAILURE';Eq $r.failureStage 'METADATA_RUN_AS';Eq $r.failureReason 'ADB_EXIT_NONZERO';Check ($r.PSObject.Properties.Name -cnotcontains 'unexpectedStructuralEntries')}
  elseif($case -eq 'reversePresent'){Eq $r.metadataStatus 'UNSPECIFIED';Eq $r.metadataKnown 'UNSPECIFIED';Eq $r.probeStatus 'PROVENANCE_OR_REVERSE_INVALID';Eq $r.failureStage 'REVERSE_READ';Eq $r.failureReason 'REVERSE_PRESENT';Check (-not $joined.Contains('METADATA_SHOULD_NOT_RUN'))}
  else{Eq $r.metadataStatus 'METADATA_ONLY';Eq $r.probeStatus 'OBSERVED';Eq $r.failureStage 'NONE';Eq $r.failureReason 'NONE'}
 }

 foreach($failureCase in @(
  @('pullExitNonzero','CHILD_APK_PULL','ADB_EXIT_NONZERO','PRIVATE_PULL_EXIT_FAILURE'),
  @('pullOversized','CHILD_APK_PULL','ADB_OUTPUT_TOO_LARGE',''),
  @('pullMissing','CHILD_APK_LOCAL_VERIFY','PACKAGE_PROVENANCE_INVALID',''),
  @('pullReparse','CHILD_APK_LOCAL_VERIFY','PACKAGE_PROVENANCE_INVALID',''),
  @('pullTooLarge','CHILD_APK_LOCAL_VERIFY','PACKAGE_PROVENANCE_INVALID',''),
  @('pullHashMismatch','CHILD_APK_LOCAL_VERIFY','PACKAGE_PROVENANCE_INVALID',''),
  @('signerMismatch','CHILD_APK_SIGNER_VERIFY','PACKAGE_SIGNER_INVALID',''),
  @('readStderr','CONFIGURATION_READ','ADB_STDERR_PRESENT','PRIVATE_ORDINARY_READ_STDERR')
 )){
  $env:KR_METADATA_MODE=$failureCase[0]
  $raw=& $shell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $bundle 'Read-CurrentMetadata.ps1') -Adb $fixture -ExpectedManifestHash $manifestHash
  $joined=$raw -join "`n";$output=$joined|ConvertFrom-Json;$r=$output.result
  Eq $r.probeStatus 'INVALID';Eq $r.failureStage $failureCase[1];Eq $r.failureReason $failureCase[2]
  Check ($r.failureReason -cne 'ADB_READ_FAILED');Check (-not $joined.Contains('PRIVATE_'));Check (-not $joined.Contains('xxxxxxxxxxxxxxxx'))
  if($failureCase[0] -cne 'readStderr'){Eq $r.hostTemporaryApk 'HOST_TEMP_DELETED';Check ($r.PSObject.Properties.Name -contains 'child');Check ($r.PSObject.Properties.Name -contains 'fixture')}
 }
 foreach($evidence in Get-ChildItem -LiteralPath $historicalDir -File){Check (-not ([IO.File]::ReadAllText($evidence.FullName).Contains('PRIVATE_')))}
 Eq (Get-FileHash -LiteralPath $historical -Algorithm SHA256).Hash $historicalHash
 $env:KR_METADATA_MODE='empty';$bad=& $shell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $bundle 'Read-CurrentMetadata.ps1') -Adb $fixture -ExpectedManifestHash ('d'*64);Check (($bad -join "`n") -notmatch 'SYNTHETIC_PRIVATE_SERIAL|PRIVATE_RAW_FAILURE')
 Write-Output "OD51_METADATA_NATIVE_CHECKS=$n;ADB=FAKE;DEVICE=NOT_INVOKED;SHELL=$($PSVersionTable.PSEdition)"
}finally{
 $env:LOCALAPPDATA=$oldLocal;$env:KR_METADATA_APK=$oldApk;$env:KR_METADATA_CHILD_HASH=$oldHash;$env:KR_METADATA_FIXTURE_HASH=$oldFixture;$env:KR_METADATA_SIGNER=$oldSigner;$env:KR_METADATA_MODE=$oldMode;$env:KR_METADATA_REPARSE_TARGET=$oldReparse
 if(Test-Path -LiteralPath $root){Remove-Item -LiteralPath $root -Recurse -Force}
}
exit 0
