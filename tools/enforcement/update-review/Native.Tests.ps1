param([Parameter(Mandatory=$true)][string]$OldApk,[Parameter(Mandatory=$true)][string]$LabApk)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root=Join-Path ([IO.Path]::GetTempPath()) ('kr-review-entry-'+[Guid]::NewGuid());[void][IO.Directory]::CreateDirectory($root)
$oldMode=$env:KR_REVIEW_TEST_MODE;$oldFixture=$env:KR_REVIEW_OLD_APK;$n=0
try{
 if((Get-FileHash $OldApk).Hash.ToLowerInvariant() -cne '3ff9962ec6bf55eab20eda993e879112be9c04a3ed7c00e8287fc7660ad63ac9'){throw 'OLD_FIXTURE_HASH'}
 foreach($f in @('Review.psm1','ReadOnly-UpdateReview.ps1')){Copy-Item (Join-Path $PSScriptRoot $f) $root}
 Copy-Item (Join-Path $PSScriptRoot '../product-oracle/ReadOnly.psm1') $root
 Copy-Item $LabApk (Join-Path $root 'lab-reference.apk')
 $java='C:\Program Files\Android\Android Studio\jbr\bin\java.exe';$jar=Join-Path $env:LOCALAPPDATA 'Android\Sdk\build-tools\37.0.0\lib\apksigner.jar'
 $m=@{scope='READ_ONLY_SIGNER_STATE_UPDATE_REVIEW';source=('a'*40);files=@();javaSha256=(Get-FileHash $java).Hash.ToLowerInvariant();apksignerSha256=(Get-FileHash $jar).Hash.ToLowerInvariant();lab=@{sha256='f6d2a240fae179343d9eb19dfde7684ae6e241b35cebea8ce491205110f7ad56';signerSha256='638dfa66379788415c313d7a3ca96dcfcaf7e643c12bb0c4950b3046a3f76beb';versionCode=2;package='dev.kidremote.child.unassigned.debug'}}
 foreach($f in @('Review.psm1','ReadOnly.psm1','ReadOnly-UpdateReview.ps1','lab-reference.apk')){$m.files+=@{name=$f;sha256=(Get-FileHash (Join-Path $root $f)).Hash.ToLowerInvariant()}}
 $manifest=Join-Path $root 'bundle.json';[IO.File]::WriteAllText($manifest,($m|ConvertTo-Json -Depth 6));$hash=(Get-FileHash $manifest).Hash.ToLowerInvariant()
 $exe=Join-Path $root 'fixture.exe';$compiler=Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
 $null=& $compiler /nologo /target:exe "/out:$exe" (Join-Path $PSScriptRoot 'NativeFixture.cs');if($LASTEXITCODE -ne 0){throw 'FAKE_BUILD'}
 $env:KR_REVIEW_OLD_APK=$OldApk
 Import-Module (Join-Path $PSScriptRoot 'Review.psm1') -Force
 $env:KR_REVIEW_TEST_MODE='present'
 $probe=Invoke-ReviewProcess $exe @('-s','SYNTHETIC_PRIVATE_SERIAL','shell','-T','run-as','dev.kidremote.child.unassigned.debug','sh') (Get-ReviewStateScript)
 $null=Convert-ReviewState $probe.stdout;$n++
 foreach($mode in @('empty','present','denied','badHash')){
  $env:KR_REVIEW_TEST_MODE=$mode
  $raw=& (Join-Path $PSHOME 'powershell.exe') -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root 'ReadOnly-UpdateReview.ps1') -Adb $exe -ExpectedManifestHash $hash -WorkRoot (Join-Path $root 'results')
  $r=($raw -join "`n")|ConvertFrom-Json
  $expected=if($mode -eq 'badHash'){'READ_ONLY_REVIEW_INVALID'}else{'SIGNER_MISMATCH_BLOCKED'}
  $n++;if($r.classification -cne $expected){throw ('NATIVE_CLASSIFICATION_'+$mode+'_'+$r.classification)}
  $n++;if($r.temporaryApkCleanup -cne 'INSTALLED_APK_BYTES_DELETED'){throw 'NATIVE_CLEANUP'}
  $n++;if(($raw -join ' ') -match 'SYNTHETIC_PRIVATE_SERIAL|PRIVATE_DENIAL'){throw 'NATIVE_REDACTION'}
  if($mode -eq 'present'){$n++;if($r.privateState.totalDurableFiles -ne 1){throw 'NATIVE_STATE'}}
  if($mode -eq 'denied'){$n++;if($r.privateState.status -cne 'UNKNOWN'){throw 'NATIVE_UNKNOWN'}}
 }
 $n++;if(@(Get-ChildItem (Join-Path $root 'results/update-review-results') -Filter '*.json').Count -ne 4){throw 'ATTEMPTS_LOST'}
 Write-Output "UPDATE_REVIEW_NATIVE_CHECKS=$n;REAL_SDK_ARCHIVED_APKS_FAKE_ADB_ONLY"
}finally{$env:KR_REVIEW_TEST_MODE=$oldMode;$env:KR_REVIEW_OLD_APK=$oldFixture;Remove-Item -LiteralPath $root -Recurse -Force}
