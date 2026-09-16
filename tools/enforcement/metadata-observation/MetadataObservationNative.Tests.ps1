Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root=Join-Path ([IO.Path]::GetTempPath()) ('kr-metadata-native-'+[Guid]::NewGuid());[void][IO.Directory]::CreateDirectory($root)
$oldLocal=$env:LOCALAPPDATA;$oldApk=$env:KR_METADATA_APK;$oldHash=$env:KR_METADATA_CHILD_HASH;$oldFixture=$env:KR_METADATA_FIXTURE_HASH;$oldSigner=$env:KR_METADATA_SIGNER;$oldMode=$env:KR_METADATA_MODE;$n=0
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
 $shell=Join-Path $PSHOME $(if($PSVersionTable.PSEdition -eq 'Core'){'pwsh.exe'}else{'powershell.exe'})
 foreach($case in @('empty','unexpected','runFail','reversePresent')){
  $env:KR_METADATA_MODE=$case
  $raw=& $shell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $bundle 'Read-CurrentMetadata.ps1') -Adb $fixture -ExpectedManifestHash $manifestHash
  $joined=$raw -join "`n";$output=$joined|ConvertFrom-Json;$r=$output.result
  Eq $r.scope 'OD51_READ_ONLY_METADATA_OBSERVATION';Eq $r.deviceMutation $false;Eq $r.backendMutation $false;Eq $r.mutationJournalCreated $false
  Eq $r.configurationProvenance 'PASS';Eq $r.packageProvenance 'PASS';Eq $r.fixtureProvenance 'PASS';Eq $r.reverseAbsent ($case -cne 'reversePresent');Eq $r.productPhysicalOracle 'BLOCKED';Eq $r.hostTemporaryApk 'HOST_TEMP_DELETED'
  Check (-not $joined.Contains('SYNTHETIC_PRIVATE_SERIAL'));Check (-not $joined.Contains('PRIVATE_RAW_FAILURE'))
  if($case -eq 'empty'){Eq $r.metadataStatus 'METADATA_ONLY';Eq $r.metadataKnown $true;Eq $r.otherDurableFiles 0;Check ($r.PSObject.Properties.Name -cnotcontains 'unexpectedStructuralEntries')}
  elseif($case -eq 'unexpected'){Eq $r.metadataStatus 'METADATA_ONLY';Eq $r.metadataFinding 'UNKNOWN_DURABLE_FILES_PRESENT';Eq $r.otherDurableFiles 1;Eq $r.unexpectedStructuralEntries[0].relativeName 'bounded-extra.dat'}
  elseif($case -eq 'runFail'){Eq $r.metadataStatus 'RUN_AS_FAILED';Eq $r.metadataKnown $false;Eq $r.probeStatus 'TYPED_METADATA_FAILURE';Check ($r.PSObject.Properties.Name -cnotcontains 'unexpectedStructuralEntries')}
  else{Eq $r.metadataStatus 'UNSPECIFIED';Eq $r.metadataKnown 'UNSPECIFIED';Eq $r.probeStatus 'PROVENANCE_OR_REVERSE_INVALID';Check (-not $joined.Contains('METADATA_SHOULD_NOT_RUN'))}
 }
 $env:KR_METADATA_MODE='empty';$bad=& $shell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $bundle 'Read-CurrentMetadata.ps1') -Adb $fixture -ExpectedManifestHash ('d'*64);Check (($bad -join "`n") -notmatch 'SYNTHETIC_PRIVATE_SERIAL|PRIVATE_RAW_FAILURE')
 Write-Output "OD51_METADATA_NATIVE_CHECKS=$n;ADB=FAKE;DEVICE=NOT_INVOKED;SHELL=$($PSVersionTable.PSEdition)"
}finally{
 $env:LOCALAPPDATA=$oldLocal;$env:KR_METADATA_APK=$oldApk;$env:KR_METADATA_CHILD_HASH=$oldHash;$env:KR_METADATA_FIXTURE_HASH=$oldFixture;$env:KR_METADATA_SIGNER=$oldSigner;$env:KR_METADATA_MODE=$oldMode
 if(Test-Path -LiteralPath $root){Remove-Item -LiteralPath $root -Recurse -Force}
}
