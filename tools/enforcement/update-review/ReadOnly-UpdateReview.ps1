param([string]$Adb='C:\platform-tools\adb.exe',[string]$ExpectedManifestHash,[string]$WorkRoot=(Join-Path $env:LOCALAPPDATA 'KidRemote'))
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$attempt=[Guid]::NewGuid().ToString();$serial=$null;$temporary=$null;$source='UNSPECIFIED';$cleanup='NOT_NEEDED';$lab=$null;$installed=$null;$state=[pscustomobject]@{status='UNKNOWN';sufficientForEmptyStateReview=$false};$classification='READ_ONLY_REVIEW_INVALID';$match='UNKNOWN'
try{
 $manifestPath=Join-Path $PSScriptRoot 'bundle.json'
 if($ExpectedManifestHash -cnotmatch '^[a-f0-9]{64}$' -or (Get-FileHash -LiteralPath $manifestPath).Hash.ToLowerInvariant() -cne $ExpectedManifestHash){throw 'READ_ONLY_REVIEW_INVALID'}
 $m=[IO.File]::ReadAllText($manifestPath)|ConvertFrom-Json
 if($m.scope -cne 'READ_ONLY_SIGNER_STATE_UPDATE_REVIEW' -or $m.source -cnotmatch '^[a-f0-9]{40}$' -or $m.files.Count -ne 4){throw 'READ_ONLY_REVIEW_INVALID'}
 foreach($name in @('Review.psm1','ReadOnly.psm1','ReadOnly-UpdateReview.ps1','lab-reference.apk')){
  $row=@($m.files|Where-Object{$_.name -ceq $name});if($row.Count -ne 1 -or (Get-FileHash -LiteralPath (Join-Path $PSScriptRoot $name)).Hash.ToLowerInvariant() -cne $row[0].sha256){throw 'LAB_APK_PROVENANCE_UNVERIFIED'}
 }
 $source=$m.source;$lab=$m.lab
 if($lab.sha256 -cne 'f6d2a240fae179343d9eb19dfde7684ae6e241b35cebea8ce491205110f7ad56' -or $lab.signerSha256 -cne '638dfa66379788415c313d7a3ca96dcfcaf7e643c12bb0c4950b3046a3f76beb' -or $lab.versionCode -ne 2 -or $lab.package -cne 'dev.kidremote.child.unassigned.debug'){throw 'LAB_APK_PROVENANCE_UNVERIFIED'}
 Import-Module (Join-Path $PSScriptRoot 'Review.psm1') -Force
 Import-Module (Join-Path $PSScriptRoot 'ReadOnly.psm1') -Force
 $java='C:\Program Files\Android\Android Studio\jbr\bin\java.exe'
 $jar=Join-Path $env:LOCALAPPDATA 'Android\Sdk\build-tools\37.0.0\lib\apksigner.jar'
 if((Get-FileHash -LiteralPath $java).Hash.ToLowerInvariant() -cne $m.javaSha256 -or (Get-FileHash -LiteralPath $jar).Hash.ToLowerInvariant() -cne $m.apksignerSha256){throw 'LAB_APK_PROVENANCE_UNVERIFIED'}
 $labVerification=Invoke-ReviewProcess $java @('--enable-native-access=ALL-UNNAMED','-jar',$jar,'verify','--verbose','--print-certs',(Join-Path $PSScriptRoot 'lab-reference.apk'))
 if($labVerification.stderr.Trim() -or (Convert-ReviewSigner $labVerification.stdout) -cne $lab.signerSha256){throw 'LAB_APK_PROVENANCE_UNVERIFIED'}
 $serial=Select-InventoryTarget (Invoke-InventoryAdb $Adb '' @('devices'))
 $read={param($a) Invoke-InventoryAdb $Adb $serial $a}.GetNewClosure()
 $inventory=Invoke-ReadOnlyInventory $read
 if($inventory.classification -in @('CONFIGURATION_MISMATCH','INVALID_PREFLIGHT') -or -not $inventory.child.installed -or $inventory.child.sha256 -cne '3ff9962ec6bf55eab20eda993e879112be9c04a3ed7c00e8287fc7660ad63ac9' -or $inventory.child.versionCode -cne '1' -or $inventory.child.versionName -cne '0.0.1-local'){throw 'READ_ONLY_REVIEW_INVALID'}
 $root=Join-Path $WorkRoot 'update-review-temp';[void][IO.Directory]::CreateDirectory($root)
 $temporary=Join-Path $root $attempt;[void][IO.Directory]::CreateDirectory($temporary);$cleanup='UNVERIFIED'
 $run={param($exe,$argsToRun,$stdinText) Invoke-ReviewProcess $exe $argsToRun $stdinText}
 $installed=Get-InstalledSigner $Adb $serial $inventory.child.basePath $temporary $java $jar $run
 $cleanup='INSTALLED_APK_BYTES_DELETED'
 $state=Get-PrivateMetadata $Adb $serial $run
 $second=Get-PrivateMetadata $Adb $serial $run
 if(($state|ConvertTo-Json -Depth 6 -Compress) -cne ($second|ConvertTo-Json -Depth 6 -Compress)){$state=[pscustomobject]@{status='UNKNOWN';sufficientForEmptyStateReview=$false}}
 $again=Get-InventoryPackage 'dev.kidremote.child.unassigned.debug' $read
 if($again.sha256 -cne $installed.sha256 -or $again.basePath -cne $inventory.child.basePath){throw 'READ_ONLY_REVIEW_INVALID'}
 $match=if($installed.signerSha256 -ceq $lab.signerSha256){'YES'}else{'NO'}
 $classification=Get-UpdateReviewDecision $installed $state $lab.signerSha256 $true
}catch{
 if($_.Exception.Message -cin @('LAB_APK_PROVENANCE_UNVERIFIED','PRIVATE_STATE_REVIEW_REQUIRED','SIGNER_MISMATCH_BLOCKED')){$classification=$_.Exception.Message}else{$classification='READ_ONLY_REVIEW_INVALID'}
}finally{
 if($temporary){try{if(Test-Path -LiteralPath (Join-Path $temporary 'installed-base.apk')){Remove-Item -LiteralPath (Join-Path $temporary 'installed-base.apk') -Force};[IO.Directory]::Delete($temporary);$cleanup='INSTALLED_APK_BYTES_DELETED'}catch{$cleanup='UNVERIFIED';$classification='READ_ONLY_REVIEW_INVALID'}}
}
$output=[ordered]@{scope='READ_ONLY_UPDATE_REVIEW_NOT_AUTHORIZATION';attempt=$attempt;utc=[DateTime]::UtcNow.ToString('o');source=$source;classification=$classification;installed=$installed;lab=$lab;signerMatch=$match;privateState=$state;temporaryApkCleanup=$cleanup;updateExecuted=$false;physicalOracle='BLOCKED'}
if($serial -and ($output|ConvertTo-Json -Depth 8 -Compress).Contains($serial)){$output=[ordered]@{scope='READ_ONLY_UPDATE_REVIEW_NOT_AUTHORIZATION';attempt=$attempt;classification='READ_ONLY_REVIEW_INVALID';reason='SANITIZATION';updateExecuted=$false}}
$serial=$null
try{
 $dir=Join-Path $WorkRoot 'update-review-results';[void][IO.Directory]::CreateDirectory($dir);$raw=$output|ConvertTo-Json -Depth 8
 $f=[IO.File]::Open((Join-Path $dir ($attempt+'.json')),[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
 try{$b=[Text.Encoding]::UTF8.GetBytes($raw);$f.Write($b,0,$b.Length);$f.Flush($true)}finally{$f.Dispose()};Write-Output $raw
}catch{Write-Output '{"classification":"READ_ONLY_REVIEW_INVALID","reason":"HOST_EVIDENCE_WRITE_FAILED"}';exit 1}
